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

    init(channels: [String] = [], videoIds: [String] = [], keywords: [String] = []) {
        self.channels = channels
        self.videoIds = videoIds
        self.keywords = keywords
    }

    // Custom decoding so an on-disk file from an older schema (missing a
    // field this shape has since gained) degrades that one field to
    // empty instead of failing to decode at all and silently wiping the
    // owner's entire blocklist back to .empty — that happened once
    // already, when `channels` replaced `channelIds`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channels = try container.decodeIfPresent([String].self, forKey: .channels) ?? []
        videoIds = try container.decodeIfPresent([String].self, forKey: .videoIds) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }
}

enum BlocklistEntryKind: String, Codable {
    case channel
    case videoId
    case keyword
}
