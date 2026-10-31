import Darwin
import Foundation

/// System memory pressure, as published by the kernel.
///
/// `kern.memorystatus_vm_pressure_level` is a read-only sysctl. The App
/// Sandbox profile allows `sysctl-read` (system.sb), so this needs no
/// entitlement and no private API. The values match the kernel's
/// `memorystatus_vm_pressure_level`: 1 normal, 2 warning, 4 critical.
enum MemoryPressure: Int {
    case normal = 1
    case warning = 2
    case critical = 4

    /// Color ramp used by the popover's memory row. Normal keeps the
    /// standard label color; warning is orange; critical is red.
    var heat: Double? {
        switch self {
        case .normal: return nil
        case .warning: return 0
        case .critical: return 1
        }
    }

    static var current: MemoryPressure {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level",
                           &value, &size, nil, 0) == 0 else {
            return .normal
        }
        return from(kernelValue: value)
    }

    /// Unknown values fall back to normal rather than showing a warning.
    static func from(kernelValue: Int32) -> MemoryPressure {
        MemoryPressure(rawValue: Int(kernelValue)) ?? .normal
    }
}
