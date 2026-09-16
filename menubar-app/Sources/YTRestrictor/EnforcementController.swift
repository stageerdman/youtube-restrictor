import Foundation

/// Ties HeartbeatMonitor (state) to FirefoxEnforcer/SafariEnforcer/
/// ChromeEnforcer (action): every checkIntervalSeconds, for each
/// browser that's running, if *that browser's own* heartbeat has gone
/// stale, quit it. No heartbeat tracking or browser-process code of its
/// own — just the periodic "check each, act" loop.
///
/// Checks each browser against its own source's staleness
/// (`heartbeatMonitor.isStale(source:)`), not a single shared timestamp
/// — see HeartbeatMonitor's doc comment for why that used to let one
/// browser's live heartbeat mask another's going silent.
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
        if FirefoxEnforcer.isFirefoxRunning(), heartbeatMonitor.isStale(source: "firefox") {
            FirefoxEnforcer.quitFirefox()
        }
        if SafariEnforcer.isSafariRunning(), heartbeatMonitor.isStale(source: "safari") {
            SafariEnforcer.quitSafari()
        }
        for app in ChromeEnforcer.runningChromiumBrowsers() {
            let source = app.bundleIdentifier == "com.brave.Browser" ? "brave" : "chrome"
            if heartbeatMonitor.isStale(source: source) {
                ChromeEnforcer.quit(app)
            }
        }
    }
}
