import SwiftUI

@main
struct YTRestrictorApp: App {
    @StateObject private var store = BlocklistStore()

    init() {
        // No Info.plist (this runs as a plain Swift Package executable,
        // not an app bundle yet — see Phase 6 for launchd/.app
        // packaging), so hide the Dock icon at runtime instead.
        //
        // Deliberately doesn't touch `store` here: reading a
        // @StateObject-wrapped property inside init() isn't guaranteed
        // to be the same instance the view graph later binds to (it can
        // silently be a second, separate BlocklistStore whose messaging
        // wiring never sees real edits). All of that wiring lives inside
        // BlocklistStore's own init instead, which has no such ambiguity.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("YouTube Restrictor", systemImage: "shield.lefthalf.filled") {
            ContentView(store: store, friction: store.friction)
        }
        .menuBarExtraStyle(.window)
    }
}
