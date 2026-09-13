import AppKit

/// Ties BrowserRegistry/UnsupportedBrowserEnforcer (detection + action)
/// to a schedule. Two triggers, deliberately redundant:
/// - An `NSWorkspace` launch notification, so a freshly downloaded
///   browser gets closed within moments of its first launch.
/// - A periodic sweep, as a backstop for anything already running
///   before this controller existed (e.g. this app just relaunched via
///   launchd) or for the rare case a launch notification is missed.
final class UnsupportedBrowserController {
    private static let sweepIntervalSeconds: TimeInterval = 30

    private var timer: Timer?
    private var launchObserver: NSObjectProtocol?

    init() {
        sweep()
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.sweepIntervalSeconds, repeats: true
        ) { [weak self] _ in
            self?.sweep()
        }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sweep()
        }
    }

    deinit {
        timer?.invalidate()
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
    }

    private func sweep() {
        for app in UnsupportedBrowserEnforcer.runningUnsupportedBrowsers() {
            UnsupportedBrowserEnforcer.quit(app)
        }
    }
}
