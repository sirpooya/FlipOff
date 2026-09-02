import AppKit
import Carbon

struct HotkeyConfig {
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let displayKey = "hotkeyDisplay"
    private static let enabledKey = "hotkeyEnabled"

    static let separateUnlockHotkeyKey = "separateUnlockHotkey"
    static let unlockKeyCodeKey = "unlockHotkeyKeyCode"
    static let unlockModifiersKey = "unlockHotkeyModifiers"
    static let unlockDisplayKey = "unlockHotkeyDisplay"

    static let defaultKeyCode = 37
    static let defaultModifiers = cmdKey | shiftKey
    static let defaultDisplay = "Cmd+Shift+L"
    static let defaultEnabled = true

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
        return storedUnlockKeyCode ?? defaultUnlockKeyCode
    }

    static var unlockModifiers: Int {
        guard separateUnlockHotkey else { return modifiers }
        return storedUnlockModifiers ?? defaultUnlockModifiers
    }

    static var unlockDisplay: String {
        guard separateUnlockHotkey else { return display }
        return UserDefaults.standard.string(forKey: unlockDisplayKey) ?? defaultUnlockDisplay
    }

    // MARK: - Raw stored unlock combo
    //
    // The accessors above collapse onto the lock hotkey while the option is off,
    // which is what every runtime caller wants and exactly what a duplicate check
    // must not see: it would be comparing the lock combo against itself and would
    // pass every time. These report what is actually on disk, and `nil` when the
    // user has never recorded an unlock combo at all — a distinction that matters,
    // because the Cmd+Shift+U default is not a claim the user has made.

    static var storedUnlockKeyCode: Int? {
        UserDefaults.standard.object(forKey: unlockKeyCodeKey) as? Int
    }

    static var storedUnlockModifiers: Int? {
        UserDefaults.standard.object(forKey: unlockModifiersKey) as? Int
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

    // MARK: - Lock / Unlock Collision Detection

    /// Which of the two shortcuts is being read or written.
    enum HotkeyRole {
        case lock
        case unlock

        var other: HotkeyRole { self == .lock ? .unlock : .lock }
        var label: String { self == .lock ? "lock" : "unlock" }
    }

    /// Non-nil when assigning this combo to `role` would give both shortcuts the
    /// same keys, silently collapsing the separate-unlock option back into one
    /// key that does both jobs.
    ///
    /// Checked whatever the option currently says. A combo recorded while it is
    /// off is still sitting on disk waiting to collide the moment it is switched
    /// on, which is how the first version of this could be walked around: record
    /// the unlock combo, turn the option off, record the same combo for lock.
    ///
    /// The one thing that is *not* treated as taken is an unlock combo the user
    /// has never recorded. Refusing to let someone lock with Cmd+Shift+U because
    /// it matches a default they have never seen is a rejection with no visible
    /// cause; that case is surfaced by `unlockCollidesWithLock` instead, where it
    /// can be explained.
    static func duplicateConflict(role: HotkeyRole, keyCode: Int, modifiers: Int, display: String) -> String? {
        let taken: (keyCode: Int, modifiers: Int)
        switch role {
        case .lock:
            guard let storedKeyCode = storedUnlockKeyCode,
                  let storedModifiers = storedUnlockModifiers else { return nil }
            taken = (storedKeyCode, storedModifiers)
        case .unlock:
            taken = (HotkeyConfig.keyCode, HotkeyConfig.modifiers)
        }

        guard keyCode == taken.keyCode, modifiers == taken.modifiers else { return nil }
        return "\(display) is already the \(role.other.label) shortcut"
    }

    /// True when the option is on but both shortcuts resolve to the same combo,
    /// so the lock key still unlocks and the feature is doing nothing.
    ///
    /// Reachable without any duplicate ever being recorded: the unlock default is
    /// a fixed Cmd+Shift+U and a user's lock hotkey can already be exactly that,
    /// in which case turning the option on changes nothing at all. Settings shows
    /// this as a standing warning rather than a transient one, because the state
    /// outlives the moment it was created.
    static var unlockCollidesWithLock: Bool {
        separateUnlockHotkey && unlockKeyCode == keyCode && unlockModifiers == modifiers
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
