import Foundation
import Network

/// Safari's counterpart to MessagingServer's role for Firefox/Chrome —
/// a loopback-only TCP listener instead of a Unix domain socket, since
/// SafariWebExtensionHandler runs sandboxed inside the .appex and can't
/// open an arbitrary filesystem path the way native-host/ can. See
/// SafariRelayPort.swift and docs/PROTOCOL.md's "Safari's transport"
/// for why this replaced the original App Group file relay.
///
/// One request per connection, no framing needed: the client sends its
/// JSON request and half-closes (FIN); this reads until that half-close,
/// responds with one JSON payload, then closes. Simpler than
/// MessagingServer's length-prefixed framing, which exists there only
/// to support multiple messages over one long-lived connection — this
/// connection never carries more than one message each way.
final class SafariLocalRelayServer {
    private let heartbeatMonitor: HeartbeatMonitor
    private let blocklistProvider: () -> Blocklist
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ytrestrictor.safari-local-relay")

    init(heartbeatMonitor: HeartbeatMonitor, blocklistProvider: @escaping () -> Blocklist) {
        self.heartbeatMonitor = heartbeatMonitor
        self.blocklistProvider = blocklistProvider
    }

    func start() {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1", port: NWEndpoint.Port(rawValue: SafariRelayPort.value)!
        )
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("[safari-relay] listener failed:", error)
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            print("[safari-relay] listening on 127.0.0.1:\(SafariRelayPort.value)")
        } catch {
            print("[safari-relay] failed to start listener:", error)
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(connection, accumulated: Data())
    }

    private func receiveRequest(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var accumulated = accumulated
            if let data { accumulated.append(data) }

            guard error == nil else {
                connection.cancel()
                return
            }
            guard isComplete else {
                self.receiveRequest(connection, accumulated: accumulated)
                return
            }

            if
                let json = try? JSONSerialization.jsonObject(with: accumulated) as? [String: Any],
                json["type"] as? String == "heartbeat"
            {
                DispatchQueue.main.async { self.heartbeatMonitor.recordHeartbeat() }
            }
            self.respond(on: connection)
        }
    }

    private func respond(on connection: NWConnection) {
        // blocklistProvider reads BlocklistStore.blocklist, an
        // @Published property only ever otherwise touched on the main
        // thread — hop there rather than reading it from this queue.
        let blocklist = DispatchQueue.main.sync { blocklistProvider() }
        guard let data = try? JSONSerialization.data(withJSONObject: NativeMessage.blocklistUpdate(blocklist)) else {
            connection.cancel()
            return
        }
        connection.send(content: data, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
