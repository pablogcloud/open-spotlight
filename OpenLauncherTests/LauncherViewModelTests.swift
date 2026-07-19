import Foundation
import XCTest
@testable import OpenLauncher

private let launcherViewModelPreferencesSuite = "OpenSpotlightViewModelTests"

@MainActor
final class LauncherViewModelTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: launcherViewModelPreferencesSuite)
        super.tearDown()
    }

    func testAttachedFileRequiresDisclosureBeforeProviderStarts() async throws {
        let runner = CountingProcessRunner()
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: ExecutableLocator(
                environmentPath: "",
                includeDefaultCandidates: false,
                explicitExecutables: [.codex: URL(fileURLWithPath: "/usr/bin/true")]
            )
        )
        let model = LauncherViewModel(
            engine: engine,
            preferences: makePreferences(),
            autoProbe: false
        )
        model.providerDescriptors[.codex] = ProviderDescriptor(
            identifier: .codex,
            status: .available(version: "test", executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        model.runState = .ready
        model.prompt = "Summarize this"

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "open-launcher-disclosure-\(UUID().uuidString).txt")
        try Data("Private project notes".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        model.attachFile(at: fileURL)
        model.submitToProvider()

        XCTAssertEqual(model.runState, .awaitingDisclosure)
        XCTAssertEqual(model.selectedFile?.contents, "Private project notes")
        XCTAssertEqual(runner.startCount, 0, "No provider process may start before confirmation")

        model.confirmFileAndSubmit()
        for _ in 0..<20 where runner.startCount == 0 { await Task.yield() }

        let sentPayload = runner.lastInvocation?.standardInput.map { String(decoding: $0, as: UTF8.self) }
        XCTAssertEqual(runner.startCount, 1)
        XCTAssertEqual(sentPayload?.components(separatedBy: "Private project notes").count ?? 0, 2)
    }

    func testOversizedAttachmentIsRejected() throws {
        let model = LauncherViewModel(preferences: makePreferences(), autoProbe: false)
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "open-launcher-large-\(UUID().uuidString).txt")
        try Data(repeating: 0x61, count: 512 * 1_024 + 1).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        model.attachFile(at: fileURL)

        XCTAssertNil(model.selectedFile)
        XCTAssertEqual(model.attachmentError, "Text attachments are limited to 512 KB in this prototype.")
    }

    func testSupersededRunCannotOverwriteNewerCompletion() async throws {
        let runner = SupersededRunProcessRunner()
        let model = makeReadyModel(runner: runner)

        model.prompt = "first"
        model.submitToProvider()
        for _ in 0..<50 where runner.startCount < 1 { await Task.yield() }

        model.cancel()
        model.prompt = "second"
        model.submitToProvider()
        for _ in 0..<100 where model.runState != .completed { await Task.yield() }

        XCTAssertEqual(model.response, "SECOND")
        XCTAssertEqual(model.runState, .completed)

        runner.releaseFirstRun()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(model.response, "SECOND")
        XCTAssertEqual(model.runState, .completed)
    }

    func testLateReprobeCannotHideStreamingState() async {
        let runner = DelayedProbeProcessRunner()
        let model = makeReadyModel(runner: runner)

        let reprobe = Task { await model.reprobeSelectedProvider() }
        for _ in 0..<50 where runner.startCount == 0 { await Task.yield() }
        model.runState = .streaming
        runner.releaseProbe()
        await reprobe.value

        XCTAssertEqual(model.runState, .streaming)
    }

    func testShutdownCancelsAndWaitsForActiveProvider() async {
        let runner = ShutdownProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "keep running"
        model.submitToProvider()
        for _ in 0..<100 where !runner.didStart { await Task.yield() }
        for _ in 0..<10 { await Task.yield() }

        await model.shutdown()

        XCTAssertTrue(runner.didCancel)
        XCTAssertTrue(runner.didWaitForCancellation)
    }

    func testShutdownWaitsForProviderCancelledDuringStartup() async {
        let runner = StartupRaceProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "start slowly"
        model.submitToProvider()
        for _ in 0..<100 where !runner.didStart { await Task.yield() }

        let shutdown = Task { await model.shutdown() }
        for _ in 0..<10 { await Task.yield() }
        runner.releaseStartup()
        await shutdown.value

        XCTAssertTrue(runner.didCancel)
        XCTAssertTrue(runner.didWaitForCancellation)
    }

    func testPreferencesControlDefaultProviderAndResultHeight() {
        let preferences = makePreferences()
        preferences.defaultProvider = .grok
        preferences.resultSize = .spacious
        let model = LauncherViewModel(preferences: preferences, autoProbe: false)

        XCTAssertEqual(model.selectedProvider, .grok)
        model.runState = .completed
        XCTAssertEqual(model.preferredSurfaceHeight, LauncherResultSize.spacious.height)
    }

    func testPresentationCanRetainPreviousQuery() {
        let preferences = makePreferences()
        preferences.clearQueryOnOpen = false
        let model = LauncherViewModel(preferences: preferences, autoProbe: false)
        model.prompt = "Keep this query"

        model.prepareForPresentation()

        XCTAssertEqual(model.prompt, "Keep this query")
    }

    func testIdleSurfaceMatchesNativeSpotlightHeight() {
        let model = LauncherViewModel(preferences: makePreferences(), autoProbe: false)

        XCTAssertEqual(model.preferredSurfaceHeight, 56)
        XCTAssertEqual(LauncherMetrics.surfaceWidth, 640)
    }

    func testActivatingAvailableProviderSelectsItWithoutStartingSetup() {
        let preferences = makePreferences()
        let model = LauncherViewModel(preferences: preferences, autoProbe: false)
        model.providerDescriptors[.claude] = ProviderDescriptor(
            identifier: .claude,
            status: .available(version: "test", executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        var setupProvider: ProviderIdentifier?
        model.onRequestProviderSetup = { setupProvider = $0 }

        model.activateProvider(.claude)

        XCTAssertEqual(model.selectedProvider, .claude)
        XCTAssertEqual(preferences.defaultProvider, .claude)
        XCTAssertNil(setupProvider)
    }

    func testActivatingProviderThatNeedsAuthenticationStartsItsSetupFlow() {
        let model = LauncherViewModel(preferences: makePreferences(), autoProbe: false)
        model.providerDescriptors[.grok] = ProviderDescriptor(
            identifier: .grok,
            status: .authenticationRequired(executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        var setupProvider: ProviderIdentifier?
        model.onRequestProviderSetup = { setupProvider = $0 }

        model.activateProvider(.grok)

        XCTAssertEqual(model.selectedProvider, .grok)
        XCTAssertEqual(setupProvider, .grok)
        XCTAssertTrue(model.selectedProviderNeedsSetup)
    }

    func testReactivatingUnavailableSelectedProviderStillStartsInstallationFlow() {
        let model = LauncherViewModel(preferences: makePreferences(), autoProbe: false)
        model.providerDescriptors[.codex] = ProviderDescriptor(
            identifier: .codex,
            status: .unavailable(reason: "Not installed"),
            capabilities: .phaseZeroRequired
        )
        var setupProvider: ProviderIdentifier?
        model.onRequestProviderSetup = { setupProvider = $0 }

        model.activateProvider(.codex)

        XCTAssertEqual(setupProvider, .codex)
    }

    func testTypingBuildsSuggestionsWithoutStartingProviderProcess() async throws {
        let runner = CountingProcessRunner()
        let coordinator = StubViewModelSuggestionCoordinator(values: [LauncherSuggestion(
            id: "prompt:budget",
            kind: .prompt,
            title: "Find documents about budget",
            subtitle: "Search your files",
            icon: .system("doc.text.magnifyingglass"),
            action: .fillPrompt("Find documents about budget"),
            score: 200
        )])
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: ExecutableLocator(
                environmentPath: "",
                includeDefaultCandidates: false,
                explicitExecutables: [.codex: URL(fileURLWithPath: "/usr/bin/true")]
            )
        )
        let model = LauncherViewModel(
            engine: engine,
            preferences: makePreferences(),
            autoProbe: false,
            suggestionCoordinator: coordinator,
            enableSuggestions: true
        )
        model.providerDescriptors[.codex] = ProviderDescriptor(
            identifier: .codex,
            status: .available(version: "test", executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        model.runState = .ready

        model.prompt = "budget"
        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(model.suggestions.map(\.title), ["Find documents about budget"])
        XCTAssertEqual(runner.startCount, 0)
    }

    func testCommandSubmitBypassesSelectedSuggestionAndStartsProvider() async throws {
        let runner = CountingProcessRunner()
        let coordinator = StubViewModelSuggestionCoordinator(values: [LauncherSuggestion(
            id: "prompt:budget",
            kind: .prompt,
            title: "Find documents about budget",
            icon: .system("doc.text.magnifyingglass"),
            action: .fillPrompt("Find documents about budget"),
            score: 200
        )])
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: ExecutableLocator(
                environmentPath: "",
                includeDefaultCandidates: false,
                explicitExecutables: [.codex: URL(fileURLWithPath: "/usr/bin/true")]
            )
        )
        let model = LauncherViewModel(
            engine: engine,
            preferences: makePreferences(),
            autoProbe: false,
            suggestionCoordinator: coordinator,
            enableSuggestions: true
        )
        model.providerDescriptors[.codex] = ProviderDescriptor(
            identifier: .codex,
            status: .available(version: "test", executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        model.runState = .ready
        model.prompt = "budget"
        try await Task.sleep(for: .milliseconds(120))

        model.submitToProvider()
        for _ in 0..<30 where runner.startCount == 0 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 1)
        XCTAssertTrue(model.suggestions.isEmpty)
    }

    func testReturnWithNoLocalSuggestionDoesNotStartProvider() async {
        let runner = CountingProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "quarterly-report.pdf"
        model.suggestions = []

        model.submit()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 0)
        XCTAssertEqual(model.runState, .ready)
    }

    func testReturnOnAskProviderSuggestionDoesNotStartProvider() async {
        let runner = CountingProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "quarterly-report.pdf"
        model.suggestions = [LauncherSuggestion(
            id: "ask:codex:quarterly-report.pdf",
            kind: .askProvider,
            title: "quarterly-report.pdf",
            subtitle: "Ask Codex",
            icon: .provider(.codex),
            action: .ask("quarterly-report.pdf"),
            score: 100
        )]
        model.selectedSuggestionIndex = 0

        model.submit()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 0)
        XCTAssertEqual(model.runState, .ready)
    }

    func testReturnOnRecentAskSuggestionDoesNotStartProvider() async {
        let runner = CountingProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "prepare the release"
        model.suggestions = [LauncherSuggestion(
            id: "recent-ask:prepare-the-release",
            kind: .recent,
            title: "prepare the release",
            subtitle: "Ask Codex again",
            icon: .provider(.codex),
            action: .ask("prepare the release"),
            score: 740
        )]
        model.selectedSuggestionIndex = 0

        model.submit()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 0)
        XCTAssertEqual(model.runState, .ready)
    }

    func testClickingAskProviderSuggestionStartsProviderExplicitly() async {
        let runner = CountingProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "quarterly-report.pdf"
        model.suggestions = [LauncherSuggestion(
            id: "ask:codex:quarterly-report.pdf",
            kind: .askProvider,
            title: "quarterly-report.pdf",
            subtitle: "Ask Codex",
            icon: .provider(.codex),
            action: .ask("quarterly-report.pdf"),
            score: 100
        )]

        model.activateSuggestion(at: 0)
        for _ in 0..<30 where runner.startCount == 0 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 1)
    }

    func testAIHistorySuggestionIsNotTheDefaultReturnTarget() async throws {
        let runner = CountingProcessRunner()
        let coordinator = StubViewModelSuggestionCoordinator(values: [
            LauncherSuggestion(
                id: "recent-ask:prepare-the-release",
                kind: .recent,
                title: "prepare the release",
                subtitle: "Ask Codex again",
                icon: .provider(.codex),
                action: .ask("prepare the release"),
                score: 740
            ),
            LauncherSuggestion(
                id: "prompt:find-release",
                kind: .prompt,
                title: "Find documents about release",
                icon: .system("doc.text.magnifyingglass"),
                action: .fillPrompt("Find documents about release"),
                score: 240
            ),
        ])
        let model = LauncherViewModel(
            engine: ProviderExecutionEngine(
                runner: runner,
                locator: ExecutableLocator(
                    environmentPath: "",
                    includeDefaultCandidates: false,
                    explicitExecutables: [.codex: URL(fileURLWithPath: "/usr/bin/true")]
                )
            ),
            preferences: makePreferences(),
            autoProbe: false,
            suggestionCoordinator: coordinator,
            enableSuggestions: true
        )
        model.runState = .ready
        model.prompt = "release"
        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(model.selectedSuggestion?.kind, .prompt)
        XCTAssertEqual(runner.startCount, 0)
    }

    func testRetryStartsProviderExplicitly() async {
        let runner = CountingProcessRunner()
        let model = makeReadyModel(runner: runner)
        model.prompt = "try this again"
        model.runState = .failed

        model.retry()
        for _ in 0..<30 where runner.startCount == 0 { await Task.yield() }

        XCTAssertEqual(runner.startCount, 1)
    }

    func testChangingQueryImmediatelyInvalidatesRenderedSuggestions() {
        let model = LauncherViewModel(
            preferences: makePreferences(),
            autoProbe: false,
            suggestionCoordinator: StubViewModelSuggestionCoordinator(values: []),
            enableSuggestions: true
        )
        model.runState = .ready
        model.suggestions = [LauncherSuggestion(
            id: "old",
            kind: .file,
            title: "Old query result",
            icon: .system("doc"),
            action: .open(URL(fileURLWithPath: "/tmp/old.md")),
            score: 1
        )]

        model.prompt = "new query"

        XCTAssertTrue(model.suggestions.isEmpty)
        XCTAssertFalse(model.showsSuggestions)
    }

    func testRefreshingIndexInvalidatesSuggestionsFromPreviousScope() {
        let preferences = makePreferences()
        preferences.indexedFolderPaths = ["/tmp/old-root"]
        let model = LauncherViewModel(
            preferences: preferences,
            autoProbe: false,
            suggestionCoordinator: StubViewModelSuggestionCoordinator(values: []),
            enableSuggestions: true
        )
        model.runState = .ready
        model.suggestions = [LauncherSuggestion(
            id: "old-scope",
            kind: .indexedDocument,
            title: "Old scope",
            icon: .system("doc"),
            action: .open(URL(fileURLWithPath: "/tmp/old-root/private.md")),
            score: 1
        )]

        model.refreshLocalIndex()

        XCTAssertTrue(model.suggestions.isEmpty)
    }

    func testAddingForbiddenWholeVolumeRootLeavesPreferencesUnchanged() {
        let preferences = makePreferences()
        let model = LauncherViewModel(preferences: preferences, autoProbe: false)

        model.addIndexFolder(URL(fileURLWithPath: "/", isDirectory: true))

        XCTAssertTrue(preferences.indexedFolderPaths.isEmpty)
        XCTAssertTrue(model.indexError?.contains("whole startup volume") == true)
        XCTAssertFalse(model.isIndexing)
    }

    func testStartupQuarantinesForbiddenPersistedRootBeforeEnablingIndex() async throws {
        let suiteName = "OpenSpotlightMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["/"], forKey: "indexedFolderPaths")
        let preferences = LauncherPreferences(defaults: defaults)
        let service = MigrationLocalIndexService()
        let model = LauncherViewModel(
            preferences: preferences,
            autoProbe: false,
            localIndexService: service,
            suggestionCoordinator: StubViewModelSuggestionCoordinator(values: []),
            enableSuggestions: true
        )

        for _ in 0..<100 where await service.quarantineCount == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }

        let quarantineCount = await service.quarantineCount
        XCTAssertEqual(quarantineCount, 1)
        XCTAssertTrue(preferences.indexedFolderPaths.isEmpty)
        XCTAssertTrue(preferences.pendingLegacyIndexQuarantinePaths.isEmpty)
        XCTAssertEqual(model.indexRunState, .quarantined)
        XCTAssertTrue(model.indexWarning?.contains("10 documents") == true)
    }

    func testCancellingIndexRefreshClearsBusyStateAndRetainsProgress() async throws {
        let preferences = makePreferences()
        preferences.indexedFolderPaths = ["/tmp/Documents"]
        let service = SuspendingLocalIndexService()
        let model = LauncherViewModel(
            preferences: preferences,
            autoProbe: false,
            localIndexService: service,
            enableSuggestions: false
        )

        model.refreshLocalIndex()
        for _ in 0..<100 where model.indexProgress.discovered == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        model.cancelLocalIndexing()

        XCTAssertFalse(model.isIndexing)
        XCTAssertEqual(model.indexRunState, .cancelled)
        XCTAssertEqual(model.indexProgress.discovered, 12)
        XCTAssertEqual(model.indexProgress.indexed, 4)
    }

    private func makeReadyModel(runner: any ProcessRunning) -> LauncherViewModel {
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: ExecutableLocator(
                environmentPath: "",
                includeDefaultCandidates: false,
                explicitExecutables: [.codex: URL(fileURLWithPath: "/usr/bin/true")]
            )
        )
        let model = LauncherViewModel(
            engine: engine,
            preferences: makePreferences(),
            autoProbe: false
        )
        model.providerDescriptors[.codex] = ProviderDescriptor(
            identifier: .codex,
            status: .available(version: "test", executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            capabilities: .phaseZeroRequired
        )
        model.runState = .ready
        return model
    }

    private func makePreferences() -> LauncherPreferences {
        let defaults = UserDefaults(suiteName: launcherViewModelPreferencesSuite)!
        defaults.removePersistentDomain(forName: launcherViewModelPreferencesSuite)
        return LauncherPreferences(defaults: defaults)
    }
}

