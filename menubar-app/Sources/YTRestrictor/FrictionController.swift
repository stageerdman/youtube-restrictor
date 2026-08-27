import Foundation

/// A removal the owner has typed confirmation for, waiting out its delay
/// before it actually takes effect. Not yet reflected in the live
/// blocklist — see BlocklistStore.effectiveBlocklist.
struct PendingRemoval: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: BlocklistEntryKind
    var value: String
    var requestedAt: Date
    var applyAt: Date
}

private struct FrictionState: Codable {
    var pendingRemovals: [PendingRemoval] = []
    var removalDelayMinutes: Int = 30
}

/// Owns the asymmetric-friction rule: adding a restriction is applied by
/// BlocklistStore immediately and never passes through here. Removing one
/// (or disabling enforcement, once that setting exists) must go through
/// requestRemoval and wait out removalDelayMinutes, cancellable at any
/// point before it applies. No blocklist storage or UI here.
final class FrictionController: ObservableObject {
    @Published private(set) var pendingRemovals: [PendingRemoval] = []
    @Published var removalDelayMinutes: Int {
        didSet { persist() }
    }

    /// Called (once) for each pending removal whose delay has elapsed.
    var onApply: ((BlocklistEntryKind, String) -> Void)?

    private var timer: Timer?

    init() {
        let state = Self.load()
        self.pendingRemovals = state.pendingRemovals
        self.removalDelayMinutes = state.removalDelayMinutes
        startTicking()
    }

    func requestRemoval(kind: BlocklistEntryKind, value: String) {
        let now = Date()
        let pending = PendingRemoval(
            id: UUID(),
            kind: kind,
            value: value,
            requestedAt: now,
            applyAt: now.addingTimeInterval(TimeInterval(removalDelayMinutes * 60))
        )
        pendingRemovals.append(pending)
        persist()
    }

    func cancelRemoval(id: UUID) {
        pendingRemovals.removeAll { $0.id == id }
        persist()
    }

    private func startTicking() {
        applyDuePendingRemovals()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.applyDuePendingRemovals()
        }
    }

    private func applyDuePendingRemovals() {
        let now = Date()
        let due = pendingRemovals.filter { $0.applyAt <= now }
        guard !due.isEmpty else { return }
        pendingRemovals.removeAll { $0.applyAt <= now }
        persist()
        for item in due {
            onApply?(item.kind, item.value)
        }
    }

    private func persist() {
        AppPaths.ensureSupportDirectoryExists()
        let state = FrictionState(
            pendingRemovals: pendingRemovals, removalDelayMinutes: removalDelayMinutes
        )
        guard let data = try? JSONEncoder.ytRestrictor.encode(state) else { return }
        try? data.write(to: AppPaths.frictionStateFile, options: .atomic)
    }

    private static func load() -> FrictionState {
        guard
            let data = try? Data(contentsOf: AppPaths.frictionStateFile),
            let state = try? JSONDecoder.ytRestrictor.decode(FrictionState.self, from: data)
        else {
            return FrictionState()
        }
        return state
    }
}

extension JSONEncoder {
    static let ytRestrictor: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let ytRestrictor: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
