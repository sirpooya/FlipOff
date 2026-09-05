import AppKit
import os.log

private let logger = Logger(subsystem: "in.pooya.flipoff", category: "HotCornerMonitor")

/// Watches the pointer for a dwell in one of the screen corners and fires
/// `onTrigger` when it has rested there long enough.
///
/// **Polling `NSEvent.mouseLocation`, deliberately, rather than a global mouse
/// monitor.** A global `NSEvent` monitor for `.mouseMoved` is a TCC-gated input
/// observation, and FlipOff's whole permissions story is that it asks for
/// Accessibility once and nothing else (see CLAUDE.md > Backdrop). Reading the
/// cursor position is not an input observation and needs no grant at all, so the
/// feature works the moment it is switched on — including in the window between
/// launch and the Accessibility grant being repaired. The cost is a 10 Hz timer,
/// which only runs while the setting is on *and* nothing is locked.
///
/// It also cannot be a `CGEventTap`: `InputBlocker` already owns a tap and the
/// two would have to be sequenced, for a job that needs no events at all.
@MainActor
final class HotCornerMonitor {
    /// Called on the main actor when the dwell completes. The controller decides
    /// whether that becomes a lock — the monitor has no opinion about state.
    var onTrigger: (() -> Void)?

    private var timer: Timer?
    private var dwellStart: Date?

    /// False from a trigger until the pointer next leaves every hot corner.
    ///
    /// This is what stops a lock from immediately re-arming itself. Unlocking
    /// does not move the mouse, so the pointer is usually still sitting in the
    /// exact corner that fired; without this the user would unlock, wait out the
    /// dwell, and be locked again without touching anything.
    private var armed = false

    /// Poll rate. 10 Hz is far finer than the shortest offered dwell (0.5s) and
    /// costs nothing measurable, and the dwell is timed off `Date`, not off a
    /// tick count, so a coalesced or delayed timer can't shorten it.
    private static let pollInterval: TimeInterval = 0.1

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }

        // Arm only if the pointer is somewhere else right now. Starting armed
        // with the cursor already parked in the corner — which is exactly the
        // situation right after an unlock — would begin a dwell the user never
        // initiated.
        armed = (currentCorner() == nil)
        dwellStart = nil

        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` so the dwell keeps counting while a menu is tracking or a
        // window is being dragged; on the default mode the timer stalls there and
        // the corner appears to stop working at random.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.debug("Hot corner monitoring started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        dwellStart = nil
        logger.debug("Hot corner monitoring stopped")
    }

    // MARK: - Private

    private func tick() {
        guard let corner = currentCorner() else {
            // Left the corner: any dwell in progress is abandoned, and a trigger
            // that disarmed the monitor is now allowed to happen again.
            dwellStart = nil
            armed = true
            return
        }

        guard armed else { return }

        guard let started = dwellStart else {
            dwellStart = Date()
            return
        }

        guard Date().timeIntervalSince(started) >= HotCornerConfig.delay else { return }

        // Disarm *before* the callback: the callback locks, which stops this
        // monitor, and if it ever doesn't (a lock refused for want of
        // Accessibility) the corner must not fire again on the next tick.
        armed = false
        dwellStart = nil
        logger.info("Hot corner dwell complete: \(corner.rawValue, privacy: .public)")
        onTrigger?()
    }

    /// The configured corner, if the pointer is currently inside it on whichever
    /// display it is on. Nil when it isn't, or when no display contains it —
    /// which happens transiently during a hot-plug.
    private func currentCorner() -> HotCorner? {
        let selection = HotCornerConfig.corner
        let point = NSEvent.mouseLocation

        // Every screen, not just the one under the pointer: the corner has to
        // work on whichever display the user is on, and on a multi-display setup
        // two screens can abut such that a "corner" is interior to the desktop.
        // That is fine — it is still that screen's corner, and it is where the
        // user's muscle memory says the corner is.
        guard let screen = HotCorner.screen(containing: point) else { return nil }

        if selection == .any {
            return HotCorner.physical.first { $0.contains(point, in: screen.frame, size: HotCornerConfig.zoneSize) }
        }
        return selection.contains(point, in: screen.frame, size: HotCornerConfig.zoneSize) ? selection : nil
    }

    deinit {
        timer?.invalidate()
    }
}
