import SafariServices
import os.log

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
/// app only through the App Group shared container (AppGroupPaths.swift),
/// never the Unix socket native-host/ and the app target use for
/// Firefox/Chrome.
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]

        if let type = message?["type"] as? String, type == "heartbeat" {
            recordHeartbeat()
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: currentBlocklistUpdate()]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func recordHeartbeat() {
        guard let url = AppGroupPaths.heartbeatFile else {
            os_log(.error, "SafariWebExtensionHandler: App Group container unavailable, dropping heartbeat")
            return
        }
        let payload: [String: Any] = ["timestamp": Int(Date().timeIntervalSince1970 * 1000)]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func currentBlocklistUpdate() -> [String: Any] {
        guard
            let url = AppGroupPaths.blocklistFile,
            let data = try? Data(contentsOf: url),
            let blocklist = try? JSONDecoder().decode(Blocklist.self, from: data)
        else {
            return NativeMessage.blocklistUpdate(.empty)
        }
        return NativeMessage.blocklistUpdate(blocklist)
    }
}
