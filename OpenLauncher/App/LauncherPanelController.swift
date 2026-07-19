import AppKit
import QuartzCore
import SwiftUI

enum LauncherPanelGeometry {
    static func resizedFrame(
        from frame: CGRect,
        toHeight height: CGFloat,
        anchoredTopY: CGFloat?
    ) -> CGRect {
        var target = frame
        target.origin.y = (anchoredTopY ?? frame.maxY) - height
        target.size.height = height
        return target
    }
}

@MainActor
final class LauncherPanelController {
    private let panel: LauncherPanel
    let model: LauncherViewModel
    private var hotKey: GlobalHotKey?
    private(set) var shortcut: LauncherShortcut
    nonisolated(unsafe) private var localClickMonitor: Any?
    nonisolated(unsafe) private var globalClickMonitor: Any?
    private var interactionProtection = LauncherInteractionProtection()
    private var panelTopAnchor: CGFloat?

    init() {
        shortcut = LauncherShortcut.stored()
        model = LauncherViewModel()
        panel = LauncherPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: LauncherMetrics.surfaceWidth,
                height: LauncherMetrics.controlSize
            ),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        model.onRequestClose = { [weak self] in self?.hide() }
        model.onRequestResize = { [weak self] height in self?.resize(to: height) }
        let hostingView = NSHostingView(rootView: LauncherView(model: model))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // A window-server shadow follows the NSPanel's rectangular frame. That
        // frame becomes visible when the provider glass separates from search,
        // so each glass shape owns its shadow instead.
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none

        do {
            hotKey = try GlobalHotKey(shortcut: shortcut) { [weak self] in self?.toggle() }
        } catch {
            model.shortcutWarning = error.localizedDescription
        }
        model.shortcutLabel = shortcut.glyph
        installClickOutsideMonitors()
    }

    @discardableResult
    func setShortcut(_ newShortcut: LauncherShortcut) -> Bool {
        guard newShortcut != shortcut else { return true }
        do {
            let replacement = try GlobalHotKey(shortcut: newShortcut) { [weak self] in self?.toggle() }
            hotKey = replacement
            shortcut = newShortcut
            newShortcut.persist()
            model.shortcutLabel = newShortcut.glyph
            model.shortcutWarning = nil
            return true
        } catch {
            model.shortcutWarning = error.localizedDescription
            show()
            return false
        }
    }

    func shutdown() async {
        await model.shutdown()
    }

    func setProviderSetupHandler(_ handler: @escaping @MainActor (ProviderIdentifier) -> Void) {
        model.onRequestProviderSetup = handler
    }

    func setSettingsHandler(_ handler: @escaping @MainActor () -> Void) {
        model.onRequestSettings = handler
    }

    func beginExternalInteraction() {
        interactionProtection.beginExternalInteraction()
    }

    func cancelExternalInteraction() {
        interactionProtection.cancelExternalInteraction()
    }

    func applicationDidResignActive() {
        interactionProtection.applicationDidResignActive()
    }

    func applicationDidBecomeActive() -> Bool {
        interactionProtection.applicationDidBecomeActive()
    }

    func show() {
        if !panel.isVisible { model.prepareForPresentation() }
        let targetOrigin = panelOrigin()
        let wasVisible = panel.isVisible
        let reduceMotion = shouldReduceMotion

        if !wasVisible {
            panelTopAnchor = targetOrigin.y + panel.frame.height
            panel.alphaValue = 0
            panel.setFrameOrigin(reduceMotion
                ? targetOrigin
                : NSPoint(x: targetOrigin.x, y: targetOrigin.y - 10))
        }
        panel.makeKeyAndOrderFront(nil)
        model.focusPrompt()

        guard !wasVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.08 : 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            if !reduceMotion { panel.animator().setFrameOrigin(targetOrigin) }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func hide() {
        if model.runState == .streaming { model.cancel() }
        panel.orderOut(nil)
    }

    private func panelOrigin() -> NSPoint {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let frame = screen?.frame else { return panel.frame.origin }
        return model.preferences.placement.panelOrigin(in: frame, panelSize: panel.frame.size)
    }

    private func resize(to height: CGFloat) {
        guard abs(panel.frame.height - height) > 0.5 else { return }
        let target = LauncherPanelGeometry.resizedFrame(
            from: panel.frame,
            toHeight: height,
            anchoredTopY: panelTopAnchor
        )
        guard panel.isVisible else {
            panel.setFrame(target, display: false)
            return
        }

        let reduceMotion = shouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.08 : 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }

    private func installClickOutsideMonitors() {
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            self?.hideIfClickOutside()
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            Task { @MainActor in self?.hideIfClickOutside() }
        }
    }

    private func hideIfClickOutside() {
        let clickIsInsidePanel = panel.frame.contains(NSEvent.mouseLocation)
        guard interactionProtection.shouldDismissOutsideClick(
            preferenceEnabled: model.preferences.dismissOnOutsideClick,
            panelVisible: panel.isVisible,
            hasModalWindow: NSApplication.shared.modalWindow != nil,
            clickIsInsidePanel: clickIsInsidePanel,
            runState: model.runState
        ) else { return }
        hide()
    }

    private var shouldReduceMotion: Bool {
        model.preferences.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    deinit {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
    }
}

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
