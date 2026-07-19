import AppKit
import SwiftUI

struct OpenSpotlightOnboardingView: View {
    @Bindable var model: LauncherViewModel
    let initialShortcut: LauncherShortcut
    let onConnect: (ProviderIdentifier) -> Void
    let onRecheck: () -> Void
    let onSelectShortcut: (LauncherShortcut) -> Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var shortcut: LauncherShortcut

    init(
        model: LauncherViewModel,
        initialShortcut: LauncherShortcut,
        onConnect: @escaping (ProviderIdentifier) -> Void,
        onRecheck: @escaping () -> Void,
        onSelectShortcut: @escaping (LauncherShortcut) -> Bool,
        onFinish: @escaping () -> Void
    ) {
        self.model = model
        self.initialShortcut = initialShortcut
        self.onConnect = onConnect
        self.onRecheck = onRecheck
        self.onSelectShortcut = onSelectShortcut
        self.onFinish = onFinish
        _shortcut = State(initialValue: initialShortcut)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcome
                case 1: providers
                default: shortcutChoice
                }
            }
            .id(page)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: page == 0 ? 8 : 18)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if page > 0 {
                    Button("Back") { changePage(to: page - 1) }
                        .buttonStyle(.plain)
                }
                Spacer()
                Button(page == 2 ? "Open Spotlight" : "Continue") {
                    if page == 2 { onFinish() } else { changePage(to: page + 1) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(page == 1 && !hasConnectedProvider)
            }
            .padding(28)
        }
        .frame(width: 620, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.42, dampingFraction: 0.88), value: page)
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .regular))
                .frame(width: 112, height: 112)
                .spotlightOnboardingGlass()
                .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text("Open Spotlight")
                    .font(.system(size: 34, weight: .semibold))
                Text("Your subscriptions. One search field.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 28)
    }

    private var providers: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect your AI")
                    .font(.system(size: 28, weight: .semibold))
                Text("Open Spotlight uses the CLI sessions already on this Mac.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            ProviderConnectionList(model: model, onConnect: onConnect)

            Button(action: onRecheck) {
                Label("Check Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(34)
    }

    private var shortcutChoice: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose a shortcut")
                    .font(.system(size: 28, weight: .semibold))
                Text("You can change it later from the menu bar.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(LauncherShortcut.allCases, id: \.self) { option in
                    Button {
                        if onSelectShortcut(option) { shortcut = option }
                    } label: {
                        HStack {
                            Text(option.title)
                            Spacer()
                            Text(option.glyph)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: shortcut == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(shortcut == option ? Color.accentColor : Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if option != LauncherShortcut.allCases.last { Divider().padding(.leading, 16) }
                }
            }
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(34)
    }

    private var hasConnectedProvider: Bool {
        model.providerDescriptors.values.contains {
            if case .available = $0.status { return true }
            return false
        }
    }

    private func changePage(to nextPage: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.4, dampingFraction: 0.88)) {
            page = nextPage
        }
    }
}

struct OpenSpotlightSettingsView: View {
    @Bindable var model: LauncherViewModel
    @Bindable var preferences: LauncherPreferences
    let initialShortcut: LauncherShortcut
    let onConnect: (ProviderIdentifier) -> Void
    let onRecheck: () -> Void
    let onSelectShortcut: (LauncherShortcut) -> Bool

    @State private var shortcut: LauncherShortcut

    init(
        model: LauncherViewModel,
        initialShortcut: LauncherShortcut,
        onConnect: @escaping (ProviderIdentifier) -> Void,
        onRecheck: @escaping () -> Void,
        onSelectShortcut: @escaping (LauncherShortcut) -> Bool
    ) {
        self.model = model
        _preferences = Bindable(wrappedValue: model.preferences)
        self.initialShortcut = initialShortcut
        self.onConnect = onConnect
        self.onRecheck = onRecheck
        self.onSelectShortcut = onSelectShortcut
        _shortcut = State(initialValue: initialShortcut)
    }

