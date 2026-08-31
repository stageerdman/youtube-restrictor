import Foundation

/// Where the (unsandboxed) YTRestrictor app and the (sandboxed)
/// YTRestrictorSafariExtension App Extension rendezvous — an App Group
/// shared container, since the extension can't reach AppPaths.swift's
/// Unix socket or Application Support directory. Compiled into both
/// targets (see menubar-app/project.yml). Mirrors AppPaths.swift's role
/// for native-host/, but for Safari's file-relay transport instead —
/// see docs/PROTOCOL.md's "Safari's transport" section for why this
/// exists at all rather than reusing the socket.
enum AppGroupPaths {
    /// Must match the `com.apple.security.application-groups` entitlement
    /// on both targets in menubar-app/project.yml exactly.
    static let groupIdentifier = "group.com.stage-ria.ytrestrictor"

    /// nil only if the entitlement is missing/misconfigured on whichever
    /// target calls this — both callers treat that as "relay unavailable"
    /// rather than crashing, since a signing/provisioning problem
    /// shouldn't take down the rest of the app or the extension.
    ///
    /// `static let`, not `var`: resolving this container triggers macOS's
    /// cross-app-container consent check on the unsandboxed app side (see
    /// docs/PROTOCOL.md's "Safari's transport" — a personal-team/non-App-
    /// Store signed app isn't fully trusted for this the way a Mac App
    /// Store or properly provisioned build would be). Resolving it fresh
    /// on every access multiplies how often that check fires; resolving
    /// it once per process and reusing the result is both cheaper and
    /// less friction-prone, at the cost of not noticing if the App Group
    /// becomes available/unavailable mid-run — never happens in practice
    /// since entitlements are fixed at launch.
    static let containerDirectory: URL? =
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)

    /// Written by SafariWebExtensionHandler.beginRequest() every time a
    /// `heartbeat` arrives; polled by SafariHeartbeatWatcher.
    static var heartbeatFile: URL? {
        containerDirectory?.appendingPathComponent("safari-heartbeat.json")
    }

    /// Written by BlocklistStore whenever the blocklist changes; read by
    /// SafariWebExtensionHandler.beginRequest() to answer the next
    /// heartbeat's blocklist-update response.
    static var blocklistFile: URL? {
        containerDirectory?.appendingPathComponent("safari-blocklist.json")
    }
}
