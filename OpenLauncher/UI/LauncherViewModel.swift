import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

struct SelectedTextFile: Equatable, Sendable {
    let url: URL
    let byteCount: Int
    let contents: String
}

@Observable
@MainActor
final class LauncherViewModel {
    var prompt = "" {
        didSet {
            guard prompt != oldValue else { return }
            promptDidChange()
        }
    }
    var selectedProvider: ProviderIdentifier
    var providerDescriptors: [ProviderIdentifier: ProviderDescriptor]
    var runState = ProviderRunState.probing
    var response = ""
    var failure: ProviderFailure?
    var selectedFile: SelectedTextFile?
    var attachmentError: String?
    var shortcutWarning: String?
    var shortcutLabel = LauncherShortcut.optionSpace.glyph
    var promptFocusToken = 0
    var presentationToken = 0
    var providerSetupInProgress: ProviderIdentifier?
    var suggestions: [LauncherSuggestion] = []
    var selectedSuggestionIndex = -1
    var isIndexing = false
    var indexedDocumentCount = 0
    var indexedChunkCount = 0
    var indexError: String?
    var indexWarning: String?
    var indexProgress = LocalIndexProgress.idle
    var indexRunState = LocalIndexRunState.idle
    var onRequestClose: (@MainActor () -> Void)?
    var onRequestResize: (@MainActor (CGFloat) -> Void)?
    var onRequestProviderSetup: (@MainActor (ProviderIdentifier) -> Void)?
    var onRequestSettings: (@MainActor () -> Void)?

    private let engine: ProviderExecutionEngine
    private let localIndexService: any LocalIndexServicing
    private let suggestionCoordinator: any LauncherSuggestionCoordinating
    private let suggestionsEnabled: Bool
    let preferences: LauncherPreferences
    private var runTask: Task<Void, Never>?
    private var activeSession: ProviderRunSession?
    private var runGeneration = 0
    private var probeGeneration = 0
    private var suggestionGeneration = 0
    private var suggestionTask: Task<Void, Never>?
    private var indexTask: Task<Void, Never>?
    private var indexGeneration = 0

    init(
        engine: ProviderExecutionEngine? = nil,
        preferences: LauncherPreferences? = nil,
        autoProbe: Bool = true,
        localIndexService: (any LocalIndexServicing)? = nil,
        suggestionCoordinator: (any LauncherSuggestionCoordinating)? = nil,
        enableSuggestions: Bool? = nil
    ) {
        self.engine = engine ?? ProviderExecutionEngine()
        let preferences = preferences ?? LauncherPreferences()
        self.preferences = preferences
        let localIndexService = localIndexService ?? LocalIndexService()
        self.localIndexService = localIndexService
        self.suggestionCoordinator = suggestionCoordinator
            ?? LauncherSuggestionCoordinator(localIndex: localIndexService)
        suggestionsEnabled = enableSuggestions ?? autoProbe
        selectedProvider = preferences.defaultProvider
        providerDescriptors = Dictionary(uniqueKeysWithValues: ProviderIdentifier.allCases.map {
            ($0, ProviderDescriptor(identifier: $0, status: .probing, capabilities: .phaseZeroRequired))
        })
        #if DEBUG
        if let previewPath = ProcessInfo.processInfo.environment["OPEN_LAUNCHER_PREVIEW_DISCLOSURE"] {
            prompt = "Summarize the attached product brief"
            attachFile(at: URL(fileURLWithPath: previewPath))
            if selectedFile != nil { runState = .awaitingDisclosure }
        } else if let previewState = ProcessInfo.processInfo.environment["OPEN_LAUNCHER_PREVIEW_STATE"] {
            prompt = "Reply with a concise status update"
            response = "The three provider adapters are connected and responding through their installed CLIs."
            switch previewState {
            case "streaming": runState = .streaming
            case "completed": runState = .completed
            case "error":
                response = ""
                failure = ProviderFailure(
                    kind: .rateLimited,
                    providerCode: "preview",
                    message: "This subscription has reached its current usage limit.",
                    isRecoverable: true
                )
                runState = .failed
            default: break
            }
        }
        #endif
        if autoProbe { Task { await probeAllProviders() } }
        if suggestionsEnabled {
            Task { [weak self] in await self?.initializeLocalIndex() }
        }
    }

