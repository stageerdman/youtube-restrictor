import Foundation

/// Same shape as extension/blocklist.example.json and the `blocklist`
/// field of docs/PROTOCOL.md's blocklist-update message. Keep these three
/// in sync if this shape ever changes.
///
/// `channels` holds plain display names (e.g. "Grian"), matched
/// case-insensitively — not channel IDs. Embedded (cross-origin) players
/// can only ever be resolved to a name, via YouTube's oEmbed endpoint,
/// never an ID, so native-page matching uses names too for consistency.
struct Blocklist: Codable, Equatable {
    var channels: [String] = []
    var videoIds: [String] = []
    var keywords: [String] = []

    static let empty = Blocklist()
}

enum BlocklistEntryKind: String, Codable {
    case channel
    case videoId
    case keyword
}
