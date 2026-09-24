import Foundation

/// All notification names in one place.
extension Notification.Name {
    static let flipOffLock = Notification.Name("flipOffLock")
    static let flipOffUnlock = Notification.Name("flipOffUnlock")
    static let flipOffUnlockPassword = Notification.Name("flipOffUnlockPassword")
    static let flipOffInputBlockerFailed = Notification.Name("flipOffInputBlockerFailed")
    /// Posted on the first key/click swallowed by the shield — wakes the lock screen.
    static let flipOffInputAttempt = Notification.Name("flipOffInputAttempt")
    /// Posted on Esc while locked — hides an already-revealed gag immediately.
    static let flipOffDismissReveal = Notification.Name("flipOffDismissReveal")
    static let flipOffSessionLost = Notification.Name("flipOffSessionLost")
    /// Posted when the primary shield window (re)gains key status. The embedded
    /// Touch ID view refuses to arm the sensor while its window isn't key ("is not
    /// visible to user because … is not key"), so `LockController` re-issues its
    /// context here to rebuild the view against a window that now qualifies.
    static let flipOffOverlayDidBecomeKey = Notification.Name("flipOffOverlayDidBecomeKey")
    /// Posted after a display change tore down and rebuilt the shield windows
    /// mid-lock. The rebuilt Touch ID view needs a fresh context, not the old one.
    static let flipOffOverlayRebuilt = Notification.Name("flipOffOverlayRebuilt")
    static let toggleFlipOff = Notification.Name("toggleFlipOff")
    static let flipOffHotkeyPreferenceChanged = Notification.Name("flipOffHotkeyPreferenceChanged")
    /// Posted when the hot-corner toggle, corner, or dwell time changes. Observed
    /// by `LockController`, which owns the monitor — Settings only writes the
    /// defaults, it has no handle on the thing that polls.
    static let flipOffHotCornerPreferenceChanged = Notification.Name("flipOffHotCornerPreferenceChanged")
    /// Posted when an AI agent pings (bridged from the distributed notification, or fired by the in-app test button).
    static let flipOffPing = Notification.Name("flipOffPing")
    /// Reopens the onboarding window, optionally on a given step (`object` is the
    /// step index as an `Int`). Observed by `AppDelegate`, which owns that window —
    /// the menu-bar item that posts this only exists while the menu is open, so a
    /// view could never observe it in time.
    static let flipOffShowOnboarding = Notification.Name("flipOffShowOnboarding")
}

/// Who asked for a lock/unlock toggle.
///
/// `toggleFlipOff` used to be an anonymous "flip the state" signal, which was
/// fine while one shortcut did both jobs. Once the user can separate them, the
/// lock shortcut and the unlock shortcut are two different requests, and only
/// the event tap that saw the key knows which one fired. Posted under
/// `userInfoKey`; a toggle with no source (the `flipoff://toggle` URL) is a
/// deliberate out-of-band request and stays unrestricted.
enum HotkeyToggleSource: String {
    case lockHotkey
    case unlockHotkey

    static let userInfoKey = "source"

    /// The `userInfo` dictionary to post this source under.
    var userInfo: [String: String] { [Self.userInfoKey: rawValue] }

    /// Reads a source back out of a posted notification, if it carried one.
    static func from(_ notification: Notification) -> HotkeyToggleSource? {
        (notification.userInfo?[userInfoKey] as? String).flatMap(HotkeyToggleSource.init(rawValue:))
    }
}
