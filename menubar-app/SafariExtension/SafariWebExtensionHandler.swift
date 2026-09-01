import Network
import SafariServices

/// Native side of Safari's request/response-only messaging model — see
/// docs/PROTOCOL.md's "Safari's transport". Every browser.runtime.
/// sendNativeMessage() call from the extension's JS lands here as one
/// beginRequest()/completeRequest() round trip; there's no persistent
/// connection to push a blocklist-update on separately, so every
/// `heartbeat` also answers with the current blocklist as its response,
/// rather than waiting for one to be pushed the way Firefox/Chrome do
/// over the socket.
///
/// Runs inside the sandboxed .appex process — reaches the rest of the
/// app only through a loopback TCP connection to
/// SafariLocalRelayServer (see SafariRelayPort.swift), never the Unix
/// socket native-host/ and the app target use for Firefox/Chrome (a
/// sandboxed process can't open an arbitrary filesystem path the way
/// that socket would need).
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    /// Best-effort: if the menu bar app isn't running (or is too slow
    /// to answer), Safari still gets a response instead of hanging.
    private static let relayTimeout: TimeInterval = 2

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        let type = message?["type"] as? String ?? ""

        queryRelay(requestType: type) { blocklistUpdate in
            let response = NSExtensionItem()
            response.userInfo = [SFExtensionMessageKey: blocklistUpdate]
            context.completeRequest(returningItems: [response], completionHandler: nil)
        }
    }

    /// Connects to SafariLocalRelayServer, sends `requestType` as a
    /// `{"type": ...}` JSON payload, half-closes, and reads the
    /// blocklist-update response back. Calls `completion` exactly once,
    /// either with that response or (timeout / connection failure /
    /// app not running) with an empty blocklist — mirrors the old App
    /// Group relay's "missing entitlement just means Safari won't see
    /// this update, not a crash" fallback.
    private func queryRelay(requestType: String, completion: @escaping ([String: Any]) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: SafariRelayPort.value) else {
            completion(NativeMessage.blocklistUpdate(.empty))
            return
        }

        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        var didComplete = false
        let finishOnce: ([String: Any]) -> Void = { result in
            guard !didComplete else { return }
            didComplete = true
            connection.cancel()
            completion(result)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + Self.relayTimeout) {
            finishOnce(NativeMessage.blocklistUpdate(.empty))
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let payload = (try? JSONSerialization.data(withJSONObject: ["type": requestType])) ?? Data()
                // contentContext: .finalMessage is what actually sends a
                // TCP half-close (FIN) here — plain `isComplete: true`
                // on the default message context is only a framing
                // marker, not a real half-close, so the relay server's
                // read-until-EOF would never terminate without this and
                // every request would silently fall back to the
                // 2-second timeout below.
                connection.send(content: payload, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { error in
                    guard error == nil else {
                        finishOnce(NativeMessage.blocklistUpdate(.empty))
                        return
                    }
                    Self.receiveResponse(connection, accumulated: Data(), completion: finishOnce)
                })
            case .failed, .cancelled:
                finishOnce(NativeMessage.blocklistUpdate(.empty))
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    private static func receiveResponse(
        _ connection: NWConnection, accumulated: Data, completion: @escaping ([String: Any]) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            var accumulated = accumulated
            if let data { accumulated.append(data) }

            guard error == nil else {
                completion(NativeMessage.blocklistUpdate(.empty))
                return
            }
            guard isComplete else {
                receiveResponse(connection, accumulated: accumulated, completion: completion)
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: accumulated) as? [String: Any] else {
                completion(NativeMessage.blocklistUpdate(.empty))
                return
            }
            completion(json)
        }
    }
}
