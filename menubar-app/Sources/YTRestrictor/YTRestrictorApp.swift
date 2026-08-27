import SwiftUI

@main
struct YTRestrictorApp: App {
    @StateObject private var store = BlocklistStore()
    private let messagingServer = MessagingServer()

    init() {
        // No Info.plist (this runs as a plain Swift Package executable,
        // not an app bundle yet — see Phase 6 for launchd/.app
        // packaging), so hide the Dock icon at runtime instead.
        NSApplication.shared.setActivationPolicy(.accessory)

        messagingServer.start()
        let server = messagingServer
        store.onChange = { blocklist in
            server.broadcast(NativeMessage.blocklistUpdate(blocklist))
        }
        // Push the current blocklist as soon as a native host connects,
        // so a freshly (re)launched extension is in sync immediately
        // rather than waiting for the next edit.
        messagingServer.onClientConnected = { [store] in
            server.broadcast(NativeMessage.blocklistUpdate(store.blocklist))
        }
    }

    var body: some Scene {
        MenuBarExtra("YouTube Restrictor", systemImage: "shield.lefthalf.filled") {
            ContentView(store: store, friction: store.friction)
        }
        .menuBarExtraStyle(.window)
    }
}