    var body: some View {
        Form {
            Section("Providers") {
                ProviderConnectionList(
                    model: model,
                    onConnect: onConnect,
                    drawsBackground: false
                )

                Picker("Default provider", selection: defaultProviderBinding) {
                    ForEach(ProviderIdentifier.allCases, id: \.self) { provider in
                        HStack(spacing: 7) {
                            ProviderLogo(provider: provider, size: 18)
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }

                HStack {
                    Text("Provider status")
                    Spacer()
                    Button("Check Again", action: onRecheck)
                }
            }

            Section("Launcher") {
                Picker("Keyboard shortcut", selection: $shortcut) {
                    ForEach(LauncherShortcut.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .onChange(of: shortcut) { oldValue, newValue in
                    if !onSelectShortcut(newValue) { shortcut = oldValue }
                }

                Picker("Screen position", selection: $preferences.placement) {
                    ForEach(LauncherPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }

                Picker("Answer size", selection: $preferences.resultSize) {
                    ForEach(LauncherResultSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }

                Toggle("Clear the previous query when opening", isOn: $preferences.clearQueryOnOpen)
                Toggle("Reveal the provider control from the magnifier", isOn: $preferences.revealProviderOnHover)
                Toggle("Close when clicking outside", isOn: $preferences.dismissOnOutsideClick)
            }

            Section("Appearance") {
                Picker("Glass contrast", selection: $preferences.glassContrast) {
                    ForEach(LauncherGlassContrast.allCases) { contrast in
                        Text(contrast.title).tag(contrast)
                    }
                }
                Toggle("Reduce launcher motion", isOn: $preferences.reduceMotion)
                Text("The macOS Reduce Motion setting always takes priority.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                LabeledContent("File confirmation") {
                    Label("Always on", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                Text("Open Spotlight asks before sending attached file content to a CLI provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Local Index") {
                LabeledContent("Status") {
                    if model.isIndexing {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text("Scanning")
                        }
                    } else {
                        Text(indexStatusText)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.indexProgress.discovered > 0 {
                    LabeledContent("Current run") {
                        Text(
                            "\(model.indexProgress.indexed.formatted()) indexed · "
                                + "\(model.indexProgress.skipped.formatted()) skipped · "
                                + "\(model.indexProgress.failed.formatted()) failed"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                ForEach(preferences.indexedFolderPaths, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            model.removeIndexFolder(path: path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(URL(fileURLWithPath: path).lastPathComponent)")
                    }
                }

                HStack {
                    Button("Add Folder…", action: chooseIndexFolder)
                    if model.isIndexing {
                        Button("Cancel", action: model.cancelLocalIndexing)
                    } else {
                        Button("Refresh", action: model.refreshLocalIndex)
                            .disabled(preferences.indexedFolderPaths.isEmpty)
                    }
                    Spacer()
                    Button("Clear Index", action: model.clearLocalIndex)
                        .disabled(model.indexedDocumentCount == 0 || model.isIndexing)
                }

                if let error = model.indexError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let warning = model.indexWarning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }

                ForEach(Array(model.indexProgress.recentErrors.prefix(3).enumerated()), id: \.offset) { _, issue in
                    Text(issue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text("Only specific folders you add are indexed. This is an early text-only index and is not yet resumable across relaunches. Search stays on this Mac; file content is never sent to a provider unless you explicitly attach and confirm it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Text("Provider names and logos belong to their respective owners.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 640, height: 720)
    }

    private var defaultProviderBinding: Binding<ProviderIdentifier> {
        Binding(
            get: { model.selectedProvider },
            set: { provider in
                model.selectProvider(provider)
                if model.selectedProviderNeedsSetup { onConnect(provider) }
            }
        )
    }

    private var indexStatusText: String {
        switch model.indexRunState {
        case .idle:
            model.indexedDocumentCount == 0
                ? "Not indexed"
                : "\(model.indexedDocumentCount.formatted()) documents · unverified partial state"
        case .indexing: "Scanning"
        case .cancelled: "Cancelled · \(model.indexedDocumentCount.formatted()) documents retained"
        case .partial: "Partial · \(model.indexedDocumentCount.formatted()) documents"
        case .complete: "Completed · \(model.indexedDocumentCount.formatted()) documents"
        case .failed: "Failed"
        case .quarantined: "Unsafe legacy index quarantined"
        }
    }

    private func chooseIndexFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to index"
        panel.prompt = "Add Folder"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.addIndexFolder(url)
    }
}

private struct ProviderConnectionList: View {
    @Bindable var model: LauncherViewModel
    let onConnect: (ProviderIdentifier) -> Void
    var drawsBackground = true

    var body: some View {
        if drawsBackground {
            rows
                .background(
                    .quaternary.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        } else {
            rows
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(ProviderIdentifier.allCases, id: \.self) { provider in
                HStack(spacing: 14) {
                    ProviderLogo(provider: provider, size: 30)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.system(size: 16, weight: .medium))
                        Text(statusText(provider))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    switch model.providerDescriptors[provider]?.status {
                    case .available:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Connected")
                    case .probing, .unknown, nil:
                        ProgressView().controlSize(.small)
                    case .authenticationRequired:
                        Button("Connect") { onConnect(provider) }
                            .buttonStyle(.bordered)
                    case .unavailable:
                        Button("Install") { onConnect(provider) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 62)

                if provider != ProviderIdentifier.allCases.last { Divider().padding(.leading, 58) }
            }
        }
    }

    private func statusText(_ provider: ProviderIdentifier) -> String {
        switch model.providerDescriptors[provider]?.status {
        case .available: "Connected"
        case .authenticationRequired: "Sign in required"
        case .unavailable: "CLI not found"
        case .probing, .unknown, nil: "Checking"
        }
    }
}

@MainActor
final class OpenSpotlightSettingsWindowController {
    private let window: NSWindow

    init(rootView: OpenSpotlightSettingsView) {
        window = Self.makeWindow(
            title: "Open Spotlight Settings",
            contentSize: NSSize(width: 640, height: 720),
            rootView: rootView
        )
    }

    func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow<Content: View>(
        title: String,
        contentSize: NSSize,
        rootView: Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        return window
    }
}

@MainActor
final class OpenSpotlightOnboardingWindowController {
    private let window: NSWindow

    init(rootView: OpenSpotlightOnboardingView) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Open Spotlight"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
    }

    func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.orderOut(nil)
    }
}

private extension View {
    @ViewBuilder
    func spotlightOnboardingGlass() -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(.regularMaterial, in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
        }
    }
}
