import AppKit

/// The one place that knows which browsers this project ships an
/// extension for, and quits anything else on KnownBrowsers.all — a
/// known browser without one. Deliberately separate from
/// FirefoxEnforcer/SafariEnforcer: those two enforce an *existing*
/// extension's heartbeat going stale after a grace period; this
/// enforces the absence of any extension at all, for a browser the
/// owner hasn't (yet, or ever) gotten one built for — there's no
/// heartbeat to wait on, so no grace period, per CLAUDE.md principle 3
/// ("tightening restrictions is instant"). Per principle 2, this only
/// ever quits the browser process itself — it never touches the app
/// bundle, the download, or anything else on the machine, and is fully
/// undone by removing YTRestrictor.app + its LaunchAgent like every
/// other enforcement mechanism here.
enum UnsupportedBrowserEnforcer {
    /// Chrome, Safari, Firefox/Zen, and Brave all ship a real extension
    /// in this repo. Zen's actual bundle identifier is
    /// `app.zen-browser.zen`, not `org.mozilla.firefox` — see
    /// docs/HOW-IT-WORKS.md's "Known bug" note on FirefoxEnforcer for
    /// why that file itself still has this wrong. This list is kept
    /// correct independently of that unfixed bug, since this is new
    /// code rather than a patch to FirefoxEnforcer.swift.
    ///
    /// Brave doesn't get its own extension directory — it's Chromium
    /// under the hood and loads `extension-chrome/` unpacked exactly
    /// as Chrome does, with its own native-messaging host registration
    /// (`scripts/install-native-host-brave.sh`) pointed at the same
    /// menu bar app. See docs/HOW-IT-WORKS.md.
    static let supportedBundleIdentifiers: Set<String> = [
        "org.mozilla.firefox",
        "app.zen-browser.zen",
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
    ]

    private static let forceQuitDelay: TimeInterval = 3

    static func runningUnsupportedBrowsers() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return KnownBrowsers.all.contains(bundleID)
                && !supportedBundleIdentifiers.contains(bundleID)
        }
    }

    /// Graceful quit first, then force-quit shortly after if it's still
    /// around — same rationale as FirefoxEnforcer.quitFirefox().
    static func quit(_ app: NSRunningApplication) {
        print("[enforcement] \(app.bundleIdentifier ?? "?") looks like a browser with no YTRestrictor extension — quitting (pid \(app.processIdentifier))")
        app.terminate()

        DispatchQueue.main.asyncAfter(deadline: .now() + forceQuitDelay) {
            if !app.isTerminated {
                print("[enforcement] \(app.bundleIdentifier ?? "?") still running — forcing quit (pid \(app.processIdentifier))")
                app.forceTerminate()
            }
        }
    }
}
