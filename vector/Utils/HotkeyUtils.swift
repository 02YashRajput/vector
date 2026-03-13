import Foundation
import AppKit

// MARK: - Hotkey Configuration
struct HotkeyConfiguration: Codable {
    let keyCode: UInt32
    let modifiers: UInt32
}

// MARK: - Hotkey Utilities
enum HotkeyUtils {

    /// Convert Carbon modifiers to NSEvent.ModifierFlags
    static func modifiers(from carbonFlags: UInt32) -> NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: UInt(carbonFlags))
    }

    /// Convert NSEvent.ModifierFlags to Carbon modifiers
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Get key name from keyCode (UInt32)
    static func keyName(for keyCode: UInt32) -> String {
        let mapping: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x28: "K", 0x2C: "/", 0x2D: "N",
            0x2E: "M", 0x2F: ",", 0x30: "Tab", 0x31: "Space",
            0x32: "`", 0x33: "Delete", 0x24: "Return",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x63: "F3",
            0x64: "F8", 0x65: "F9", 0x67: "F11", 0x69: "F13",
            0x6B: "F14", 0x6D: "F10", 0x6F: "F12", 0x71: "F15",
            0x76: "F4", 0x78: "F2", 0x7A: "F1",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }

    /// Get key name from keyCode (UInt16 - for NSEvent compatibility)
    static func keyName(for keyCode: UInt16) -> String {
        return keyName(for: UInt32(keyCode))
    }

    /// Build hotkey string from modifiers and keycode with custom separator
    static func buildHotkeyString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, separator: String = " + ") -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Alt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(keyName(for: keyCode))
        return parts.joined(separator: separator)
    }

    /// Get modifier symbols (⌘, ⌥, ⌃, ⇧)
    static func modifierSymbols(for modifiers: NSEvent.ModifierFlags) -> [String] {
        var symbols: [String] = []
        if modifiers.contains(.control) { symbols.append("⌃") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.command) { symbols.append("⌘") }
        return symbols
    }

    /// Get modifier names (Ctrl, Alt, Shift, Cmd)
    static func modifierNames(for modifiers: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if modifiers.contains(.control) { names.append("Ctrl") }
        if modifiers.contains(.option) { names.append("Alt") }
        if modifiers.contains(.shift) { names.append("Shift") }
        if modifiers.contains(.command) { names.append("Cmd") }
        return names
    }

    /// Build display string with custom separator and format
    /// - Parameters:
    ///   - config: The hotkey configuration
    ///   - separator: Separator between modifiers and key (default: "")
    ///   - modifierTransform: Transform for each modifier symbol (default: identity)
    ///   - keyTransform: Transform for the key name (default: identity)
    /// - Returns: Formatted string
    static func displayString(
        for config: HotkeyConfiguration,
        separator: String = "",
        modifierTransform: (String) -> String = { $0 },
        keyTransform: (String) -> String = { $0 }
    ) -> String {
        let mods = modifiers(from: config.modifiers)
        let symbols = modifierSymbols(for: mods).map(modifierTransform)
        let key = keyTransform(keyName(for: config.keyCode))
        return symbols.joined() + separator + key
    }

    /// Default display with symbols (⌘+S)
    static func defaultDisplayString(for config: HotkeyConfiguration) -> String {
        displayString(for: config, separator: "")
    }

    /// Display with names (Cmd+S)
    static func namedDisplayString(for config: HotkeyConfiguration) -> String {
        let mods = modifiers(from: config.modifiers)
        let names = modifierNames(for: mods)
        let key = keyName(for: config.keyCode)
        return (names + [key]).joined(separator: "+")
    }
}

// MARK: - Carbon Constants
private let cmdKey: UInt32 = 0x0100
private let optionKey: UInt32 = 0x0800
private let controlKey: UInt32 = 0x1000
private let shiftKey: UInt32 = 0x0200
