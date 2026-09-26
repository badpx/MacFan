import Foundation

/// Short two-line form shown in the menu bar: a value line and a label
/// line (e.g. "16%" over "CPU"). `uniformFont` keeps both lines at the
/// same size (used by the network widget: up over down).
/// `topWidthTemplate` is a worst-case string (e.g. "100%") used to give
/// the widget a fixed width, so the menu bar does not resize as the
/// value's digit count changes.
struct CompactReading {
    let top: String
    let bottom: String
    let uniformFont: Bool
    let topWidthTemplate: String?

    init(top: String, bottom: String, uniformFont: Bool = false,
         topWidthTemplate: String? = nil) {
        self.top = top
        self.bottom = bottom
        self.uniformFont = uniformFont
        self.topWidthTemplate = topWidthTemplate
    }
}

/// Structured values for the popover. Capacity is expressed in the same
/// GB/GiB convention as its provider; network rates are bytes per second.
enum MetricValue {
    case percent(Double)
    case capacity(used: Double, total: Double)
    case temperature(Double)
    case fan(Double)
    case network(download: Double?, upload: Double?)

    var scalar: Double? {
        switch self {
        case .percent(let value), .temperature(let value), .fan(let value): return value
        default: return nil
        }
    }
}

/// One reading of a metric, in two formats:
/// - menu: full line shown in the dropdown, e.g. "CPU: 12.3 %"
/// - compact: short two-line form for the menu bar, nil when there is no
///   usable value (never shown in the menu bar).
struct MetricReading {
    let menu: String
    let compact: CompactReading?
    /// Warning severity for the menu line: nil = normal color,
    /// 0 = just over the warning threshold (orange), 1 = critical (red).
    let heat: Double?
    let value: MetricValue?

    init(menu: String, compact: CompactReading? = nil, heat: Double? = nil,
         value: MetricValue? = nil) {
        self.menu = menu
        self.compact = compact
        self.heat = heat
        self.value = value
    }
}

/// A single system metric shown in the menu and, when enabled by the user,
/// directly in the menu bar. Conform for future metrics — the controller
/// renders whatever the providers return.
protocol MetricProvider {
    /// Stable identifier used to persist the user's menu bar selection.
    var id: String { get }
    func sample() -> MetricReading
}
