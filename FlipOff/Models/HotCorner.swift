import AppKit

/// A screen corner that can arm the lock, plus `.any` for "whichever one the
/// pointer reaches first".
///
/// Corner rects are computed against `NSScreen.frame`, which is Cocoa's
/// bottom-left origin space — the same space `NSEvent.mouseLocation` reports in,
/// so no flip is needed anywhere in this file. Getting that backwards is the
/// classic hot-corner bug: top and bottom swap, and the feature fires on the
/// opposite edge from the one the user picked.
enum HotCorner: String, CaseIterable, Identifiable {
    case any
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "Any corner"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }

    /// The four real corners, in picker order. `.any` is a selection, not a place.
    static let physical: [HotCorner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    /// The square hot zone for this corner inside `frame`. Nil for `.any`, which
    /// has no single rect — use `contains(_:in:)` instead of reaching for this.
    func zone(in frame: NSRect, size: CGFloat) -> NSRect? {
        switch self {
        case .any:
            return nil
        case .topLeft:
            return NSRect(x: frame.minX, y: frame.maxY - size, width: size, height: size)
        case .topRight:
            return NSRect(x: frame.maxX - size, y: frame.maxY - size, width: size, height: size)
        case .bottomLeft:
            return NSRect(x: frame.minX, y: frame.minY, width: size, height: size)
        case .bottomRight:
            return NSRect(x: frame.maxX - size, y: frame.minY, width: size, height: size)
        }
    }

    /// True when `point` (global, bottom-left origin) sits in this corner's zone
    /// on `frame`. `.any` matches all four.
    ///
    /// **Not `NSMouseInRect`, and not `NSPointInRect`.** Both are half-open on two
    /// of the four sides, and which two is fixed — `NSMouseInRect(_:_:false)`
    /// excludes maxX and minY, `NSPointInRect` excludes maxX and maxY. Either way
    /// two of the screen's own outer edges fall outside the zone, and those are
    /// precisely the edges the pointer pins itself against: slam the cursor into
    /// the bottom-left and it reports y == frame.minY, which `NSMouseInRect`
    /// calls outside. The corner would simply never fire.
    ///
    /// So the test is written out: **inclusive on the two screen edges, exclusive
    /// on the two inner edges.** The inner exclusion is what keeps the zone from
    /// leaking a point into a neighbouring zone on a tiny frame.
    func contains(_ point: NSPoint, in frame: NSRect, size: CGFloat) -> Bool {
        if self == .any {
            return HotCorner.physical.contains { $0.contains(point, in: frame, size: size) }
        }
        guard let zone = zone(in: frame, size: size) else { return false }

        let inX = isLeading
            ? (point.x >= zone.minX && point.x < zone.maxX)
            : (point.x > zone.minX && point.x <= zone.maxX)
        let inY = isBottom
            ? (point.y >= zone.minY && point.y < zone.maxY)
            : (point.y > zone.minY && point.y <= zone.maxY)

        return inX && inY
    }

    /// Which screen edges this corner is anchored to, deciding which sides of its
    /// zone are inclusive. Meaningless for `.any`, which never reaches the test.
    private var isLeading: Bool { self == .topLeft || self == .bottomLeft }
    private var isBottom: Bool { self == .bottomLeft || self == .bottomRight }

    /// The screen `point` is on, or nil if none contains it (which happens
    /// transiently mid-hot-plug).
    ///
    /// Fully inclusive on every edge, for the same reason as `contains`: a
    /// half-open test drops the pointer off the bottom or right edge of the
    /// display and no screen matches at all. Where two displays abut, both claim
    /// the shared edge and the first one wins — deterministic, and either answer
    /// is the right one, since it is still a corner of a real screen.
    static func screen(containing point: NSPoint, in screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        screens.first { screen in
            let f = screen.frame
            return point.x >= f.minX && point.x <= f.maxX && point.y >= f.minY && point.y <= f.maxY
        }
    }
}

/// UserDefaults-backed settings for the hot-corner trigger.
///
/// Static accessors rather than `@AppStorage` because the reader is
/// `HotCornerMonitor`, a plain controller with no SwiftUI environment — the same
/// split `HotkeyConfig` uses.
enum HotCornerConfig {
    static let enabledKey = "hotCornerEnabled"
    static let cornerKey = "hotCornerSelection"
    static let delayKey = "hotCornerDelay"

    static let defaultEnabled = false

    /// Bottom-right: the corner furthest from the menu bar and from anything the
    /// pointer crosses on its way somewhere else.
    ///
    /// Worth knowing that macOS ships Quick Note on this corner. Both will fire if
    /// it is still assigned there — the note under the picker in Settings says so,
    /// since there is no API to read the system's assignments and detect it.
    static let defaultCorner = HotCorner.bottomRight.rawValue

    /// Seconds the pointer must rest before the lock fires. Long enough that
    /// merely passing through a corner on the way to the Dock is not a lock.
    static let defaultDelay: Double = 5

    /// Offered dwell times. A dropdown of presets, not a free-form field: the
    /// useful range is narrow and a mistyped 0.05 would make the corner a trap.
    static let delayOptions: [Double] = [1, 5, 10, 30]

    /// Side of the square hot zone, in points. Deliberately tiny — macOS's own
    /// hot corners want the pointer genuinely pinned into the corner, and a
    /// generous zone turns "reaching for the Dock" into "locked the Mac".
    static let zoneSize: CGFloat = 5

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? defaultEnabled
    }

    static var corner: HotCorner {
        HotCorner(rawValue: UserDefaults.standard.string(forKey: cornerKey) ?? defaultCorner) ?? .bottomRight
    }

    /// Snapped to the nearest offered preset — not merely clamped to the range.
    ///
    /// Clamping alone leaves an in-range value that matches no menu item, and a
    /// `Picker` whose selection matches no tag renders **blank**. That is not
    /// hypothetical: the presets changed once already, and anyone who had picked
    /// the old 2s would have opened Settings to an empty dropdown. Snapping also
    /// covers a value written by hand, which could otherwise arm a corner that
    /// fires instantly or effectively never.
    static var delay: Double {
        let stored = UserDefaults.standard.object(forKey: delayKey) as? Double ?? defaultDelay
        return delayOptions.min { abs($0 - stored) < abs($1 - stored) } ?? defaultDelay
    }

    static func label(forDelay seconds: Double) -> String {
        "\(Int(seconds))s"
    }
}
