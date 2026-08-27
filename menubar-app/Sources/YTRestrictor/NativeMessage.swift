import Foundation

/// Mirrors docs/PROTOCOL.md's message shapes. This app is the socket
/// *server*; native-host/ (spawned per Firefox session) is the client.
enum NativeMessage {
    static let protocolVersion = "0.1.0"

    static func blocklistUpdate(_ blocklist: Blocklist) -> [String: Any] {
        [
            "type": "blocklist-update",
            "version": protocolVersion,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "blocklist": [
                "channels": blocklist.channels,
                "videoIds": blocklist.videoIds,
                "keywords": blocklist.keywords,
            ],
        ]
    }
}
