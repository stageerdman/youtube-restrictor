import SwiftUI

struct RemovalRequest: Identifiable {
    let id = UUID()
    let kind: BlocklistEntryKind
    let value: String
}

struct ContentView: View {
    @ObservedObject var store: BlocklistStore
    @ObservedObject var friction: FrictionController

    @State private var newChannel = ""
    @State private var newVideo = ""
    @State private var newKeyword = ""
    @State private var confirmingRemoval: RemovalRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("YouTube Restrictor").font(.headline)

                BlocklistSectionView(
                    title: "Channels", placeholder: "Channel name",
                    entries: store.blocklist.channels, kind: .channel,
                    newValue: $newChannel, isPending: store.isPendingRemoval,
                    onAdd: store.addChannel,
                    onRemove: { confirmingRemoval = RemovalRequest(kind: .channel, value: $0) }
                )
                BlocklistSectionView(
                    title: "Videos", placeholder: "Video ID",
                    entries: store.blocklist.videoIds, kind: .videoId,
                    newValue: $newVideo, isPending: store.isPendingRemoval,
                    onAdd: store.addVideo,
                    onRemove: { confirmingRemoval = RemovalRequest(kind: .videoId, value: $0) }
                )
                BlocklistSectionView(
                    title: "Keywords", placeholder: "Keyword",
                    entries: store.blocklist.keywords, kind: .keyword,
                    newValue: $newKeyword, isPending: store.isPendingRemoval,
                    onAdd: store.addKeyword,
                    onRemove: { confirmingRemoval = RemovalRequest(kind: .keyword, value: $0) }
                )

                if !friction.pendingRemovals.isEmpty {
                    Divider()
                    Text("Pending removals").font(.subheadline).bold()
                    ForEach(friction.pendingRemovals) { pending in
                        HStack {
                            Text(pending.value).lineLimit(1)
                            Spacer()
                            Text(pending.applyAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Cancel") { friction.cancelRemoval(id: pending.id) }
                                .buttonStyle(.link)
                        }
                    }
                }

                Divider()
                Stepper(
                    "Removal delay: \(friction.removalDelayMinutes) min",
                    value: $friction.removalDelayMinutes, in: 1...240
                )
                Text("Adding a restriction is instant. Removing one waits out this delay, and you can cancel it any time before it applies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                Button("Quit YouTube Restrictor") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .frame(width: 380, height: 480)
        .sheet(item: $confirmingRemoval) { request in
            RemovalConfirmationView(
                request: request,
                onConfirm: {
                    switch request.kind {
                    case .channel: store.requestRemoveChannel(request.value)
                    case .videoId: store.requestRemoveVideo(request.value)
                    case .keyword: store.requestRemoveKeyword(request.value)
                    }
                    confirmingRemoval = nil
                },
                onCancel: { confirmingRemoval = nil }
            )
        }
    }
}

private struct BlocklistSectionView: View {
    let title: String
    let placeholder: String
    let entries: [String]
    let kind: BlocklistEntryKind
    @Binding var newValue: String
    let isPending: (BlocklistEntryKind, String) -> Bool
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()

            ForEach(entries, id: \.self) { entry in
                HStack {
                    Text(entry).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if isPending(kind, entry) {
                        Text("removal pending").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Remove") { onRemove(entry) }
                            .buttonStyle(.link)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                TextField(placeholder, text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submit() }
                Button("Add", action: submit)
            }
        }
    }

    private func submit() {
        onAdd(newValue)
        newValue = ""
    }
}

private struct RemovalConfirmationView: View {
    let request: RemovalRequest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typedValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remove from blocklist?").font(.headline)
            Text("Type the exact value below to confirm. It won't actually be removed until the removal delay finishes — you can cancel any time before then.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(request.value)
                .font(.system(.body, design: .monospaced))
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            TextField("Type it here to confirm", text: $typedValue)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Start removal", action: onConfirm)
                    .disabled(typedValue != request.value)
            }
        }
        .padding()
        .frame(width: 340)
    }
}
