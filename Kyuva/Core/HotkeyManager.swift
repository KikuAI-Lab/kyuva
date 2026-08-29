import Carbon
import Foundation

/// Registers only Kyuva's explicit shortcuts with macOS.
///
/// `RegisterEventHotKey` avoids observing arbitrary keystrokes, so Kyuva does
/// not need Accessibility or Input Monitoring permission for its controls.
final class HotkeyManager {
    enum Hotkey: UInt32, CaseIterable {
        case speedUp = 1
        case speedDown
        case togglePause
        case toggleVoiceFollow
        case reset
        case toggleOverlay
        case nextDisplay

        var shortcut: Shortcut {
            switch self {
            case .speedUp:
                return Shortcut(keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥→")
            case .speedDown:
                return Shortcut(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥←")
            case .togglePause:
                return Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥Space")
            case .toggleVoiceFollow:
                return Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥V")
            case .reset:
                return Shortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥R")
            case .toggleOverlay:
                return Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥T")
            case .nextDisplay:
                return Shortcut(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥D")
            }
        }
    }

    struct Shortcut: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
        let display: String
    }

    private static let signature: OSType = 0x4B595556 // "KYUV"

    private var handlers: [Hotkey: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef] = []

    init() {
        installEventHandler()
        registerSystemHotkeys()
    }

    deinit {
        for hotkey in registeredHotkeys {
            UnregisterEventHotKey(hotkey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        handlers[hotkey] = handler
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<HotkeyManager>
                .fromOpaque(userData)
                .takeUnretainedValue()
            return manager.handle(event)
        }

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            print("[Kyuva] Failed to install the global shortcut handler: \(status)")
        }
    }

    private func registerSystemHotkeys() {
        guard eventHandler != nil else { return }

        for hotkey in Hotkey.allCases {
            let shortcut = hotkey.shortcut
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: Self.signature, id: hotkey.rawValue)
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                identifier,
                GetApplicationEventTarget(),
                0,
                &reference
            )

            if status == noErr, let reference {
                registeredHotkeys.append(reference)
            } else {
                print("[Kyuva] Could not register shortcut \(shortcut.display): \(status)")
            }
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )

        guard status == noErr,
              identifier.signature == Self.signature,
              let hotkey = Hotkey(rawValue: identifier.id),
              let handler = handlers[hotkey] else {
            return OSStatus(eventNotHandledErr)
        }

        handler()
        return noErr
    }
}

extension Notification.Name {
    static let toggleVoiceFollow = Notification.Name("ToggleVoiceFollow")
}
