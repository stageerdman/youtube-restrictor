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
    /// Well under HeartbeatMonitor.staleAfter (5 min) and Safari's own
    /// ~60s heartbeat interval — just needs to notice a new timestamp
    /// reasonably promptly, not react instantly.
    private static let pollIntervalSeconds: TimeInterval = 15

    private let heartbeatMonitor: HeartbeatMonitor
    private var timer: Timer?
    private var lastSeenTimestamp: Int?

    init(heartbeatMonitor: HeartbeatMonitor) {
        self.heartbeatMonitor = heartbeatMonitor
    }

    func start() {
        poll()
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
