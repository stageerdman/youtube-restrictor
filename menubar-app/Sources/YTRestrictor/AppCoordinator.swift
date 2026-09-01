import Foundation

/// Owns every long-lived piece of app state and wires them together in
/// its own init — the one place guaranteed to run exactly once against
/// real, persistent instances. Deliberately NOT done in the SwiftUI App
/// struct's init(): reading a @StateObject there isn't guaranteed to be
/// the same instance the view graph later binds to, which once already
/// caused BlocklistStore's messaging wiring to silently attach to a
/// throwaway instance the UI never actually mutated.
final class AppCoordinator: ObservableObject {
    let blocklistStore: BlocklistStore
    let heartbeatMonitor = HeartbeatMonitor()
    private let messagingServer = MessagingServer()
    private let enforcementController: EnforcementController
    // Safari's counterpart to messagingServer — see
    // SafariLocalRelayServer's doc comment and docs/PROTOCOL.md's
    // "Safari's transport". Answers both the heartbeat and the
    // blocklist fetch in one round trip, since Safari has no persistent
    // connection to push a blocklist-update on separately.
    private let safariLocalRelayServer: SafariLocalRelayServer

    init() {
        let messagingServer = self.messagingServer
        let heartbeatMonitor = self.heartbeatMonitor

        self.blocklistStore = BlocklistStore(messagingServer: messagingServer)
        self.enforcementController = EnforcementController(heartbeatMonitor: heartbeatMonitor)

        let blocklistStore = self.blocklistStore
        self.safariLocalRelayServer = SafariLocalRelayServer(
            heartbeatMonitor: heartbeatMonitor,
            blocklistProvider: { blocklistStore.blocklist }
        )
        messagingServer.onMessage = { message in
            guard let type = message["type"] as? String, type == "heartbeat" else { return }
            heartbeatMonitor.recordHeartbeat()
        }
        // Push the current blocklist as soon as a native host connects,
        // so a freshly (re)launched extension is in sync immediately
        // rather than waiting for the next edit. Wired before start() so
        // there's no window where an early connection could arrive
        // before this callback is set.
        messagingServer.onClientConnected = {
            messagingServer.broadcast(NativeMessage.blocklistUpdate(blocklistStore.blocklist))
        }
        messagingServer.start()
        safariLocalRelayServer.start()
    }
}
