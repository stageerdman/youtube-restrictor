import AppKit

/// Chrome and Brave's counterpart to FirefoxEnforcer.swift/
/// SafariEnforcer.swift — same graceful-then-force quit approach, but
/// covers both bundle identifiers in one place instead of two separate
/// enforcers: Chrome and Brave share the same extension-chrome/
/// extension and the same native-messaging heartbeat mechanism (see
/// docs/HOW-IT-WORKS.md's "Brave reuses Chrome's extension"), so a
/// stale heartbeat means the same thing for either one. Per CLAUDE.md's
/// owner-is-the-ultimate-authority principle, this only ever quits the
/// browser process itself, never touches the extension or anything
/// else on the machine.
enum ChromeEnforcer {
    private static let bundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.brave.Browser",
    ]
    private static let forceQuitDelay: TimeInterval = 3

    static func runningChromiumBrowsers() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return bundleIdentifiers.contains(bundleID)
        }
    }

    /// Graceful quit first, then force-quit shortly after if it's still
    /// around — same rationale as FirefoxEnforcer.quitFirefox().
    static func quit(_ app: NSRunningApplication) {
        print("[enforcement] heartbeat stale — quitting \(app.bundleIdentifier ?? "?") (pid \(app.processIdentifier))")
        app.terminate()

        DispatchQueue.main.asyncAfter(deadline: .now() + forceQuitDelay) {
            if !app.isTerminated {
                print("[enforcement] \(app.bundleIdentifier ?? "?") still running — forcing quit (pid \(app.processIdentifier))")
                app.forceTerminate()
            }
        }
    }
}
