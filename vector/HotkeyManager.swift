import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let defaultsKey = "hotkey_configs"

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [String: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var nameToId: [String: UInt32] = [:]
    private var nextId: UInt32 = 1

    private init() {}

    // MARK: - Public API

    func registerFromDefaults() {
        ensureHandler()

        guard let configs = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: [String: Any]] else { return }

        for (name, entry) in configs {
            guard let keyCode = entry["keycode"] as? Int,
                  let modifiersRaw = entry["modifiers"] as? Int else { continue }
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))
            let filterStr = entry["filter"] as? String
            let action = Self.buildAction(filter: filterStr)
            registerInternal(name: name, keyCode: UInt32(keyCode), modifiers: modifiers, action: action)
        }
    }

    /// Register a hotkey and persist it. Single call to set up everything.
    func set(name: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, display: String, filter: CommandType? = nil) {
        let action = Self.buildAction(filter: filter?.rawValue)
        let success = registerInternal(name: name, keyCode: UInt32(keyCode), modifiers: modifiers, action: action)

        guard success else { return }

        // Persist only after successful registration
        var configs = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: [String: Any]] ?? [:]
        var entry: [String: Any] = [
            "keycode": Int(keyCode),
            "modifiers": Int(modifiers.rawValue),
            "display": display
        ]
        if let filter { entry["filter"] = filter.rawValue }
        configs[name] = entry
        UserDefaults.standard.set(configs, forKey: Self.defaultsKey)
    }

    /// Unregister a hotkey and remove its persisted config.
    func remove(name: String) {
        // Unregister
        if let ref = hotKeyRefs.removeValue(forKey: name) {
            UnregisterEventHotKey(ref)
        }
        if let id = nameToId[name] {
            actions.removeValue(forKey: id)
        }

        // Remove config
        var configs = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: [String: Any]] ?? [:]
        configs.removeValue(forKey: name)
        UserDefaults.standard.set(configs, forKey: Self.defaultsKey)
    }

    func loadConfig(name: String) -> (keyCode: Int, modifiers: Int, display: String, filter: CommandType?)? {
        guard let configs = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: [String: Any]],
              let entry = configs[name],
              let keyCode = entry["keycode"] as? Int,
              let modifiers = entry["modifiers"] as? Int,
              let display = entry["display"] as? String else { return nil }
        let filter: CommandType? = (entry["filter"] as? String).flatMap { CommandType(rawValue: $0) }
        return (keyCode, modifiers, display, filter)
    }

    // MARK: - Internals

    @discardableResult
    private func registerInternal(name: String, keyCode: UInt32, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) -> Bool {
        // Unregister existing if any
        if let ref = hotKeyRefs.removeValue(forKey: name) {
            UnregisterEventHotKey(ref)
        }
        if let id = nameToId[name] {
            actions.removeValue(forKey: id)
        }
        ensureHandler()

        let id = assignId(for: name)
        actions[id] = action

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("VCTR"), id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs[name] = ref
            return true
        }
        actions.removeValue(forKey: id)
        return false
    }

    private func ensureHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            HotkeyManager.shared.actions[hkID.id]?()
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
    }

    private func assignId(for name: String) -> UInt32 {
        if let existing = nameToId[name] { return existing }
        let id = nextId
        nextId += 1
        nameToId[name] = id
        return id
    }

    static func buildAction(filter filterStr: String?) -> () -> Void {
        let filterType: CommandType? = filterStr.flatMap { CommandType(rawValue: $0) }
        return { DispatchQueue.main.async { PanelManager.shared.toggle(filterType: filterType) } }
    }

}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
