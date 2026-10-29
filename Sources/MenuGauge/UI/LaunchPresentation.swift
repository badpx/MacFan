import AppKit

/// When the Settings window opens by itself.
///
/// Cold start shows it only the first time the user opens the app.
/// A login-item launch never shows it and does not consume that first
/// launch, so the next time the user opens MenuGauge by hand the window
/// still appears. Reopening an already-running app is handled separately
/// (`applicationShouldHandleReopen`) and does not consult this flag.
///
/// Reset first launch with:
/// `defaults delete com.badpx.macfan didCompleteFirstLaunch`
/// The Mac App Store build stores preferences in its container:
/// `~/Library/Containers/com.badpx.macfan/Data/Library/Preferences/com.badpx.macfan.plist`
enum LaunchPresentation {
    static let firstLaunchKey = "didCompleteFirstLaunch"

    static func shouldShowSettings(launchedAtLogin: Bool, hasCompletedFirstLaunch: Bool) -> Bool {
        if launchedAtLogin { return false }
        return !hasCompletedFirstLaunch
    }
}

/// Login-item launches are an `oapp` Apple event whose `prdt`
/// (`keyAEPropData`) parameter is the enum `lgit`
/// (`keyAELaunchedAsLogInItem`), not a record that contains that field.
/// Finder, Launchpad and `open` send `oapp` with no `prdt`. Read the event
/// during `applicationDidFinishLaunching`; it is not available later.
enum LoginLaunch {
    /// 'oapp'
    static let openApplication = AEEventID(0x6F617070)
    /// 'prdt'
    static let propData = AEKeyword(0x70726474)
    /// 'lgit'
    static let launchedAsLogInItem = OSType(0x6C676974)
    /// 'enum'
    private static let enumerated = DescType(0x656E756D)

    static func isCurrentEvent() -> Bool {
        isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
    }

    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == openApplication else { return false }
        guard let props = event.paramDescriptor(forKeyword: propData) else { return false }
        // The system sends `prdt` as the enum itself.
        if props.descriptorType == enumerated, props.enumCodeValue == launchedAsLogInItem {
            return true
        }
        // A record that nests `lgit` is not what launchd sends. Accept it
        // so a non-system launcher cannot slip past the check.
        guard let flag = props.paramDescriptor(forKeyword: launchedAsLogInItem) else { return false }
        let kind = flag.descriptorType
        if kind == DescType(0x66616C73) { return false } // 'fals'
        if kind == DescType(0x626F6F6C) || kind == DescType(0x74727565) {
            return flag.booleanValue
        }
        return true
    }
}

/// Logout, restart and shutdown send `quit` with a reason. Those must not
/// wait on the in-app confirmation. A Dock or menu quit has no such reason.
enum SessionQuit {
    /// 'quit'
    static let quitApplication = AEEventID(0x71756974)
    /// 'why?'
    static let reasonKeyword = AEKeyword(0x7768793F)

    static func isEndingSession(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == quitApplication else { return false }
        guard let reason = event.paramDescriptor(forKeyword: reasonKeyword) else { return false }
        // shut, rest, rlgo, logo, rrst, rsdn
        let endings: Set<OSType> = [
            0x73687574, 0x72657374, 0x726C676F, 0x6C6F676F, 0x72727374, 0x7273646E,
        ]
        return endings.contains(reason.enumCodeValue)
    }
}
