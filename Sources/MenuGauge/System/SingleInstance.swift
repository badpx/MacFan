import Foundation

/// One menu-bar icon per bundle id. A second process — `open -n`, the raw
/// executable, or the website build launched beside the App Store build —
/// yields instead of creating another status item.
///
/// The decision is pure so tests can cover it. The App Sandbox allows the
/// handoff itself: a distributed notification between copies of this bundle
/// id (no extra entitlement) plus `NSRunningApplication.activate`. The post
/// must use `userInfo: nil`; a dictionary is dropped or delivered
/// unreliably inside the sandbox. The yielding process posts before it
/// registers an observer, so the receiver does not filter by PID.
/// Activation alone does not call `applicationShouldHandleReopen`, so the
/// existing copy listens for the notification and opens Settings.
struct SingleInstancePeer: Equatable {
    var bundleIdentifier: String?
    var processIdentifier: Int32
}

enum SingleInstance {
    static let handoffNotification = Notification.Name("com.badpx.macfan.showSettings")
    static let snapshotArgument = "--ui-snapshot"
    /// Sandbox delivery requires this to stay nil.
    static let handoffUserInfo: [AnyHashable: Any]? = nil

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
