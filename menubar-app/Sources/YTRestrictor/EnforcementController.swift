import Foundation

/// Ties HeartbeatMonitor (state) to FirefoxEnforcer (action): every
/// checkIntervalSeconds, if Firefox is running and the heartbeat has
/// gone stale, quit it. No heartbeat tracking or Firefox-process code of
/// its own — just the periodic "check both, act" loop.
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
        guard FirefoxEnforcer.isFirefoxRunning(), heartbeatMonitor.isStale else { return }
        FirefoxEnforcer.quitFirefox()
    }
}
