import Foundation

/// A curated, maintained list of known web browsers' bundle
/// identifiers — every browser this project knows about, whether or
/// not it ships an extension for it yet (see
/// UnsupportedBrowserEnforcer for the "does it ship one" split).
///
/// Not auto-detected. An earlier version of this tried asking macOS
/// Launch Services "which installed apps can open http/https links" —
/// `NSWorkspace.shared.urlsForApplications(toOpen:)` — as a way to spot
/// a brand-new browser without needing to know its bundle ID up front.
/// That produced a real false positive on the very first machine it
/// ran on: BetterTouchTool registers as an http/https handler (for some
/// in-app web view, presumably) despite not being a browser at all, and
/// would have been force-quit on a loop forever. `LSApplicationCategoryType`
/// isn't a usable substitute either — checked directly against installed
/// apps on this machine: Chrome and Brave both leave it blank, Safari's
/// is "public.app-category.productivity", not "...web-browser". There's
/// no macOS-provided signal precise enough to auto-detect "is this a
/// browser" without false positives, so this list is hand-maintained
/// instead. A wrong or missing bundle ID here just fails to match
/// anything — unlike the dynamic approach, it can't misfire against an
/// unrelated app.
///
/// Adding a newly-downloaded browser here (a one-line bundle-ID string)
/// is the "detection mechanism" INIT.md/CLAUDE.md's owner asked for
/// that doesn't require writing a whole extension for it — the browser
/// gets closed on sight until an extension exists, instead of running
/// unrestricted.
enum KnownBrowsers {
    /// Bundle identifiers confirmed by reading the installed app's own
    /// Info.plist on this machine, or well-established/stable public
    /// identifiers for major browsers. Chromium-based forks (Brave,
    /// Edge, Opera, Vivaldi, Arc) and Firefox-based forks each get
    /// their own real bundle ID, not their upstream engine's.
    static let all: Set<String> = [
        // Confirmed on this machine (see KnownBrowsers.swift's doc comment).
        // Note: this set is "known browsers", supported or not — whether
        // one actually ships an extension (and so is exempt from being
        // quit on sight) is UnsupportedBrowserEnforcer.supportedBundleIdentifiers'
        // job, not this file's. Brave is both: known here, and supported
        // there (it reuses extension-chrome/ — see that file's doc comment).
        "com.google.Chrome",
        "com.brave.Browser",
        "com.google.chrome.for.testing",
        "app.zen-browser.zen",
        "com.apple.Safari",

        // Not installed here — best-effort from public/vendor identifiers,
        // safe to include even if imprecise (see doc comment above):
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Canary",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser", // Arc
        "company.thebrowser.dia",     // Dia (Arc's successor)
        "org.chromium.Chromium",
        "org.torproject.torbrowser",
        "com.duckduckgo.macos.browser",
        "com.apple.SafariTechnologyPreview",
    ]
}
