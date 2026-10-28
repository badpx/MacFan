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

/// Login-item launches are an `oapp` Apple event whose `prdt` record
/// contains `lgit` (`keyAELaunchedAsLogInItem`). Finder, Launchpad and
/// `open` send `oapp` without that flag. Read the event during
/// `applicationDidFinishLaunching`; it is not available later.
enum LoginLaunch {
    /// 'oapp'
    static let openApplication = AEEventID(0x6F617070)
    /// 'prdt'
    static let propData = AEKeyword(0x70726474)
    /// 'lgit'
    static let launchedAsLogInItem = AEKeyword(0x6C676974)

    static func isCurrentEvent() -> Bool {
        isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
    }

    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == openApplication else { return false }
        guard let props = event.paramDescriptor(forKeyword: propData) else { return false }
        guard let flag = props.paramDescriptor(forKeyword: launchedAsLogInItem) else { return false }
        // An explicit false is the only negative. Some launchers insert the
        // key without a boolean type; presence then still means login.
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
