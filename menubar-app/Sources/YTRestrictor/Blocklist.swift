import Foundation

/// Same shape as extension/blocklist.example.json and the `blocklist`
/// field of docs/PROTOCOL.md's blocklist-update message. Keep these three
/// in sync if this shape ever changes.
struct Blocklist: Codable, Equatable {
    var channelIds: [String] = []
    var videoIds: [String] = []
    var keywords: [String] = []

    static let empty = Blocklist()
}

enum BlocklistEntryKind: String, Codable {
    case channelId
    case videoId
    case keyword
}
