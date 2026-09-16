import Foundation

/// Pure state: tracks when the extension last checked in. No enforcement
/// action, no knowledge of Firefox or the messaging transport — see
/// EnforcementController and FirefoxEnforcer/SafariEnforcer/ChromeEnforcer
/// for those.
///
/// Tracked per source ("firefox", "chrome", "brave", "safari" — see
/// native-host/host.js's `--source` tag and SafariLocalRelayServer's
/// hardcoded "safari") rather than as one shared timestamp. That used to
/// be a single global `lastHeartbeatAt`, which meant a live heartbeat
/// from any one browser masked every other browser's heartbeat going
/// stale — documented as a known limitation in docs/HOW-IT-WORKS.md
/// until this fixed it. `isStale`/`lastHeartbeatAt` below are kept as a
/// "most recent heartbeat from anything" convenience purely for the
/// menu bar UI's single connection dot (ContentView.swift) — actual
/// enforcement must go through `isStale(source:)`.
final class HeartbeatMonitor: ObservableObject {
    /// Per INIT.md Phase 5: "if Firefox is open but the extension hasn't
    /// checked in for 5 minutes, it closes Firefox." Not owner-configurable
    /// (unlike the removal delay) — INIT.md doesn't call for that here.
    static let staleAfter: TimeInterval = 5 * 60

    /// A source with no heartbeat yet reads as "last heard from at
    /// launch," the same grace period the old single-timestamp version
    /// gave every browser — otherwise a browser whose native host just
    /// hasn't connected yet would look infinitely stale and get quit
    /// the moment it's noticed, before its extension had any chance to
    /// check in.
    private let launchedAt = Date()

    @Published private(set) var lastHeartbeatBySource: [String: Date] = [:]

    func recordHeartbeat(source: String) {
        lastHeartbeatBySource[source] = Date()
    }

    func isStale(source: String) -> Bool {
        Date().timeIntervalSince(lastHeartbeatBySource[source] ?? launchedAt) > Self.staleAfter
    }

    /// Most recent heartbeat across every source — UI-only, see doc
    /// comment above.
    var lastHeartbeatAt: Date {
        lastHeartbeatBySource.values.max() ?? launchedAt
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) > Self.staleAfter
    }
}
