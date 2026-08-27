import Foundation

/// Single source of truth for where this app keeps its files, mirroring
/// native-host/src/socket-path.js on the extension/native-host side.
enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("YTRestrictor", isDirectory: true)
    }

    static var blocklistFile: URL {
        supportDirectory.appendingPathComponent("blocklist.json")
    }

    /// Pending (not-yet-applied) removal requests and the owner's
    /// configured delay, together — see FrictionController.
    static var frictionStateFile: URL {
        supportDirectory.appendingPathComponent("friction-state.json")
    }

    /// Must match native-host/src/socket-path.js exactly.
    static var socketPath: String {
        supportDirectory.appendingPathComponent("host.sock").path
    }

    static func ensureSupportDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: supportDirectory, withIntermediateDirectories: true
        )
    }
}
