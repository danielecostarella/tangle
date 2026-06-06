import Carbon
import Foundation
import TangleCore

private enum GlobalShortcutID: UInt32, CaseIterable {
    case quickTransformPicker = 1
    case cleanClipboard = 2
    case cleanURL = 3
    case markdown = 4
    case pasteCleanedText = 5
    case clipboardHistory = 6

    init(action: TangleShortcutAction) {
        switch action {
        case .clipboardHistory:
            self = .clipboardHistory
        case .quickTransformPicker:
            self = .quickTransformPicker
        case .cleanClipboard:
            self = .cleanClipboard
        case .cleanURL:
            self = .cleanURL
        case .markdown:
            self = .markdown
        case .pasteCleanedText:
            self = .pasteCleanedText
        }
    }
}

struct GlobalShortcut: Identifiable, Sendable {
    let id: TangleShortcutAction
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
}

@MainActor
final class GlobalShortcutManager {
    private var registeredHotKeys: [EventHotKeyRef?] = []
    private var installedHandler: EventHandlerRef?

    func register(
        shortcutKeys: [TangleShortcutAction: TangleShortcutKey],
        clipboardHistory: @escaping @MainActor () -> Void,
        quickTransformPicker: @escaping @MainActor () -> Void,
        cleanClipboard: @escaping @MainActor () -> Void,
        cleanURL: @escaping @MainActor () -> Void,
        markdown: @escaping @MainActor () -> Void,
        pasteCleanedText: @escaping @MainActor () -> Void
    ) {
        unregisterAll()
        ShortcutActionStore.shared.removeAll()

        let actions: [(TangleShortcutAction, @MainActor () -> Void)] = [
            (.clipboardHistory, clipboardHistory),
            (.quickTransformPicker, quickTransformPicker),
            (.cleanClipboard, cleanClipboard),
            (.cleanURL, cleanURL),
            (.markdown, markdown),
            (.pasteCleanedText, pasteCleanedText)
        ]

        for (id, action) in actions {
            ShortcutActionStore.shared.setAction(for: GlobalShortcutID(action: id).rawValue) {
                Task { @MainActor in
                    action()
                }
            }
        }

        installHandlerIfNeeded()

        for shortcut in Self.shortcuts(from: shortcutKeys) {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: GlobalShortcutID(action: shortcut.id).rawValue
            )

            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                registeredHotKeys.append(hotKeyRef)
            }
        }
    }

    func unregisterAll() {
        for hotKeyRef in registeredHotKeys {
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }

        registeredHotKeys.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard installedHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutHandler,
            1,
            &eventType,
            nil,
            &installedHandler
        )
    }

    static func shortcuts(from keys: [TangleShortcutAction: TangleShortcutKey]) -> [GlobalShortcut] {
        TangleShortcutAction.allCases.compactMap { action in
            let key = keys[action] ?? TangleSettings.defaultShortcutKeys[action] ?? .c
            guard let keyCode = key.carbonKeyCode else { return nil }
            return GlobalShortcut(
                id: action,
                keyCode: keyCode,
                modifiers: UInt32(cmdKey | optionKey | controlKey),
                displayName: key.displayName
            )
        }
    }

    private static let signature: OSType = 0x546E676C
}

private extension TangleShortcutKey {
    var carbonKeyCode: UInt32? {
        switch self {
        case .c:
            return UInt32(kVK_ANSI_C)
        case .u:
            return UInt32(kVK_ANSI_U)
        case .m:
            return UInt32(kVK_ANSI_M)
        case .v:
            return UInt32(kVK_ANSI_V)
        case .x:
            return UInt32(kVK_ANSI_X)
        case .b:
            return UInt32(kVK_ANSI_B)
        case .k:
            return UInt32(kVK_ANSI_K)
        case .p:
            return UInt32(kVK_ANSI_P)
        }
    }
}

private final class ShortcutActionStore: @unchecked Sendable {
    static let shared = ShortcutActionStore()

    private let lock = NSLock()
    private var actions: [UInt32: @Sendable () -> Void] = [:]

    func setAction(for id: UInt32, action: @escaping @Sendable () -> Void) {
        lock.withLock {
            actions[id] = action
        }
    }

    func action(for id: UInt32) -> (@Sendable () -> Void)? {
        lock.withLock {
            actions[id]
        }
    }

    func removeAll() {
        lock.withLock {
            actions.removeAll()
        }
    }
}

private func globalShortcutHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else { return status }
    ShortcutActionStore.shared.action(for: hotKeyID.id)?()
    return noErr
}
