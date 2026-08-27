import SwiftUI

@main
struct YTRestrictorApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        // No Info.plist (this runs as a plain Swift Package executable,
        // not an app bundle yet — see Phase 6 for launchd/.app
        // packaging), so hide the Dock icon at runtime instead.
        //
        // Deliberately doesn't touch `coordinator` here — see
        // AppCoordinator's doc comment for why.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("YouTube Restrictor", systemImage: "shield.lefthalf.filled") {
            ContentView(
                store: coordinator.blocklistStore,
                friction: coordinator.blocklistStore.friction,
                heartbeat: coordinator.heartbeatMonitor
            )
        }
        .menuBarExtraStyle(.window)
    }
}
