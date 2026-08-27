import Foundation

/// Owns the live, enforced blocklist and its persistence to plain JSON.
/// Adding an entry (tightening) applies and pushes immediately. Removing
/// one (loosening) is delegated to FrictionController and only actually
/// changes `blocklist` once that entry's delay has elapsed — see
/// CLAUDE.md's asymmetric-friction principle.
final class BlocklistStore: ObservableObject {
    @Published private(set) var blocklist: Blocklist
    let friction: FrictionController

    /// Fired with the new blocklist every time it actually changes
    /// (add, or a removal finally applying) — MessagingServer pushes on
    /// this.
    var onChange: ((Blocklist) -> Void)?

    init() {
        self.blocklist = Self.load()
        self.friction = FrictionController()
        friction.onApply = { [weak self] kind, value in
            self?.applyRemoval(kind: kind, value: value)
        }
    }

    // MARK: - Instant (tightening)

    func addChannel(_ rawName: String) {
        add(rawName, keyPath: \.channels)
    }

    func addVideo(_ rawId: String) {
        add(rawId, keyPath: \.videoIds)
    }

    func addKeyword(_ rawKeyword: String) {
        add(rawKeyword, keyPath: \.keywords)
    }

    private func add(_ raw: String, keyPath: WritableKeyPath<Blocklist, [String]>) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !blocklist[keyPath: keyPath].contains(value) else { return }
        blocklist[keyPath: keyPath].append(value)
        persistAndNotify()
    }

    // MARK: - Delayed + confirmed (loosening)

    func requestRemoveChannel(_ name: String) {
        friction.requestRemoval(kind: .channel, value: name)
    }

    func requestRemoveVideo(_ id: String) {
        friction.requestRemoval(kind: .videoId, value: id)
    }

    func requestRemoveKeyword(_ keyword: String) {
        friction.requestRemoval(kind: .keyword, value: keyword)
    }

    func isPendingRemoval(kind: BlocklistEntryKind, value: String) -> Bool {
        friction.pendingRemovals.contains { $0.kind == kind && $0.value == value }
    }

    private func applyRemoval(kind: BlocklistEntryKind, value: String) {
        switch kind {
        case .channel:
            blocklist.channels.removeAll { $0 == value }
        case .videoId:
            blocklist.videoIds.removeAll { $0 == value }
        case .keyword:
            blocklist.keywords.removeAll { $0 == value }
        }
        persistAndNotify()
    }

    // MARK: - Persistence

    private func persistAndNotify() {
        persist()
        onChange?(blocklist)
    }

    private func persist() {
        AppPaths.ensureSupportDirectoryExists()
        guard let data = try? JSONEncoder.ytRestrictor.encode(blocklist) else { return }
        try? data.write(to: AppPaths.blocklistFile, options: .atomic)
    }

    private static func load() -> Blocklist {
        guard
            let data = try? Data(contentsOf: AppPaths.blocklistFile),
            let blocklist = try? JSONDecoder.ytRestrictor.decode(Blocklist.self, from: data)
        else {
            return .empty
        }
        return blocklist
    }
}
