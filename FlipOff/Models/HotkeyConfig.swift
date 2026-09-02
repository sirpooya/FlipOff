import AppKit
import Carbon

struct HotkeyConfig {
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let displayKey = "hotkeyDisplay"
    private static let enabledKey = "hotkeyEnabled"
    static let requireAuthenticationToUnlockKey = "requireAuthenticationToUnlock"

    static let separateUnlockHotkeyKey = "separateUnlockHotkey"
    static let unlockKeyCodeKey = "unlockHotkeyKeyCode"
    static let unlockModifiersKey = "unlockHotkeyModifiers"
    static let unlockDisplayKey = "unlockHotkeyDisplay"

    static let defaultKeyCode = 37
    static let defaultModifiers = cmdKey | shiftKey
    static let defaultDisplay = "Cmd+Shift+L"
    static let defaultEnabled = true
    static let defaultRequireAuthenticationToUnlock = false

    static let defaultSeparateUnlockHotkey = false
    static let defaultUnlockKeyCode = 32
    static let defaultUnlockModifiers = cmdKey | shiftKey
    static let defaultUnlockDisplay = "Cmd+Shift+U"

    static var keyCode: Int {
        UserDefaults.standard.object(forKey: keyCodeKey) as? Int ?? defaultKeyCode
    }

    static var modifiers: Int {
        UserDefaults.standard.object(forKey: modifiersKey) as? Int ?? defaultModifiers
    }

    static var display: String {
        UserDefaults.standard.string(forKey: displayKey) ?? defaultDisplay
    }

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? defaultEnabled
    }

    static var separateUnlockHotkey: Bool {
        UserDefaults.standard.object(forKey: separateUnlockHotkeyKey) as? Bool ?? defaultSeparateUnlockHotkey
    }

    /// The combo that ends a lock. Falls back to the lock hotkey whenever the
    /// separate-unlock option is off, so every caller can ask for it unconditionally.
    static var unlockKeyCode: Int {
        guard separateUnlockHotkey else { return keyCode }
        return UserDefaults.standard.object(forKey: unlockKeyCodeKey) as? Int ?? defaultUnlockKeyCode
    }

    static var unlockModifiers: Int {
        guard separateUnlockHotkey else { return modifiers }
        return UserDefaults.standard.object(forKey: unlockModifiersKey) as? Int ?? defaultUnlockModifiers
    }

    static var unlockDisplay: String {
        guard separateUnlockHotkey else { return display }
        return UserDefaults.standard.string(forKey: unlockDisplayKey) ?? defaultUnlockDisplay
    }

    static var requiresAuthenticationToUnlock: Bool {
        UserDefaults.standard.object(forKey: requireAuthenticationToUnlockKey) as? Bool ?? defaultRequireAuthenticationToUnlock
    }

    static func saveKeyCode(_ value: Int) {
        UserDefaults.standard.set(value, forKey: keyCodeKey)
    }

    static func saveModifiers(_ value: Int) {
        UserDefaults.standard.set(value, forKey: modifiersKey)
    }

    static func saveDisplay(_ value: String) {
        UserDefaults.standard.set(value, forKey: displayKey)
    }

    static func saveEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: enabledKey)
    }

    static func saveRequireAuthenticationToUnlock(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: requireAuthenticationToUnlockKey)
    }

    static func saveSeparateUnlockHotkey(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: separateUnlockHotkeyKey)
    }

    static func saveUnlockKeyCode(_ value: Int) {
        UserDefaults.standard.set(value, forKey: unlockKeyCodeKey)
    }

    static func saveUnlockModifiers(_ value: Int) {
        UserDefaults.standard.set(value, forKey: unlockModifiersKey)
    }

    static func saveUnlockDisplay(_ value: String) {
        UserDefaults.standard.set(value, forKey: unlockDisplayKey)
    }

    // MARK: - System Shortcut Conflict Detection

    /// Returns a description of the conflicting system shortcut, or nil if no conflict.
    static func systemConflict(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String? {
        let cmd = modifiers.contains(.command)
        let shift = modifiers.contains(.shift)
        let opt = modifiers.contains(.option)
        let ctrl = modifiers.contains(.control)

        // Cmd-only shortcuts
        if cmd && !shift && !opt && !ctrl {
            switch keyCode {
            case 12: return "Cmd+Q (Quit)"           // Q
            case 13: return "Cmd+W (Close Window)"    // W
            case 0: return "Cmd+A (Select All)"       // A
            case 8: return "Cmd+C (Copy)"             // C
            case 9: return "Cmd+V (Paste)"            // V
            case 7: return "Cmd+X (Cut)"              // X
            case 6: return "Cmd+Z (Undo)"             // Z
            case 3: return "Cmd+F (Find)"             // F
            case 4: return "Cmd+H (Hide)"             // H
            case 46: return "Cmd+M (Minimize)"        // M
            case 35: return "Cmd+P (Print)"           // P
            case 1: return "Cmd+S (Save)"             // S
            case 17: return "Cmd+T (New Tab)"         // T
            case 32: return "Cmd+U (Underline)"       // U
            case 45: return "Cmd+N (New)"             // N
            case 31: return "Cmd+O (Open)"            // O
            case 48: return "Cmd+Tab (App Switcher)"  // Tab
            case 49: return "Cmd+Space (Spotlight)"   // Space
            case 44: return "Cmd+, (Settings)"        // ,
            default: break
            }
        }

        // Cmd+Shift shortcuts
        if cmd && shift && !opt && !ctrl {
            switch keyCode {
            case 6: return "Cmd+Shift+Z (Redo)"
            case 30: return "Cmd+Shift+] (Next Tab)"
            case 33: return "Cmd+Shift+[ (Previous Tab)"
            default: break
            }
        }

        // Ctrl+Cmd shortcuts
        if cmd && ctrl && !shift && !opt {
            switch keyCode {
            case 12: return "Ctrl+Cmd+Q (Lock Screen)"
            case 36: return "Ctrl+Cmd+F (Fullscreen)"  // Return key
            default: break
            }
        }

        return nil
    }
}
