import Foundation
import Network

/// Unix-domain-socket server at AppPaths.socketPath. This app is the
/// long-running side; native-host/host.js (spawned per Firefox session)
/// connects in as a client. Pure transport — no blocklist logic here
/// beyond what to send, which is handed in from the outside.
final class MessagingServer {
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let queue = DispatchQueue(label: "ytrestrictor.messaging-server")

    /// Called on the main queue whenever a native-host process connects.
    var onClientConnected: (() -> Void)?

    func start() {
        AppPaths.ensureSupportDirectoryExists()
        let socketPath = AppPaths.socketPath
        // A stale socket file from a previous run (crash, force-quit)
        // blocks re-binding to the same path.
        try? FileManager.default.removeItem(atPath: socketPath)

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: socketPath)

        do {
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("[messaging] listener failed:", error)
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            print("[messaging] listening on", socketPath)
        } catch {
            print("[messaging] failed to start listener:", error)
        }
    }

    /// Sends `payload` (a JSON-serializable dictionary) to every
    /// currently connected native-host process.
    func broadcast(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let framed = frame(data)
        for connection in connections.values {
            connection.send(
                content: framed,
                completion: .contentProcessed { error in
                    if let error {
                        print("[messaging] send failed:", error)
                    }
                }
            )
        }
    }

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[messaging] native host connected")
                DispatchQueue.main.async { self?.onClientConnected?() }
            case .failed, .cancelled:
                self?.connections.removeValue(forKey: key)
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveLoop(connection)
    }

    private func receiveLoop(_ connection: NWConnection) {
        // 4-byte little-endian length prefix, per
        // native-host/src/stdio-framing.js.
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] headerData, _, _, error in
            guard let self, let headerData, headerData.count == 4, error == nil else { return }
            let length = Int(headerData.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian)

            connection.receive(minimumIncompleteLength: length, maximumLength: length) { bodyData, _, _, error in
                if let bodyData, let json = try? JSONSerialization.jsonObject(with: bodyData) {
                    print("[messaging] received:", json)
                }
                if error == nil {
                    self.receiveLoop(connection)
                }
            }
        }
    }

    private func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).littleEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(payload)
        return framed
    }
}
