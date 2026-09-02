import XCTest
import AppKit
import Carbon
@testable import FlipOff

final class HotkeyConfigTests: XCTestCase {
    /// The collision tests have to move the *lock* hotkey, which is a real user
    /// setting on the machine running the suite — these tests share
    /// `UserDefaults.standard` with the installed app. Snapshot it and put it
    /// back rather than deleting it, so a local test run can't quietly reset
    /// someone's shortcut to Cmd+Shift+L.
    private var savedLockKeyCode: Any?
    private var savedLockModifiers: Any?

    override func setUp() {
        super.setUp()
        savedLockKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode")
        savedLockModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers")
        clearUnlockHotkeyDefaults()
    }

    override func tearDown() {
        clearUnlockHotkeyDefaults()
        restore(savedLockKeyCode, forKey: "hotkeyKeyCode")
        restore(savedLockModifiers, forKey: "hotkeyModifiers")
        super.tearDown()
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func clearUnlockHotkeyDefaults() {
        for key in [
            HotkeyConfig.separateUnlockHotkeyKey,
            HotkeyConfig.unlockKeyCodeKey,
            HotkeyConfig.unlockModifiersKey,
            HotkeyConfig.unlockDisplayKey
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Separate unlock hotkey

    func testUnlockHotkeyMirrorsLockHotkeyWhenSeparateIsOff() {
        XCTAssertFalse(HotkeyConfig.separateUnlockHotkey)
        XCTAssertEqual(HotkeyConfig.unlockKeyCode, HotkeyConfig.keyCode)
        XCTAssertEqual(HotkeyConfig.unlockModifiers, HotkeyConfig.modifiers)
        XCTAssertEqual(HotkeyConfig.unlockDisplay, HotkeyConfig.display)
    }

    func testUnlockHotkeyIgnoresStoredValueUntilSeparateIsOn() {
        HotkeyConfig.saveUnlockKeyCode(45)
        XCTAssertEqual(HotkeyConfig.unlockKeyCode, HotkeyConfig.keyCode)

        HotkeyConfig.saveSeparateUnlockHotkey(true)
        XCTAssertEqual(HotkeyConfig.unlockKeyCode, 45)
    }

    func testUnlockHotkeyFallsBackToItsOwnDefaults() {
        HotkeyConfig.saveSeparateUnlockHotkey(true)
        XCTAssertEqual(HotkeyConfig.unlockKeyCode, HotkeyConfig.defaultUnlockKeyCode)
        XCTAssertEqual(HotkeyConfig.unlockModifiers, HotkeyConfig.defaultUnlockModifiers)
        XCTAssertEqual(HotkeyConfig.unlockDisplay, HotkeyConfig.defaultUnlockDisplay)
    }

    // MARK: - Lock / unlock collision

    func testRecordingUnlockOverTheLockComboIsRefused() {
        HotkeyConfig.saveSeparateUnlockHotkey(true)

        let conflict = HotkeyConfig.duplicateConflict(
            role: .unlock,
            keyCode: HotkeyConfig.keyCode,
            modifiers: HotkeyConfig.modifiers,
            display: HotkeyConfig.display
        )

        XCTAssertNotNil(conflict)
        XCTAssertTrue(conflict?.contains("lock shortcut") == true)
    }

    /// The bypass in the first version: the check only ran while the option was
    /// on, so turning it off, recording the unlock combo as the lock hotkey, and
    /// turning it back on produced two identical shortcuts.
    func testRecordingLockOverAStoredUnlockComboIsRefusedEvenWhenSeparateIsOff() {
        HotkeyConfig.saveUnlockKeyCode(45)
        HotkeyConfig.saveUnlockModifiers(cmdKey | shiftKey)
        HotkeyConfig.saveSeparateUnlockHotkey(false)

        let conflict = HotkeyConfig.duplicateConflict(
            role: .lock,
            keyCode: 45,
            modifiers: cmdKey | shiftKey,
            display: "Cmd+Shift+N"
        )

        XCTAssertNotNil(conflict)
        XCTAssertTrue(conflict?.contains("unlock shortcut") == true)
    }

    /// An unlock combo the user has never recorded is not a claim on those keys.
    /// Refusing Cmd+Shift+U for the lock hotkey because it matches an unseen
    /// default would be a rejection with no visible cause.
    func testUnrecordedUnlockDefaultDoesNotBlockTheLockCombo() {
        XCTAssertNil(HotkeyConfig.storedUnlockKeyCode)

        let conflict = HotkeyConfig.duplicateConflict(
            role: .lock,
            keyCode: HotkeyConfig.defaultUnlockKeyCode,
            modifiers: HotkeyConfig.defaultUnlockModifiers,
            display: HotkeyConfig.defaultUnlockDisplay
        )

        XCTAssertNil(conflict)
    }

    func testDistinctCombosDoNotConflict() {
        HotkeyConfig.saveSeparateUnlockHotkey(true)
        HotkeyConfig.saveUnlockKeyCode(45)
        HotkeyConfig.saveUnlockModifiers(cmdKey | shiftKey)

        XCTAssertNil(HotkeyConfig.duplicateConflict(
            role: .unlock,
            keyCode: 40,
            modifiers: cmdKey | shiftKey,
            display: "Cmd+Shift+K"
        ))
        XCTAssertFalse(HotkeyConfig.unlockCollidesWithLock)
    }

    func testCollisionIsNotReportedWhileSeparateUnlockIsOff() {
        // Both accessors resolve to the lock hotkey when the option is off, which
        // is equality by design and must not be read as a collision.
        XCTAssertEqual(HotkeyConfig.unlockKeyCode, HotkeyConfig.keyCode)
        XCTAssertFalse(HotkeyConfig.unlockCollidesWithLock)
    }

    /// Reachable with nothing recorded twice: set the lock hotkey to Cmd+Shift+U,
    /// turn the option on, and the untouched unlock default already matches it.
    func testCollisionIsReportedWhenTheUnlockDefaultMatchesTheLockCombo() {
        HotkeyConfig.saveKeyCode(HotkeyConfig.defaultUnlockKeyCode)
        HotkeyConfig.saveModifiers(HotkeyConfig.defaultUnlockModifiers)
        HotkeyConfig.saveSeparateUnlockHotkey(true)

        XCTAssertTrue(HotkeyConfig.unlockCollidesWithLock)
    }

    // MARK: - System conflict detection

    func testCmdQIsConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 12, modifiers: .command)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Quit"), "Cmd+Q should report a Quit conflict")
    }

    func testCmdTabIsConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 48, modifiers: .command)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("App Switcher"), "Cmd+Tab should report an App Switcher conflict")
    }

    func testCmdShiftLIsNotConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 37, modifiers: [.command, .shift])
        XCTAssertNil(result, "Cmd+Shift+L should not conflict with any system shortcut")
    }

    func testCtrlCmdQIsConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 12, modifiers: [.command, .control])
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Lock Screen"), "Ctrl+Cmd+Q should report a Lock Screen conflict")
    }

    // MARK: - Additional cases

    func testCmdSpaceIsConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 49, modifiers: .command)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Spotlight"))
    }

    func testCmdShiftZIsConflict() {
        let result = HotkeyConfig.systemConflict(keyCode: 6, modifiers: [.command, .shift])
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Redo"))
    }

    func testNoConflictForUnusedCombination() {
        // Cmd+Shift+K (keyCode 40) is not a system shortcut
        let result = HotkeyConfig.systemConflict(keyCode: 40, modifiers: [.command, .shift])
        XCTAssertNil(result)
    }
}
