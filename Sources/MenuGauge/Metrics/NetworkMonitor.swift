import AppKit
import Foundation

/// Network throughput (down/up) computed from getifaddrs byte counters
/// over physical interfaces (en*), sampled between two calls.
///
/// Each interface keeps its own baseline (`NetworkCounterLedger`). A
/// 32-bit rollover is applied per interface; a counter that drops by
/// more than one plausible sample, or an interface that appears or
/// disappears, does not produce a spike.
///
/// Some VPN/filter drivers (e.g. CorpLink) swallow inbound packets before
/// the interface byte counters are incremented, leaving rx stuck at 0.
/// When outbound traffic clearly flows while cumulative inbound stays at
/// exactly zero, the inbound counter is considered broken and the
/// download rate is shown as "--" instead of a misleading "0.0K".
final class NetworkMonitor: MetricProvider {

    let id = "network"

    private var ledger = NetworkCounterLedger()
    private var lastSample: Date?
    private var cumulativeRx: UInt64 = 0
    private var cumulativeTx: UInt64 = 0
    private var inboundBroken = false

    func sample() -> MetricReading {
        guard let counters = readCounters() else {
            return MetricReading(menu: "\(L10n.tr(.network)): --")
        }

        let now = Date()
        let previousTime = lastSample
        let delta = ledger.advance(to: counters)
        lastSample = now
        guard let previousTime else { return MetricReading(menu: "\(L10n.tr(.network)): --") }

        let elapsed = now.timeIntervalSince(previousTime)
        guard elapsed > 0 else { return MetricReading(menu: "\(L10n.tr(.network)): --") }

        cumulativeRx &+= delta.rx
        cumulativeTx &+= delta.tx
        if delta.rx > 0 {
            inboundBroken = false
        } else if cumulativeRx == 0 && cumulativeTx > 512 * 1024 {
            inboundBroken = true
        }

        let down = Double(delta.rx) / elapsed
        let up = Double(delta.tx) / elapsed
        let downText = Self.format(rate: down)
        let downCompact = NetworkCompactRate.format(bytesPerSecond: down)
        let upCompact = NetworkCompactRate.format(bytesPerSecond: up)
        return MetricReading(
            menu: String(format: "%@: ↓ %@ ↑ %@",
                         L10n.tr(.network),
                         inboundBroken ? "--" : downText,
                         Self.format(rate: up)),
            compact: CompactReading(top: "↑\(upCompact)",
                                    bottom: inboundBroken ? "↓--" : "↓\(downCompact)",
                                    uniformFont: true,
                                    topWidthTemplate: NetworkCompactRate.widthTemplate),
            value: .network(download: inboundBroken ? nil : down, upload: up)
        )
    }

    private func readCounters() -> [String: NetworkInterfaceCounters]? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var counters: [String: NetworkInterfaceCounters] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let name = String(cString: current.pointee.ifa_name)
            // Physical interfaces only: en0 (Wi-Fi), en1... (Ethernet...).
            guard name.hasPrefix("en"),
                  Int32(current.pointee.ifa_addr.pointee.sa_family) == AF_LINK,
                  let data = current.pointee.ifa_data else { continue }

            // One AF_LINK record per name. These are cumulative counters,
            // so a duplicate replaces the earlier reading instead of being
            // added to it. The fields are u_int32_t; truncating is a no-op
            // for that width and keeps the low 32 bits if the importer
            // presents them as a wider unsigned integer.
            let ifData = data.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = NetworkInterfaceCounters(
                rx: Self.byteCounter(ifData.ifi_ibytes),
                tx: Self.byteCounter(ifData.ifi_obytes)
            )
        }
        return counters
    }

    private static func byteCounter<T: UnsignedInteger>(_ value: T) -> UInt32 {
        UInt32(truncatingIfNeeded: value)
    }

    /// Decimal units (1K = 1000B, 1M = 1000K, 1G = 1000M), K minimum:
    /// sub-K rates are shown as fractions, e.g. 43 B/s -> "0.0K".
    private static func format(rate: Double) -> String {
        switch rate {
        case ..<1_000_000:
            return String(format: "%.1f KB/s", rate / 1000)
        default:
            return String(format: "%.1f MB/s", rate / 1_000_000)
        }
    }

}

/// Menu-bar network rate. At most three digits: one decimal while the
/// integer part has fewer than three digits (`0.5K`, `15.8K`), and an
/// integer once it has three (`510K`). Rounding never produces a fourth
/// digit or a trailing `.0` on a three-digit integer — `99.96K` is `100K`,
/// `999.6K` is `1.0M`. Units stop at G.
enum NetworkCompactRate {
    /// Same face the menu-bar network rows are drawn with.
    static let menuFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let units = ["K", "M", "G"]

    static func format(bytesPerSecond rate: Double) -> String {
        guard rate.isFinite, rate > 0 else { return "0.0K" }
        for (index, unit) in units.enumerated() {
            let scaled = rate / pow(1000, Double(index + 1))
            switch render(scaled) {
            case .promote where index == units.count - 1:
                return "999" + unit
            case .promote:
                continue
            case .text(let body):
                return body + unit
            }
        }
        return "999G"
    }

    /// Arrow-prefixed shapes that cover every compact output, using the
    /// widest digit, plus the broken-inbound placeholder. The column is
    /// exactly as wide as the widest of these — no added slack.
    static func widthCandidates(widestDigit: Character) -> [String] {
        let digit = String(widestDigit)
        var candidates = ["↓--"]
        for unit in units {
            for arrow in ["↑", "↓"] {
                candidates.append("\(arrow)\(digit)\(digit).\(digit)\(unit)")
                candidates.append("\(arrow)\(digit)\(digit)\(digit)\(unit)")
            }
        }
        return candidates
    }

    static func widestDigit(measuring measure: (String) -> CGFloat) -> Character {
        var best: Character = "0"
        var bestWidth: CGFloat = -1
        for digit in "0123456789" {
            let width = measure(String(digit))
            if width > bestWidth {
                bestWidth = width
                best = digit
            }
        }
        return best
    }

    static func measure(_ text: String, font: NSFont = menuFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// The single string the menu-bar column is sized to.
    static let widthTemplate: String = {
        let digit = widestDigit { measure($0) }
        return widthCandidates(widestDigit: digit).max { measure($0) < measure($1) } ?? "↑00.0M"
    }()

    /// Exact advance width of `widthTemplate`. Not rounded up.
    static let columnWidth: CGFloat = measure(widthTemplate)

    private enum Rendered {
        case text(String)
        case promote
    }

    /// `value` is already in the current unit (K, M, or G).
    private static func render(_ value: Double) -> Rendered {
        if value >= 1000 { return .promote }
        let tenths = (value * 10).rounded() / 10
        if tenths >= 1000 { return .promote }
        if tenths >= 100 {
            let whole = value.rounded()
            if whole >= 1000 { return .promote }
            return .text(String(format: "%.0f", locale: posix, whole))
        }
        return .text(String(format: "%.1f", locale: posix, tenths))
    }
}
