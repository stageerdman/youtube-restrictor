import Foundation

/// Where SafariWebExtensionHandler (sandboxed .appex, this file's other
/// caller) reaches SafariLocalRelayServer (this app's main process) —
/// replaces the old App Group file relay entirely. See
/// docs/PROTOCOL.md's "Safari's transport" for why: a loopback TCP
/// connection is governed by the `com.apple.security.network.client`
/// sandbox entitlement alone (granted silently at code-signing time,
/// same as any sandboxed app making an outgoing connection) — unlike
/// reading a shared App Group container, which macOS's
/// kTCCServiceSystemPolicyAppData check re-prompts for on every single
/// launch of a development-signed (non-Developer-Program) process,
/// regardless of how rarely the container is actually touched.
enum SafariRelayPort {
    /// Arbitrary, just needs to not collide with something else already
    /// running locally. Loopback-only (127.0.0.1) — see
    /// SafariLocalRelayServer's requiredLocalEndpoint — so this is never
    /// reachable from outside this Mac.
    static let value: UInt16 = 47_813
}
