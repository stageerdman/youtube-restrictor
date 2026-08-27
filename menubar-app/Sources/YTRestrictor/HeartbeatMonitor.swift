import Foundation

/// Pure state: tracks when the extension last checked in. No enforcement
/// action, no knowledge of Firefox or the messaging transport — see
/// EnforcementController and FirefoxEnforcer for those.
final class HeartbeatMonitor: ObservableObject {
    /// Per INIT.md Phase 5: "if Firefox is open but the extension hasn't
    /// checked in for 5 minutes, it closes Firefox." Not owner-configurable
    /// (unlike the removal delay) — INIT.md doesn't call for that here.
    static let staleAfter: TimeInterval = 5 * 60

    /// Seeded to "now" rather than nil so a just-launched app gets the
    /// same grace period as a real gap — otherwise it would look stale
    /// (and could trigger an immediate, surprising quit) before the
    /// extension has had a chance to send its first heartbeat.
    @Published private(set) var lastHeartbeatAt = Date()

    func recordHeartbeat() {
        lastHeartbeatAt = Date()
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) > Self.staleAfter
    }
}
