import Foundation
import ServiceManagement

/// Launch-at-login management (macOS 13+). The first time the user enables
/// it, macOS may require approval in System Settings > General > Login Items.
enum LoginItem {

    enum State { case enabled, disabled, requiresApproval, unavailable }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .disabled
        default: return .unavailable
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if state == .enabled || state == .requiresApproval { return }
            try SMAppService.mainApp.register()
        } else {
            if state == .disabled { return }
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