private actor StubViewModelSuggestionCoordinator: LauncherSuggestionCoordinating {
    let values: [LauncherSuggestion]

    init(values: [LauncherSuggestion]) {
        self.values = values
    }

    func suggestions(for request: LauncherSuggestionRequest) -> [LauncherSuggestion] {
        values
    }

    func recordSelection(_ suggestion: LauncherSuggestion) {}
}

private actor MigrationLocalIndexService: LocalIndexServicing {
    private(set) var quarantineCount = 0

    func search(_ query: String, roots: [URL], limit: Int) -> [LocalSearchReference] { [] }
    func rebuild(roots: [URL]) -> LocalIndexStatistics {
        LocalIndexStatistics(documents: 0, chunks: 0)
    }
    func statistics(roots: [URL]) -> LocalIndexStatistics {
        LocalIndexStatistics(documents: 0, chunks: 0)
    }
    func clear(roots: [URL]) {}
    func quarantineForbiddenRoots(paths: [String]) -> LocalIndexQuarantineResult? {
        quarantineCount += 1
        return LocalIndexQuarantineResult(
            removedDocumentCount: 10,
            backupURL: URL(fileURLWithPath: "/tmp/OpenSpotlight-legacy-index.sqlite")
        )
    }
}

private actor SuspendingLocalIndexService: LocalIndexServicing {
    func search(_ query: String, roots: [URL], limit: Int) -> [LocalSearchReference] { [] }
    func rebuild(roots: [URL]) async throws -> LocalIndexStatistics {
        try await rebuild(roots: roots) { _ in }
    }
    func rebuild(
        roots: [URL],
        progress: @Sendable (LocalIndexProgress) async -> Void
    ) async throws -> LocalIndexStatistics {
        await progress(LocalIndexProgress(
            state: .indexing,
            discovered: 12,
            processed: 6,
            indexed: 4,
            skipped: 2,
            failed: 0,
            currentPath: "/tmp/Documents/report.md",
            recentErrors: []
        ))
        try await Task.sleep(for: .seconds(60))
        return LocalIndexStatistics(documents: 4, chunks: 4, state: .complete)
    }
    func statistics(roots: [URL]) -> LocalIndexStatistics {
        LocalIndexStatistics(documents: 4, chunks: 4)
    }
    func clear(roots: [URL]) {}
}

