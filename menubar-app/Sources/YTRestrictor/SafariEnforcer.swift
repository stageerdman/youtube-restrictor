import AppKit

/// Safari's counterpart to FirefoxEnforcer.swift — same approach, same
/// caveats, different bundle identifier. Kept as its own tiny type
/// (rather than parameterizing FirefoxEnforcer) so each stays the "one
/// place that knows how to find and quit <this specific browser>", per
/// CLAUDE.md's owner-is-the-ultimate-authority principle: this only
/// ever quits the browser process itself, never touches the extension
/// or anything else on the machine.
enum SafariEnforcer {
    private static let bundleIdentifier = "com.apple.Safari"
    private static let forceQuitDelay: TimeInterval = 3

    static func isSafariRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Graceful quit first, then force-quit shortly after if Safari's
    /// still around — same rationale as FirefoxEnforcer.quitFirefox().
    static func quitSafari() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !apps.isEmpty else { return }

        for app in apps {
            print("[enforcement] heartbeat stale — quitting Safari (pid \(app.processIdentifier))")
            app.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + forceQuitDelay) {
            for app in apps where !app.isTerminated {
                print("[enforcement] Safari still running — forcing quit (pid \(app.processIdentifier))")
                app.forceTerminate()
            }
        }
    }
}
