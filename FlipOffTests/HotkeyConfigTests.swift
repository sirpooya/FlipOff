import XCTest
import AppKit
@testable import FlipOff

final class HotkeyConfigTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: HotkeyConfig.requireAuthenticationToUnlockKey)
        clearUnlockHotkeyDefaults()
    }

    override func tearDown() {
        clearUnlockHotkeyDefaults()
        UserDefaults.standard.removeObject(forKey: HotkeyConfig.requireAuthenticationToUnlockKey)
        super.tearDown()
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

    // MARK: - Unlock authentication preference

    func testRequiresAuthenticationToUnlockDefaultsToFalse() {
        XCTAssertFalse(HotkeyConfig.requiresAuthenticationToUnlock)
    }

    func testRequiresAuthenticationToUnlockPersists() {
        HotkeyConfig.saveRequireAuthenticationToUnlock(true)
        XCTAssertTrue(HotkeyConfig.requiresAuthenticationToUnlock)

        HotkeyConfig.saveRequireAuthenticationToUnlock(false)
        XCTAssertFalse(HotkeyConfig.requiresAuthenticationToUnlock)
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
