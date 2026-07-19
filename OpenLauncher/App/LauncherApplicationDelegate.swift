import AppKit

@MainActor
final class LauncherApplicationDelegate: NSObject, NSApplicationDelegate {
    private var panelController: LauncherPanelController?
    private var settingsController: OpenSpotlightSettingsWindowController?
    private var onboardingController: OpenSpotlightOnboardingWindowController?
    private var statusItem: NSStatusItem?
    private var shortcutItems: [LauncherShortcut: NSMenuItem] = [:]
    private var terminationInProgress = false
    private let authenticationCoordinator = ProviderAuthenticationCoordinator()

    private static let onboardingKey = "didCompleteOpenSpotlightOnboarding"

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["OPEN_LAUNCHER_PREVIEW_APPEARANCE"] == "light" {
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        }
        #endif
        NSApplication.shared.setActivationPolicy(.accessory)
        let controller = LauncherPanelController()
        panelController = controller
        controller.setProviderSetupHandler { [weak self] provider in self?.connect(provider) }
        controller.setSettingsHandler { [weak self] in self?.showSettings() }
        installStatusItem()
        if UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            controller.show()
        } else {
            showOnboarding()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        panelController?.applicationDidResignActive()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard panelController?.applicationDidBecomeActive() == true,
              let model = panelController?.model
        else { return }
        Task { @MainActor in
            await model.reprobeSelectedProvider()
            model.finishProviderSetup()
        }
    }

    @objc func showLauncher() {
        panelController?.show()
    }

    @objc private func showSettings() {
        guard let panelController else { return }
        if panelController.model.runState != .streaming { panelController.hide() }
        if settingsController == nil {
            settingsController = OpenSpotlightSettingsWindowController(
                rootView: OpenSpotlightSettingsView(
                    model: panelController.model,
                    initialShortcut: panelController.shortcut,
                    onConnect: { [weak self] provider in self?.connect(provider) },
                    onRecheck: { [weak self] in self?.recheckProviders() },
                    onSelectShortcut: { [weak self] shortcut in self?.applyShortcut(shortcut) ?? false }
                )
            )
        }
        settingsController?.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true
        Task { @MainActor [weak self] in
            await self?.panelController?.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func selectShortcut(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let shortcut = LauncherShortcut(rawValue: rawValue),
              panelController?.setShortcut(shortcut) == true
        else { return }
        updateShortcutMenuState()
    }

    private func applyShortcut(_ shortcut: LauncherShortcut) -> Bool {
        guard panelController?.setShortcut(shortcut) == true else { return false }
        updateShortcutMenuState()
        return true
    }

    private func connect(_ provider: ProviderIdentifier) {
        panelController?.beginExternalInteraction()
        do {
            try authenticationCoordinator.begin(for: provider)
        } catch {
            panelController?.cancelExternalInteraction()
            panelController?.model.finishProviderSetup()
            let alert = NSAlert(error: error)
            alert.messageText = "Could not start \(provider.displayName) setup"
            alert.runModal()
        }
    }

    private func recheckProviders() {
        guard let model = panelController?.model else { return }
        Task { await model.probeAllProviders() }
    }

    private func showOnboarding() {
        guard let panelController else { return }
        onboardingController = OpenSpotlightOnboardingWindowController(
            rootView: OpenSpotlightOnboardingView(
                model: panelController.model,
                initialShortcut: panelController.shortcut,
                onConnect: { [weak self] provider in self?.connect(provider) },
                onRecheck: { [weak self] in self?.recheckProviders() },
                onSelectShortcut: { [weak self] shortcut in self?.applyShortcut(shortcut) ?? false },
                onFinish: { [weak self] in self?.finishOnboarding() }
            )
        )
        onboardingController?.show()
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        onboardingController?.close()
        onboardingController = nil
        panelController?.show()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Open Spotlight")

        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Spotlight", action: #selector(showLauncher), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let shortcutMenu = NSMenu()
        for shortcut in LauncherShortcut.allCases {
            let menuItem = NSMenuItem(title: shortcut.title, action: #selector(selectShortcut), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = shortcut.rawValue
            shortcutMenu.addItem(menuItem)
            shortcutItems[shortcut] = menuItem
        }
        let shortcutRoot = NSMenuItem(title: "Global Shortcut", action: nil, keyEquivalent: "")
        shortcutRoot.submenu = shortcutMenu
        menu.addItem(shortcutRoot)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Open Spotlight", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        updateShortcutMenuState()
    }

    private func updateShortcutMenuState() {
        let selected = panelController?.shortcut
        for (shortcut, item) in shortcutItems {
            item.state = shortcut == selected ? .on : .off
        }
    }
}
