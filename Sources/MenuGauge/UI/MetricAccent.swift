import SwiftUI

/// Per-metric accent colors. The settings card dot and the matching popover
/// row icon both use the same value, so the color is a stable identity for
/// the metric. Every metric gets a distinct color in both appearances.
enum MetricAccent {
    static let ids = ["cpu", "gpu", "memory", "disk", "temperature", "fan", "network"]

    static func lightHex(for id: String) -> UInt32 {
        switch id {
        case "cpu": return 0x0E7C86
        case "gpu": return 0x5B57D1
        case "memory": return 0xC243A0
        case "disk": return 0x9A6B00
        case "temperature": return 0xC2410C
        case "fan": return 0x1F8A4C
        case "network": return 0x0A6FD1
        default: return 0x8A949A
        }
    }

    static func darkHex(for id: String) -> UInt32 {
        switch id {
        case "cpu": return 0x5FCFDD
        case "gpu": return 0x8E8CFF
        case "memory": return 0xE070C8
        case "disk": return 0xFFC857
        case "temperature": return 0xFF7A45
        case "fan": return 0x5EE0A0
        case "network": return 0x0A84FF
        default: return 0x7C858D
        }
    }

    static func color(for id: String) -> Color {
        PanelPalette.adaptive(Int(lightHex(for: id)), Int(darkHex(for: id)))
    }
}
