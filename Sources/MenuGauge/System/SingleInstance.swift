import Foundation

/// One menu-bar icon per bundle id. A second process — `open -n`, the raw
/// executable, or the website build launched beside the App Store build —
/// yields instead of creating another status item.
///
/// The decision is pure so tests can cover it. The App Sandbox allows the
/// handoff itself: a distributed notification between copies of this bundle
/// id (no extra entitlement) plus `NSRunningApplication.activate`. Activation
/// alone does not call `applicationShouldHandleReopen`, so the existing
/// copy listens for the notification and opens Settings the same way.
struct SingleInstancePeer: Equatable {
    var bundleIdentifier: String?
    var processIdentifier: Int32
}

enum SingleInstance {
    static let handoffNotification = Notification.Name("com.badpx.macfan.showSettings")
    static let snapshotArgument = "--ui-snapshot"
    /// Property-list key on the distributed notification. The sender ignores
    /// its own echo if the center delivers the post back to this process.
    static let senderPIDKey = "pid"

    static func shouldYield(bundleIdentifier: String?,
                            currentPID: Int32,
                            peers: [SingleInstancePeer],
                            arguments: [String]) -> Bool {
        if arguments.contains(snapshotArgument) { return false }
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
        return peers.contains {
            $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier != currentPID
        }
    }
}