private final class CountingProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var invocation: ProcessInvocation?

    var startCount: Int { lock.withLock { count } }
    var lastInvocation: ProcessInvocation? { lock.withLock { invocation } }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        lock.withLock {
            count += 1
            self.invocation = invocation
        }
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            continuation.yield(.terminated(exitCode: 0, reason: .exit))
            continuation.finish()
        }
        return ProcessSession(events: stream, cancellation: {}, runningCheck: { false })
    }
}

private enum DelayedRunnerError: Error {
    case firstRunReleased
}

private final class SupersededRunProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var firstContinuation: CheckedContinuation<Void, Never>?

    var startCount: Int { lock.withLock { count } }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let index = lock.withLock {
            defer { count += 1 }
            return count
        }
        if index == 0 {
            await withCheckedContinuation { continuation in
                lock.withLock { firstContinuation = continuation }
            }
            throw DelayedRunnerError.firstRunReleased
        }

        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            continuation.yield(.standardOutput(Data((#"{"type":"item.completed","item":{"type":"agent_message","text":"SECOND"}}"# + "\n").utf8)))
            continuation.yield(.standardOutput(Data((#"{"type":"turn.completed"}"# + "\n").utf8)))
            continuation.yield(.terminated(exitCode: 0, reason: .exit))
            continuation.finish()
        }
        return ProcessSession(events: stream, cancellation: {}, runningCheck: { false })
    }

    func releaseFirstRun() {
        let continuation = lock.withLock {
            defer { firstContinuation = nil }
            return firstContinuation
        }
        continuation?.resume()
    }
}

private final class DelayedProbeProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var probeContinuation: CheckedContinuation<Void, Never>?

    var startCount: Int { lock.withLock { count } }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let invocationIndex = lock.withLock {
            defer { count += 1 }
            return count
        }
        if invocationIndex == 0 {
            await withCheckedContinuation { continuation in
                lock.withLock { probeContinuation = continuation }
            }
        }
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            continuation.yield(.standardOutput(Data("codex 1.0\n".utf8)))
            continuation.yield(.terminated(exitCode: 0, reason: .exit))
            continuation.finish()
        }
        return ProcessSession(events: stream, cancellation: {}, runningCheck: { false })
    }

    func releaseProbe() {
        let continuation = lock.withLock {
            defer { probeContinuation = nil }
            return probeContinuation
        }
        continuation?.resume()
    }
}

private final class ShutdownProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var cancelled = false
    private var waited = false
    private var continuation: AsyncThrowingStream<ProcessOutputEvent, any Error>.Continuation?

    var didStart: Bool { lock.withLock { started } }
    var didCancel: Bool { lock.withLock { cancelled } }
    var didWaitForCancellation: Bool { lock.withLock { waited } }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            lock.withLock {
                self.continuation = continuation
                started = true
            }
        }
        return ProcessSession(
            events: stream,
            cancellation: { [weak self] in self?.lock.withLock { self?.cancelled = true } },
            runningCheck: { true },
            cancellationAndWait: { [weak self] in
                self?.lock.withLock {
                    self?.waited = true
                    self?.continuation?.finish()
                }
            }
        )
    }
}

private final class StartupRaceProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var cancelled = false
    private var waited = false
    private var startupContinuation: CheckedContinuation<Void, Never>?

    var didStart: Bool { lock.withLock { started } }
    var didCancel: Bool { lock.withLock { cancelled } }
    var didWaitForCancellation: Bool { lock.withLock { waited } }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        lock.withLock { started = true }
        await withCheckedContinuation { continuation in
            lock.withLock { startupContinuation = continuation }
        }
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { _ in }
        return ProcessSession(
            events: stream,
            cancellation: { [weak self] in self?.lock.withLock { self?.cancelled = true } },
            runningCheck: { true },
            cancellationAndWait: { [weak self] in self?.lock.withLock { self?.waited = true } }
        )
    }

    func releaseStartup() {
        let continuation = lock.withLock {
            defer { startupContinuation = nil }
            return startupContinuation
        }
        continuation?.resume()
    }
}
