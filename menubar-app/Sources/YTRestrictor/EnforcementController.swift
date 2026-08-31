import Foundation

/// Ties HeartbeatMonitor (state) to FirefoxEnforcer/SafariEnforcer
/// (action): every checkIntervalSeconds, if a browser is running and the
/// heartbeat has gone stale, quit it. No heartbeat tracking or browser-
/// process code of its own — just the periodic "check each, act" loop.
///
/// Known limitation, see docs/HOW-IT-WORKS.md's heartbeat section:
/// heartbeatMonitor is a single shared "last heartbeat from any source"
/// timestamp, not one per browser, so a live heartbeat from one browser
/// can mask a dead one from another open at the same time. Not fixed
/// here — out of scope for adding Safari support.
final class EnforcementController {
    private static let checkIntervalSeconds: TimeInterval = 30

    private let heartbeatMonitor: HeartbeatMonitor
    private var timer: Timer?

    init(heartbeatMonitor: HeartbeatMonitor) {
        self.heartbeatMonitor = heartbeatMonitor
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.checkIntervalSeconds, repeats: true
        ) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        guard heartbeatMonitor.isStale else { return }
        if FirefoxEnforcer.isFirefoxRunning() {
            FirefoxEnforcer.quitFirefox()
        }
        if SafariEnforcer.isSafariRunning() {
            SafariEnforcer.quitSafari()
        }
    }
}
