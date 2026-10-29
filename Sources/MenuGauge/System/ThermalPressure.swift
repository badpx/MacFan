import Darwin
import Foundation

// notify.h is not in the SDK's Swift module map; bind the three calls used.
@_silgen_name("notify_register_check")
private func notify_register_check(_ name: UnsafePointer<CChar>,
                                   _ token: UnsafeMutablePointer<Int32>) -> UInt32
@_silgen_name("notify_get_state")
private func notify_get_state(_ token: Int32, _ state: UnsafeMutablePointer<UInt64>) -> UInt32
@_silgen_name("notify_cancel")
private func notify_cancel(_ token: Int32) -> UInt32

private let notifyStatusOK: UInt32 = 0

/// thermald's five-level thermal pressure, published through notifyd as
/// `com.apple.system.thermalpressurelevel` (OSThermalNotification.h).
/// Readable without root and from inside the App Store sandbox, unlike SMC.
enum ThermalPressure: Int {
    case nominal = 0, moderate, heavy, trapping, sleeping

    /// Segments lit on the menu-bar gauge: nominal leaves all four empty.
    var segments: Int { rawValue }

    /// True once the system is shedding load (heavy throttling or worse).
    var isHot: Bool { rawValue >= ThermalPressure.heavy.rawValue }

    /// Fixed-width menu-bar token, three glyphs at most.
    var compactToken: String {
        switch self {
        case .nominal: return "OK"
        case .moderate: return "MID"
        case .heavy: return "HI"
        case .trapping: return "HOT"
        case .sleeping: return "MAX"
        }
    }

    /// Orange-to-red ramp for the menu line: nil is normal. Same shape as
    /// the old four-state ramp with heavy interpolated between fair and serious.
    var heat: Double? {
        switch self {
        case .nominal: return nil
        case .moderate: return 0.35
        case .heavy: return 0.6
        case .trapping: return 0.85
        case .sleeping: return 1
        }
    }

    /// Popover wording for this pressure level.
    var labelKey: L10n.Key {
        switch self {
        case .nominal: return .thermalNominal
        case .moderate: return .thermalFair
        case .heavy: return .thermalHeavy
        case .trapping: return .thermalSerious
        case .sleeping: return .thermalCritical
        }
    }

    /// Coarse four-state view matching `ProcessInfo.thermalState`, used for
    /// the accessibility label so its wording stays on the existing strings.
    var thermalLevel: ThermalLevel {
        switch self {
        case .nominal: return .nominal
        case .moderate, .heavy: return .fair
        case .trapping: return .serious
        case .sleeping: return .critical
        }
    }

    /// Live pressure from notifyd; falls back to the four-state
    /// `ProcessInfo.thermalState` when the notification state is unreadable.
    static var current: ThermalPressure {
        var token: Int32 = 0
        guard notify_register_check("com.apple.system.thermalpressurelevel", &token) == notifyStatusOK else {
            return fallback
        }
        defer { _ = notify_cancel(token) }
        var state: UInt64 = 0
        guard notify_get_state(token, &state) == notifyStatusOK else { return fallback }
        return ThermalPressure(rawValue: Int(state)) ?? .heavy
    }

    private static var fallback: ThermalPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .moderate
        case .serious: return .trapping
        case .critical: return .sleeping
        @unknown default: return .heavy
        }
    }
}
