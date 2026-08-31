import Foundation

/// Owns the live, enforced blocklist and its persistence to plain JSON.
/// Adding an entry (tightening) applies and pushes immediately. Removing
/// one (loosening) is delegated to FrictionController and only actually
/// changes `blocklist` once that entry's delay has elapsed — see
/// CLAUDE.md's asymmetric-friction principle.
///
/// Takes its MessagingServer injected rather than creating its own: both
/// this store and EnforcementController's heartbeat tracking need to
/// share the single real socket server, and AppCoordinator is the one
/// place that constructs and wires all of that together — see its doc
/// comment for why that wiring can't safely live in the SwiftUI App
/// struct's init() instead.
final class BlocklistStore: ObservableObject {
    @Published private(set) var blocklist: Blocklist
    let friction: FrictionController
    private let messagingServer: MessagingServer

    init(messagingServer: MessagingServer) {
        self.messagingServer = messagingServer
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
        messagingServer.broadcast(NativeMessage.blocklistUpdate(blocklist))
    }

    private func persist() {
        AppPaths.ensureSupportDirectoryExists()
        guard let data = try? JSONEncoder.ytRestrictor.encode(blocklist) else { return }
        try? data.write(to: AppPaths.blocklistFile, options: .atomic)

        // Safari can't reach AppPaths.blocklistFile (sandboxed) or the
        // socket messagingServer just broadcast on — it polls this App
        // Group copy instead, on its own next heartbeat. See
        // docs/PROTOCOL.md's "Safari's transport". Best-effort: a
        // missing/misconfigured App Group entitlement just means Safari
        // won't see this update, not a crash here.
        if let url = AppGroupPaths.blocklistFile {
            try? data.write(to: url, options: .atomic)
        }
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
