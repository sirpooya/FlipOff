import XCTest
import AppKit
@testable import FlipOff

final class HotCornerTests: XCTestCase {
    /// A stand-in display, bottom-left origin, offset from zero so a bug that
    /// assumes screens start at the origin shows up.
    private let frame = NSRect(x: 100, y: 200, width: 1000, height: 800)
    private let size: CGFloat = 5

    // MARK: - Geometry

    func testZonesSitAtTheCornersOfTheFrame() {
        // Cocoa space: maxY is the *top* edge. Swapping these is the classic
        // hot-corner bug, where the picked corner and the live one are opposites.
        XCTAssertEqual(HotCorner.topLeft.zone(in: frame, size: size), NSRect(x: 100, y: 995, width: 5, height: 5))
        XCTAssertEqual(HotCorner.topRight.zone(in: frame, size: size), NSRect(x: 1095, y: 995, width: 5, height: 5))
        XCTAssertEqual(HotCorner.bottomLeft.zone(in: frame, size: size), NSRect(x: 100, y: 200, width: 5, height: 5))
        XCTAssertEqual(HotCorner.bottomRight.zone(in: frame, size: size), NSRect(x: 1095, y: 200, width: 5, height: 5))
    }

    func testAnyHasNoSingleZone() {
        XCTAssertNil(HotCorner.any.zone(in: frame, size: size))
    }

    func testEachCornerContainsItsOwnPointAndNoOtherCornersPoint() {
        let points: [HotCorner: NSPoint] = [
            .topLeft: NSPoint(x: 101, y: 998),
            .topRight: NSPoint(x: 1098, y: 998),
            .bottomLeft: NSPoint(x: 101, y: 201),
            .bottomRight: NSPoint(x: 1098, y: 201),
        ]

        for (corner, point) in points {
            XCTAssertTrue(corner.contains(point, in: frame, size: size), "\(corner) should contain its own point")
            for other in HotCorner.physical where other != corner {
                XCTAssertFalse(other.contains(point, in: frame, size: size), "\(other) should not contain \(corner)'s point")
            }
        }
    }

    func testAnyMatchesAllFourCorners() {
        for corner in HotCorner.physical {
            let zone = corner.zone(in: frame, size: size)!
            XCTAssertTrue(HotCorner.any.contains(NSPoint(x: zone.midX, y: zone.midY), in: frame, size: size))
        }
    }

    func testTheMiddleOfTheScreenIsNotACorner() {
        let middle = NSPoint(x: frame.midX, y: frame.midY)
        for corner in HotCorner.allCases {
            XCTAssertFalse(corner.contains(middle, in: frame, size: size))
        }
    }

    func testTheInnerEdgesOfTheZoneAreExclusive() {
        // 5pt zone anchored at (100, 200). x=105 and y=205 are the edges facing
        // the rest of the desktop; the pointer there is on its way somewhere, not
        // in the corner.
        XCTAssertFalse(HotCorner.bottomLeft.contains(NSPoint(x: 105, y: 201), in: frame, size: size))
        XCTAssertFalse(HotCorner.bottomLeft.contains(NSPoint(x: 101, y: 205), in: frame, size: size))
        XCTAssertTrue(HotCorner.bottomLeft.contains(NSPoint(x: 104, y: 204), in: frame, size: size))
    }

    /// The regression that motivated hand-writing the containment test. A pointer
    /// slammed into a corner reports the screen's own boundary coordinate, and
    /// both `NSMouseInRect(_:_:false)` and `NSPointInRect` exclude two of those
    /// four boundaries — so two of the four corners would never have fired.
    func testTheScreenEdgesThemselvesCount() {
        XCTAssertTrue(HotCorner.bottomLeft.contains(NSPoint(x: 100, y: 200), in: frame, size: size))
        XCTAssertTrue(HotCorner.bottomRight.contains(NSPoint(x: 1100, y: 200), in: frame, size: size))
        XCTAssertTrue(HotCorner.topLeft.contains(NSPoint(x: 100, y: 1000), in: frame, size: size))
        XCTAssertTrue(HotCorner.topRight.contains(NSPoint(x: 1100, y: 1000), in: frame, size: size))

        // …and `.any` has to agree, or the setting would behave differently from
        // picking that same corner by hand.
        XCTAssertTrue(HotCorner.any.contains(NSPoint(x: 1100, y: 200), in: frame, size: size))
    }

