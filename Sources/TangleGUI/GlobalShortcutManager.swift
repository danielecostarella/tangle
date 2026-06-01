import Carbon
import Foundation

enum GlobalShortcutID: UInt32, CaseIterable {
    case cleanClipboard = 1
    case cleanURL = 2
    case markdown = 3
    case pasteCleanedText = 4
}

struct GlobalShortcut: Identifiable, Sendable {
    let id: GlobalShortcutID
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
}

@MainActor
final class GlobalShortcutManager {
    private var registeredHotKeys: [EventHotKeyRef?] = []
    private var installedHandler: EventHandlerRef?

    func registerDefaults(
        cleanClipboard: @escaping @MainActor () -> Void,
        cleanURL: @escaping @MainActor () -> Void,
        markdown: @escaping @MainActor () -> Void,
        pasteCleanedText: @escaping @MainActor () -> Void
    ) {
        unregisterAll()
        ShortcutActionStore.shared.removeAll()

        let actions: [(GlobalShortcutID, @MainActor () -> Void)] = [
            (.cleanClipboard, cleanClipboard),
            (.cleanURL, cleanURL),
            (.markdown, markdown),
            (.pasteCleanedText, pasteCleanedText)
        ]

        for (id, action) in actions {
            ShortcutActionStore.shared.setAction(for: id.rawValue) {
                Task { @MainActor in
                    action()
                }
            }
        }

        installHandlerIfNeeded()

        for shortcut in Self.defaultShortcuts {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: shortcut.id.rawValue
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

    static let defaultShortcuts: [GlobalShortcut] = [
        GlobalShortcut(
            id: .cleanClipboard,
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(cmdKey | optionKey | controlKey),
            displayName: "⌃⌥⌘C"
        ),
        GlobalShortcut(
            id: .cleanURL,
            keyCode: UInt32(kVK_ANSI_U),
            modifiers: UInt32(cmdKey | optionKey | controlKey),
            displayName: "⌃⌥⌘U"
        ),
        GlobalShortcut(
            id: .markdown,
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(cmdKey | optionKey | controlKey),
            displayName: "⌃⌥⌘M"
        ),
        GlobalShortcut(
            id: .pasteCleanedText,
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | optionKey | controlKey),
            displayName: "⌃⌥⌘V"
        )
    ]

    private static let signature: OSType = 0x546E676C
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
