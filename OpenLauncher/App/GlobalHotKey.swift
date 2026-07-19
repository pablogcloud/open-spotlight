import Carbon
import Foundation

enum LauncherShortcut: String, CaseIterable, Sendable {
    case optionSpace
    case controlSpace
    case commandShiftSpace
    case commandSpace

    static let defaultsKey = "globalShortcut"

    var title: String {
        switch self {
        case .optionSpace: "Option-Space"
        case .controlSpace: "Control-Space"
        case .commandShiftSpace: "Command-Shift-Space"
        case .commandSpace: "Command-Space"
        }
    }

    var glyph: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .controlSpace: "⌃ Space"
        case .commandShiftSpace: "⌘⇧ Space"
        case .commandSpace: "⌘ Space"
        }
    }

    fileprivate var modifiers: UInt32 {
        switch self {
        case .optionSpace: UInt32(optionKey)
        case .controlSpace: UInt32(controlKey)
        case .commandShiftSpace: UInt32(cmdKey | shiftKey)
        case .commandSpace: UInt32(cmdKey)
        }
    }

    static func stored(in defaults: UserDefaults = .standard) -> LauncherShortcut {
        defaults.string(forKey: defaultsKey).flatMap(LauncherShortcut.init(rawValue:)) ?? .optionSpace
    }

    func persist(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}

final class GlobalHotKey: @unchecked Sendable {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let bridge: HotKeyBridge

    init(
        shortcut: LauncherShortcut,
        handler: @escaping @MainActor @Sendable () -> Void
    ) throws {
        bridge = HotKeyBridge(handler: handler)

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotKeyBridge>.fromOpaque(userData).takeUnretainedValue().fire()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(bridge).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.eventHandlerInstallationFailed(handlerStatus)
        }

        let identifier = EventHotKeyID(signature: Self.signature("OLCH"), id: 1)
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registrationStatus == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            throw GlobalHotKeyError.registrationFailed(shortcut, registrationStatus)
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private static func signature(_ value: String) -> OSType {
        value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}

enum GlobalHotKeyError: LocalizedError, Equatable {
    case eventHandlerInstallationFailed(OSStatus)
    case registrationFailed(LauncherShortcut, OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandlerInstallationFailed(status):
            "Could not install the shortcut event handler (\(status))."
        case let .registrationFailed(shortcut, status):
            "\(shortcut.title) is unavailable (\(status)). Choose another shortcut from the menu bar."
        }
    }
}

private final class HotKeyBridge: @unchecked Sendable {
    private let handler: @MainActor @Sendable () -> Void

    init(handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    func fire() {
        Task { @MainActor in handler() }
    }
}
