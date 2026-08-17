import Foundation
import ServiceManagement

/// Launch-at-login management (macOS 13+). The first time the user enables
/// it, macOS may require approval in System Settings > General > Login Items.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MacFan: failed to update login item: \(error.localizedDescription)")
        }
    }
}
