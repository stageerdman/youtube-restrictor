import Foundation

/// Owns the live, enforced blocklist, its persistence to plain JSON, and
/// pushing it out over the messaging server. Adding an entry (tightening)
/// applies and pushes immediately. Removing one (loosening) is delegated
/// to FrictionController and only actually changes `blocklist` once that
/// entry's delay has elapsed — see CLAUDE.md's asymmetric-friction
/// principle.
///
/// Owns (rather than being wired to from outside, e.g. from the App
/// struct's init) its MessagingServer deliberately: this class's own
/// init is the one place guaranteed to run exactly once against the
/// real, persistent instance — unlike code in the SwiftUI App struct's
/// init(), which can end up wiring a throwaway @StateObject instance
/// that the view graph never actually uses.
final class BlocklistStore: ObservableObject {
    @Published private(set) var blocklist: Blocklist
    let friction: FrictionController
    private let messagingServer = MessagingServer()

    init() {
        self.blocklist = Self.load()
        self.friction = FrictionController()
        friction.onApply = { [weak self] kind, value in
            self?.applyRemoval(kind: kind, value: value)
        }

        // Push the current blocklist as soon as a native host connects,
        // so a freshly (re)launched extension is in sync immediately
        // rather than waiting for the next edit. Wired before start()
        // so there's no window where an early connection could arrive
        // before this callback is set.
        messagingServer.onClientConnected = { [weak self] in
            guard let self else { return }
            self.messagingServer.broadcast(NativeMessage.blocklistUpdate(self.blocklist))
        }
        messagingServer.start()
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
