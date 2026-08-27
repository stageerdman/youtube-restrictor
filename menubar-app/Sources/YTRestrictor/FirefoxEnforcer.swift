import AppKit

/// The one place that knows how to find and quit Firefox. No heartbeat
/// tracking, no blocklist knowledge — per CLAUDE.md's owner-is-the-
/// ultimate-authority principle, this only ever quits the browser
/// process itself; it never touches the extension, the enterprise
/// policy file, or anything else on the machine.
enum FirefoxEnforcer {
    private static let bundleIdentifier = "org.mozilla.firefox"
    private static let forceQuitDelay: TimeInterval = 3

    static func isFirefoxRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Tries a graceful quit first, then force-quits shortly after if
    /// Firefox is still running — a plain terminate() can be blocked by
    /// a "save changes?"-style prompt, which would let a stale-heartbeat
    /// quit be dismissed away rather than actually enforced.
    static func quitFirefox() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !apps.isEmpty else { return }

        for app in apps {
            print("[enforcement] heartbeat stale — quitting Firefox (pid \(app.processIdentifier))")
            app.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + forceQuitDelay) {
            for app in apps where !app.isTerminated {
                print("[enforcement] Firefox still running — forcing quit (pid \(app.processIdentifier))")
                app.forceTerminate()
            }
        }
    }
}
