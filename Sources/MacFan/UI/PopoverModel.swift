import AppKit
import Combine

enum PopoverPage: Int, CaseIterable { case overview, configuration }

struct MetricDescriptor: Identifiable {
    let id: String
    let title: String
    let symbol: String

    static var all: [MetricDescriptor] { [
        .init(id: "cpu", title: "CPU", symbol: "cpu"),
        .init(id: "gpu", title: "GPU", symbol: "cpu"),
        .init(id: "memory", title: L10n.tr(.memory), symbol: "memorychip"),
        .init(id: "disk", title: L10n.tr(.disk), symbol: "internaldrive"),
        .init(id: "temperature", title: L10n.tr(.temperature), symbol: "thermometer.medium"),
        .init(id: "fan", title: L10n.tr(.fan), symbol: "fan"),
        .init(id: "network", title: L10n.tr(.network), symbol: "arrow.up.arrow.down"),
    ] }
}

/// Updated only while the popover is open. Menu-bar drawing remains independent.
final class PopoverModel: ObservableObject {
    @Published var readings: [String: MetricReading] = [:]
    @Published var selectedIDs: [String] = []
    @Published var hiddenCount = 0
    @Published var loginState: LoginItem.State = .disabled
    @Published var loginError: String?
    @Published var page: PopoverPage = .overview
    @Published var height: CGFloat = 302
    /// Measured height of the scrollable page content, reported by the view.
    /// 0 until the first layout pass.
    @Published var contentHeight: CGFloat = 0
    var onSelection: ((String, Bool) -> Void)?
    var onLogin: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
    var onPage: (() -> Void)?
}

enum MetricFormat {
    static func number(_ value: Double?, decimals: Int = 1) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.*f", decimals, value)
    }

    static func rate(_ bytes: Double?) -> (value: String, unit: String) {
        guard let bytes, bytes.isFinite, bytes >= 0 else { return ("N/A", "") }
        switch bytes {
        case ..<1_000: return (number(bytes, decimals: 0), "B/s")
        case ..<1_000_000: return (number(bytes / 1_000), "KB/s")
        case ..<1_000_000_000: return (number(bytes / 1_000_000), "MB/s")
        default: return (number(bytes / 1_000_000_000), "GB/s")
        }
    }

    static func heatColor(_ heat: Double?) -> NSColor {
        guard let heat else { return .labelColor }
        return .systemOrange.blended(withFraction: min(max(heat, 0), 1), of: .systemRed) ?? .systemRed
    }
}