    var selectedDescriptor: ProviderDescriptor? { providerDescriptors[selectedProvider] }

    var selectedAdapterDisclosure: ProviderInvocationDisclosure {
        ProviderAdapterFactory.make(selectedProvider).invocationDisclosure
    }

    var canSubmit: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isSelectedProviderAvailable
            && runState != .streaming
    }

    var isSelectedProviderAvailable: Bool {
        guard case .available = selectedDescriptor?.status else { return false }
        return true
    }

    var preferredSurfaceHeight: CGFloat {
        if showsSuggestions {
            return LauncherMetrics.controlSize
                + LauncherMetrics.resultGap
                + CGFloat(suggestions.count) * LauncherMetrics.suggestionRowHeight
                + 12
        }
        return switch runState {
        case .idle, .probing, .ready:
            selectedFile == nil ? LauncherMetrics.controlSize : 116
        case .awaitingDisclosure: 314
        case .streaming, .completed, .cancelled: preferences.resultSize.height
        case .failed: 194
        case .empty: 154
        }
    }

    var selectedProviderNeedsSetup: Bool {
        providerNeedsSetup(selectedProvider)
    }

    var isProviderSetupInProgress: Bool {
        providerSetupInProgress == selectedProvider
    }

    var showsSuggestions: Bool {
        !suggestions.isEmpty
            && selectedFile == nil
            && runState != .streaming
            && runState != .awaitingDisclosure
    }

    var selectedSuggestion: LauncherSuggestion? {
        guard suggestions.indices.contains(selectedSuggestionIndex) else { return nil }
        return suggestions[selectedSuggestionIndex]
    }

    func providerNeedsSetup(_ provider: ProviderIdentifier) -> Bool {
        switch providerDescriptors[provider]?.status {
        case .authenticationRequired, .unavailable: true
        default: false
        }
    }

    func focusPrompt() { promptFocusToken += 1 }

    func selectProvider(_ provider: ProviderIdentifier) {
        guard provider != selectedProvider else { return }
        if runState == .streaming { cancel() }
        providerSetupInProgress = nil
        probeGeneration += 1
        selectedProvider = provider
        preferences.defaultProvider = provider
        failure = nil
        switch selectedDescriptor?.status {
        case .available:
            runState = .ready
        case .authenticationRequired:
            failure = ProviderFailure(
                kind: .authentication,
                providerCode: nil,
                message: "Connect \(provider.displayName) to continue.",
                isRecoverable: true
            )
            runState = .failed
        case .unavailable:
            runState = .failed
        case .probing, .unknown, nil:
            runState = .probing
        }
        requestSurfaceResize()
        scheduleSuggestions(immediate: true)
        focusPrompt()
    }

    func activateProvider(_ provider: ProviderIdentifier) {
        selectProvider(provider)
        if providerNeedsSetup(provider) { beginProviderSetup(provider) }
    }

    func prepareForPresentation() {
        guard runState != .streaming else { return }
        if preferences.clearQueryOnOpen {
            prompt = ""
            response = ""
        }
        failure = nil
        selectedFile = nil
        attachmentError = nil
        runState = isSelectedProviderAvailable ? .ready : .probing
        presentationToken += 1
        scheduleSuggestions(immediate: true)
        requestSurfaceResize()
        focusPrompt()
    }

    func dismiss() {
        if runState == .streaming { cancel() }
        onRequestClose?()
    }

    func requestProviderSetup() {
        beginProviderSetup(selectedProvider)
    }

    func finishProviderSetup() {
        providerSetupInProgress = nil
    }

    func submit() {
        guard showsSuggestions else { return }
        activateSelectedSuggestion()
    }

    func submitToProvider() {
        guard canSubmit else {
            if selectedProviderNeedsSetup { requestProviderSetup() }
            return
        }
        let query = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { [suggestionCoordinator, selectedProvider] in
            await suggestionCoordinator.recordSelection(LauncherSuggestion(
                id: "direct-ask:\(UUID().uuidString)",
                kind: .askProvider,
                title: query,
                subtitle: "Ask \(selectedProvider.displayName)",
                icon: .provider(selectedProvider),
                action: .ask(query),
                score: 0
            ))
        }
        clearSuggestions()
        if selectedFile != nil {
            runState = .awaitingDisclosure
        } else {
            startRun(confirmedContext: nil)
        }
        requestSurfaceResize()
    }

    func confirmFileAndSubmit() {
        guard let selectedFile else { return }
        do {
            let disclosure = try FileContextDisclosure(
                fileURL: selectedFile.url,
                byteCount: selectedFile.byteCount,
                extractedCharacterCount: selectedFile.contents.count,
                provider: selectedProvider
            )
            let context = try ConfirmedFileContext(disclosure: disclosure, contents: selectedFile.contents)
            startRun(confirmedContext: context)
            requestSurfaceResize()
        } catch {
            attachmentError = error.localizedDescription
            runState = .failed
        }
    }

    func rejectDisclosure() {
        runState = .ready
        requestSurfaceResize()
        focusPrompt()
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Attach a text file"
        panel.prompt = "Attach"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .text, .json, .commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        attachFile(at: url)
    }

    func attachFile(at url: URL) {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 512 * 1_024 else {
                throw AttachmentError.tooLarge
            }
            guard let contents = String(data: data, encoding: .utf8) else {
                throw AttachmentError.notUTF8
            }
            selectedFile = SelectedTextFile(url: url, byteCount: data.count, contents: contents)
            attachmentError = nil
            requestSurfaceResize()
        } catch {
            selectedFile = nil
            attachmentError = error.localizedDescription
            requestSurfaceResize()
        }
    }

    func removeFile() {
        selectedFile = nil
        attachmentError = nil
        if runState == .awaitingDisclosure { runState = .ready }
        requestSurfaceResize()
    }

    func cancelOrClose() {
        if runState == .streaming {
            cancel()
        } else {
            onRequestClose?()
        }
    }

    func cancel() {
        runGeneration += 1
        activeSession?.cancel()
        runTask?.cancel()
        activeSession = nil
        runTask = nil
        runState = .cancelled
        requestSurfaceResize()
    }

    func shutdown() async {
        runGeneration += 1
        probeGeneration += 1
        suggestionGeneration += 1
        suggestionTask?.cancel()
        indexTask?.cancel()
        let session = activeSession
        let task = runTask
        let pendingIndex = indexTask
        task?.cancel()
        runTask = nil
        activeSession = nil
        if let session {
            await session.cancelAndWait()
        }
        await task?.value
        await pendingIndex?.value
    }

    func retry() {
        failure = nil
        submitToProvider()
    }

    func reprobeSelectedProvider() async {
        probeGeneration += 1
        let generation = probeGeneration
        let provider = selectedProvider
        providerDescriptors[provider] = ProviderDescriptor(
            identifier: provider,
            status: .probing,
            capabilities: .phaseZeroRequired
        )
        runState = .probing
        let descriptor = await engine.probe(provider)
        guard generation == probeGeneration,
              provider == selectedProvider,
              runState == .probing
        else { return }
        providerDescriptors[provider] = descriptor
        failure = nil
        runState = isSelectedProviderAvailable ? .ready : .failed
        if isSelectedProviderAvailable { providerSetupInProgress = nil }
        requestSurfaceResize()
    }

    func probeAllProviders() async {
        await withTaskGroup(of: ProviderDescriptor.self) { group in
            for provider in ProviderIdentifier.allCases {
                group.addTask { [engine] in await engine.probe(provider) }
            }
            for await descriptor in group {
                providerDescriptors[descriptor.identifier] = descriptor
                if descriptor.identifier == selectedProvider, runState == .probing {
                    runState = isSelectedProviderAvailable ? .ready : .failed
                    requestSurfaceResize()
                }
            }
        }
    }

    func moveSuggestionSelection(by delta: Int) {
        guard !suggestions.isEmpty else { return }
        if suggestions.indices.contains(selectedSuggestionIndex) {
            selectedSuggestionIndex = (selectedSuggestionIndex + delta + suggestions.count) % suggestions.count
        } else {
            selectedSuggestionIndex = delta < 0 ? suggestions.count - 1 : 0
        }
    }

    func selectSuggestion(at index: Int) {
        guard suggestions.indices.contains(index) else { return }
        selectedSuggestionIndex = index
    }

    func activateSelectedSuggestion() {
        guard let suggestion = selectedSuggestion,
              !suggestion.action.invokesProvider
        else { return }
        activateSuggestion(suggestion)
    }

    func activateSuggestion(at index: Int) {
        guard suggestions.indices.contains(index) else { return }
        selectedSuggestionIndex = index
        activateSuggestion(suggestions[index])
    }

    func addIndexFolder(_ url: URL) {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        if let reason = LocalIndexRootPolicy.rejectionReason(for: url) {
            indexError = "The folder cannot be indexed: \(path). \(reason)"
            return
        }
        guard !preferences.indexedFolderPaths.contains(path) else { return }
        indexError = nil
        preferences.indexedFolderPaths.append(path)
        refreshLocalIndex()
    }

    func removeIndexFolder(path: String) {
        if isIndexing { cancelLocalIndexing() }
        preferences.indexedFolderPaths.removeAll { $0 == path }
        clearSuggestions()
        Task { [weak self] in await self?.loadLocalIndexState() }
    }

    func refreshLocalIndex() {
        clearSuggestions()
        indexGeneration += 1
        let generation = indexGeneration
        indexTask?.cancel()
        isIndexing = true
        indexRunState = .indexing
        indexProgress = LocalIndexProgress(
            state: .indexing,
            discovered: 0,
            processed: 0,
            indexed: 0,
            skipped: 0,
            failed: 0,
            currentPath: nil,
            recentErrors: []
        )
        indexError = nil
        let roots = preferences.indexedFolders
        indexTask = Task { [weak self, localIndexService] in
            do {
                let values = try await localIndexService.rebuild(roots: roots) { [weak self] progress in
                    await self?.receiveIndexProgress(progress, generation: generation)
                }
                guard !Task.isCancelled, self?.indexGeneration == generation else { return }
                self?.indexedDocumentCount = values.documents
                self?.indexedChunkCount = values.chunks
                self?.indexRunState = values.state
                self?.indexProgress = LocalIndexProgress(
                    state: values.state,
                    discovered: values.discovered,
                    processed: values.processed,
                    indexed: values.indexed,
                    skipped: values.skipped,
                    failed: values.failed,
                    currentPath: nil,
                    recentErrors: values.recentErrors
                )
            } catch is CancellationError {
                guard self?.indexGeneration == generation else { return }
                self?.indexRunState = .cancelled
                self?.indexProgress = LocalIndexProgress(
                    state: .cancelled,
                    discovered: self?.indexProgress.discovered ?? 0,
                    processed: self?.indexProgress.processed ?? 0,
                    indexed: self?.indexProgress.indexed ?? 0,
                    skipped: self?.indexProgress.skipped ?? 0,
                    failed: self?.indexProgress.failed ?? 0,
                    currentPath: nil,
                    recentErrors: self?.indexProgress.recentErrors ?? []
                )
            } catch {
                guard !Task.isCancelled, self?.indexGeneration == generation else { return }
                self?.indexError = error.localizedDescription
                self?.indexRunState = .failed
            }
            guard self?.indexGeneration == generation else { return }
            self?.isIndexing = false
            self?.indexTask = nil
            self?.scheduleSuggestions(immediate: true)
        }
    }

    func cancelLocalIndexing() {
        guard isIndexing else { return }
        indexGeneration += 1
        indexTask?.cancel()
        indexTask = nil
        isIndexing = false
        indexRunState = .cancelled
        indexProgress = LocalIndexProgress(
            state: .cancelled,
            discovered: indexProgress.discovered,
            processed: indexProgress.processed,
            indexed: indexProgress.indexed,
            skipped: indexProgress.skipped,
            failed: indexProgress.failed,
            currentPath: nil,
            recentErrors: indexProgress.recentErrors
        )
        scheduleSuggestions(immediate: true)
    }

    func clearLocalIndex() {
        clearSuggestions()
        indexGeneration += 1
        let generation = indexGeneration
        indexTask?.cancel()
        isIndexing = true
        indexRunState = .indexing
        indexError = nil
        let roots = preferences.indexedFolders
        indexTask = Task { [weak self, localIndexService] in
            do {
                try await localIndexService.clear(roots: roots)
                guard !Task.isCancelled, self?.indexGeneration == generation else { return }
                self?.indexedDocumentCount = 0
                self?.indexedChunkCount = 0
                self?.indexProgress = .idle
                self?.indexRunState = .idle
            } catch {
                guard !Task.isCancelled, self?.indexGeneration == generation else { return }
                self?.indexError = error.localizedDescription
                self?.indexRunState = .failed
            }
            guard self?.indexGeneration == generation else { return }
            self?.isIndexing = false
            self?.indexTask = nil
            self?.scheduleSuggestions(immediate: true)
        }
    }

    private func startRun(confirmedContext: ConfirmedFileContext?) {
        runGeneration += 1
        probeGeneration += 1
        let generation = runGeneration
        runTask?.cancel()
        activeSession?.cancel()
        activeSession = nil
        failure = nil
        response = ""
        runState = .streaming
        requestSurfaceResize()

        do {
            let request = try ProviderRequest(
                provider: selectedProvider,
                query: prompt,
                confirmedFileContext: confirmedContext
            )
            runTask = Task { [weak self] in await self?.consume(request, generation: generation) }
        } catch {
            failure = ProviderFailure(
                kind: .invocation,
                providerCode: nil,
                message: error.localizedDescription,
                isRecoverable: true
            )
            runState = .failed
            requestSurfaceResize()
        }
    }

    private func activateSuggestion(_ suggestion: LauncherSuggestion) {
        Task { [suggestionCoordinator] in await suggestionCoordinator.recordSelection(suggestion) }
        switch suggestion.action {
        case let .open(url):
            _ = NSWorkspace.shared.open(url)
            clearSuggestions()
            onRequestClose?()
        case let .ask(query):
            prompt = query
            submitToProvider()
        case let .fillPrompt(value):
            prompt = value
            focusPrompt()
            scheduleSuggestions(immediate: true)
        case .showSettings:
            clearSuggestions()
            onRequestSettings?()
        }
    }

    private func promptDidChange() {
        guard suggestionsEnabled else { return }
        if runState == .completed || runState == .cancelled || runState == .empty {
            response = ""
            failure = nil
            runState = isSelectedProviderAvailable ? .ready : .probing
        }
        scheduleSuggestions()
    }

    private func scheduleSuggestions(immediate: Bool = false) {
        guard suggestionsEnabled, runState != .streaming, runState != .awaitingDisclosure else { return }
        suggestionGeneration += 1
        let generation = suggestionGeneration
        suggestionTask?.cancel()
        suggestions = []
        selectedSuggestionIndex = -1
        let request = LauncherSuggestionRequest(
            query: prompt,
            provider: selectedProvider,
            indexedRoots: preferences.indexedFolders,
            limit: 6
        )
        suggestionTask = Task { [weak self, suggestionCoordinator] in
            if !immediate { try? await Task.sleep(for: .milliseconds(70)) }
            guard !Task.isCancelled else { return }
            let values = await suggestionCoordinator.suggestions(for: request)
            guard !Task.isCancelled, self?.suggestionGeneration == generation else { return }
            self?.suggestions = values
            self?.selectedSuggestionIndex = Self.defaultSuggestionIndex(in: values)
            self?.suggestionTask = nil
            self?.requestSurfaceResize()
        }
    }

    private func clearSuggestions() {
        suggestionGeneration += 1
        suggestionTask?.cancel()
        suggestionTask = nil
        suggestions = []
        selectedSuggestionIndex = -1
    }

    private static func defaultSuggestionIndex(in suggestions: [LauncherSuggestion]) -> Int {
        suggestions.firstIndex { !$0.action.invokesProvider } ?? -1
    }

    private func initializeLocalIndex() async {
        await migrateLegacyIndexIfNeeded()
        await loadLocalIndexState()
    }

    private func migrateLegacyIndexIfNeeded() async {
        let paths = preferences.pendingLegacyIndexQuarantinePaths
        guard !paths.isEmpty else { return }
        indexRunState = .quarantined
        isIndexing = true
        do {
            let result = try await localIndexService.quarantineForbiddenRoots(paths: paths)
            preferences.completeLegacyIndexQuarantine()
            indexedDocumentCount = 0
            indexedChunkCount = 0
            indexWarning = if let result, let backupURL = result.backupURL {
                "Unsafe whole-volume index quarantined (\(result.removedDocumentCount.formatted()) documents). Backup: \(backupURL.path)"
            } else {
                "Unsafe whole-volume indexing was disabled. Add specific folders to build a new index."
            }
            indexRunState = .quarantined
        } catch {
            indexError = "The unsafe legacy index could not be quarantined: \(error.localizedDescription)"
            indexRunState = .failed
        }
        isIndexing = false
    }

    private func loadLocalIndexState() async {
        let roots = preferences.indexedFolders
        guard !roots.isEmpty else {
            indexedDocumentCount = 0
            indexedChunkCount = 0
            if indexRunState != .quarantined { indexRunState = .idle }
            scheduleSuggestions(immediate: true)
            return
        }
        do {
            let values = try await localIndexService.statistics(roots: roots)
            indexedDocumentCount = values.documents
            indexedChunkCount = values.chunks
            indexRunState = values.documents == 0 ? .idle : .partial
        } catch {
            indexError = error.localizedDescription
            indexRunState = .failed
        }
        scheduleSuggestions(immediate: true)
    }

    private func receiveIndexProgress(_ progress: LocalIndexProgress, generation: Int) {
        guard generation == indexGeneration else { return }
        indexProgress = progress
        indexRunState = progress.state
    }

    private func beginProviderSetup(_ provider: ProviderIdentifier) {
        providerSetupInProgress = provider
        onRequestProviderSetup?(provider)
        requestSurfaceResize()
    }

    private func consume(_ request: ProviderRequest, generation: Int) async {
        do {
            let session = try await engine.start(request)
            guard generation == runGeneration else {
                await session.cancelAndWait()
                return
            }
            activeSession = session
            for try await event in session.events {
                guard !Task.isCancelled, generation == runGeneration else {
                    session.cancel()
                    return
                }
                switch event {
                case let .state(state): runState = state
                case let .textDelta(text): response += text
                case .completed: runState = response.isEmpty ? .empty : .completed
                case let .failed(value):
                    failure = value
                    runState = .failed
                }
                requestSurfaceResize()
            }
            if generation == runGeneration {
                activeSession = nil
                runTask = nil
            }
        } catch is CancellationError {
            if generation == runGeneration { runState = .cancelled }
        } catch let executionError as ProviderExecutionError {
            guard generation == runGeneration else { return }
            failure = ProviderFailure(
                kind: .invocation,
                providerCode: nil,
                message: executionError.localizedDescription,
                isRecoverable: true
            )
            runState = .failed
            requestSurfaceResize()
        } catch {
            guard generation == runGeneration else { return }
            failure = ProviderFailure(
                kind: .unknown,
                providerCode: nil,
                message: error.localizedDescription,
                isRecoverable: true
            )
            runState = .failed
            requestSurfaceResize()
        }
    }

    private func requestSurfaceResize() {
        onRequestResize?(preferredSurfaceHeight)
    }
}

private enum AttachmentError: LocalizedError {
    case tooLarge
    case notUTF8

    var errorDescription: String? {
        switch self {
        case .tooLarge: "Text attachments are limited to 512 KB in this prototype."
        case .notUTF8: "This prototype can only attach UTF-8 text files."
        }
    }
}

extension ProviderExecutionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .executableNotFound(provider): "\(provider.displayName) is not installed or executable."
        case .providerMismatch: "The selected provider does not match the request."
        }
    }
}