    func testPointOutsideTheFrameEntirelyIsNotACorner() {
        // The monitor picks the screen first, but the geometry must not claim a
        // point on a neighbouring display just because it is near this frame.
        XCTAssertFalse(HotCorner.bottomLeft.contains(NSPoint(x: 98, y: 201), in: frame, size: size))
        XCTAssertFalse(HotCorner.topRight.contains(NSPoint(x: 1098, y: 1002), in: frame, size: size))
    }

    // MARK: - Config

    func testDefaultsAreOffAndOnTheBottomRight() {
        XCTAssertFalse(HotCornerConfig.defaultEnabled)
        XCTAssertEqual(HotCornerConfig.defaultCorner, HotCorner.bottomRight.rawValue)
    }

    func testUnknownStoredCornerFallsBackRatherThanCrashing() {
        XCTAssertNil(HotCorner(rawValue: "middle"))
        XCTAssertEqual(HotCorner(rawValue: HotCornerConfig.defaultCorner), .bottomRight)
    }

    func testDelayAlwaysResolvesToSomethingOnTheMenu() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: HotCornerConfig.delayKey)
        defer {
            if let original { defaults.set(original, forKey: HotCornerConfig.delayKey) }
            else { defaults.removeObject(forKey: HotCornerConfig.delayKey) }
        }

        // A `Picker` whose selection matches no tag draws blank, so every value
        // that can reach it has to land on an actual option.
        for stored in [0.01, 0.5, 2.0, 4.0, 7.5, 20.0, 9999.0] {
            defaults.set(stored, forKey: HotCornerConfig.delayKey)
            XCTAssertTrue(
                HotCornerConfig.delayOptions.contains(HotCornerConfig.delay),
                "stored \(stored) resolved to \(HotCornerConfig.delay), which is not on the menu"
            )
        }

        // A near-zero dwell would make the corner a trap rather than a gesture…
        defaults.set(0.01, forKey: HotCornerConfig.delayKey)
        XCTAssertEqual(HotCornerConfig.delay, HotCornerConfig.delayOptions.first!)

        // …and an absurd one would make it dead.
        defaults.set(9999.0, forKey: HotCornerConfig.delayKey)
        XCTAssertEqual(HotCornerConfig.delay, HotCornerConfig.delayOptions.last!)

        // The presets changed once (0.5/1/2/3/5 → 1/5/10/30). Anyone sitting on
        // the old 2s snaps to the nearest survivor rather than to blank.
        defaults.set(2.0, forKey: HotCornerConfig.delayKey)
        XCTAssertEqual(HotCornerConfig.delay, 1)

        defaults.set(10.0, forKey: HotCornerConfig.delayKey)
        XCTAssertEqual(HotCornerConfig.delay, 10)

        defaults.removeObject(forKey: HotCornerConfig.delayKey)
        XCTAssertEqual(HotCornerConfig.delay, HotCornerConfig.defaultDelay)
    }

    func testDelayLabelsReadAsTheyDoInThePicker() {
        XCTAssertEqual(HotCornerConfig.delayOptions.map(HotCornerConfig.label(forDelay:)), ["1s", "5s", "10s", "30s"])
    }

    func testTheDefaultDelayIsOneOfTheOfferedOptions() {
        XCTAssertTrue(HotCornerConfig.delayOptions.contains(HotCornerConfig.defaultDelay))
    }
}
