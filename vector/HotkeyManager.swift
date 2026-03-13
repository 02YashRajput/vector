import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func registerFromDefaults() {
        guard let config = UserDefaults.standard.dictionary(forKey: "hotkey_config"),
              let keyCode = config["keycode"] as? Int,
              let modifiersRaw = config["modifiers"] as? Int else {
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))
        register(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        unregister()

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("VCTR"), id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            HotkeyManager.shared.toggleWindow()
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)

        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func toggleWindow() {
        DispatchQueue.main.async {
            PanelManager.shared.toggle()
        }
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
