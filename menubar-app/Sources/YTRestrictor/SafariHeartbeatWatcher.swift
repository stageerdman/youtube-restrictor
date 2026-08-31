import Foundation

/// Safari's counterpart to MessagingServer's role for Firefox/Chrome —
/// except there's no socket to listen on here. SafariWebExtensionHandler
/// (running sandboxed, inside the .appex) writes a timestamp to
/// AppGroupPaths.heartbeatFile every time browser.runtime.sendNativeMessage
/// delivers a `heartbeat`; this class (running in this app's normal,
/// unsandboxed process) polls that same file and feeds any new timestamp
/// into the one shared HeartbeatMonitor Firefox and Chrome already report
/// to. See docs/PROTOCOL.md's "Safari's transport" for why this is a
/// poll instead of a push.
final class SafariHeartbeatWatcher {
    /// Matches Safari's own ~60s heartbeat-send interval — polling faster
    /// than that can't notice anything sooner, and every poll is a file
    /// read against the App Group container, which macOS's cross-app-
    /// container consent check (see AppGroupPaths.containerDirectory's
    /// doc comment) treats as a separate access to justify. Well under
    /// HeartbeatMonitor.staleAfter (5 min) either way.
    private static let pollIntervalSeconds: TimeInterval = 60

    private let heartbeatMonitor: HeartbeatMonitor
    private var timer: Timer?
    private var lastSeenTimestamp: Int?

    init(heartbeatMonitor: HeartbeatMonitor) {
        self.heartbeatMonitor = heartbeatMonitor
    }

    func start() {
        // Deliberately no immediate poll() here — BlocklistStore.init()
        // already touches the same App Group container once, moments
        // earlier in AppCoordinator's init sequence. Polling immediately
        // too means two independent, near-simultaneous accesses to the
        // same container at every launch, which is exactly what was
        // producing a back-to-back double consent prompt. HeartbeatMonitor
        // is seeded to "now" at construction, so there's no correctness
        // cost to just waiting for the first regular tick.
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollIntervalSeconds, repeats: true
        ) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard
            let url = AppGroupPaths.heartbeatFile,
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = json["timestamp"] as? Int
        else { return }

        guard timestamp != lastSeenTimestamp else { return }
        lastSeenTimestamp = timestamp
        heartbeatMonitor.recordHeartbeat()
    }
}
