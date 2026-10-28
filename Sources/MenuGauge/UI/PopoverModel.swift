import AppKit
import Combine

struct MetricDescriptor: Identifiable {
    let id: String
    let title: String
    let symbol: String

    static var all: [MetricDescriptor] { [
        .init(id: "cpu", title: "CPU", symbol: "cpu"),
        .init(id: "gpu", title: "GPU", symbol: "cpu"),
        .init(id: "memory", title: L10n.tr(.memory), symbol: "memorychip"),
        .init(id: "disk", title: L10n.tr(.disk), symbol: "internaldrive"),
        .init(id: "temperature",
              title: AppEdition.isAppStore ? L10n.tr(.thermalState) : L10n.tr(.temperature),
              symbol: "thermometer.medium"),
        .init(id: "fan", title: L10n.tr(.fan), symbol: "fan"),
        .init(id: "network", title: L10n.tr(.network), symbol: "arrow.up.arrow.down"),
    ] }

    /// Settings rows for this edition. The App Store build has no fan choice.
    static var offered: [MetricDescriptor] {
        MetricCatalog.offeredDescriptors(appStore: AppEdition.isAppStore)
    }
}

/// Which binary is running. Tests pass an explicit flag into `MetricCatalog`
/// so both editions stay covered without a second test build.
enum AppEdition {
    static var isAppStore: Bool {
        #if MAS
        true
        #else
        false
        #endif
    }
}

/// The metrics both editions can sample, in menu-bar order. The direct
/// edition inserts the SMC fan provider; the App Store edition leaves it out.
enum MetricCatalog {
    static let fanID = "fan"

    static func makeProviders(appStore: Bool) -> [MetricProvider] {
        var providers: [MetricProvider] = [
            CPUMonitor(),
            GPUMonitor(),
            MemoryMonitor(),
            DiskMonitor(),
            TemperatureMonitor(),
        ]
        #if !MAS
        if !appStore {
            providers.append(FanMonitor())
        }
        #else
        // The parameter selects the edition in the direct build. This
        // binary has no fan provider to append.
        _ = appStore
        #endif
        providers.append(NetworkMonitor())
        return providers
    }

    static func offeredDescriptors(appStore: Bool) -> [MetricDescriptor] {
        guard appStore else { return MetricDescriptor.all }
        return MetricDescriptor.all.filter { $0.id != fanID }
    }

    /// A saved fan choice from the direct edition must not count in the
    /// App Store build. Other ids, and their order, stay as stored.
    static func sanitizedSelection(_ saved: [String], appStore: Bool) -> [String] {
        guard appStore else { return saved }
        return saved.filter { $0 != fanID }
    }
}

/// Shared by the menu-bar panel and the Settings window.
/// Menu-bar drawing reads the providers directly and does not use this model.
final class PopoverModel: ObservableObject {
    @Published var readings: [String: MetricReading] = [:]
    @Published var selectedIDs: [String] = []
    @Published var hiddenCount = 0
    @Published var loginState: LoginItem.State = .disabled
    @Published var loginError: String?
    @Published var height: CGFloat = 330
    /// Measured height of the scrollable page content, reported by the view.
    /// 0 until the first layout pass.
    @Published var contentHeight: CGFloat = 0
    var onSelection: ((String, Bool) -> Void)?
    var onLogin: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
    var onOpenSettings: (() -> Void)?
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
