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
        let downCompact = Self.compactFormat(rate: down)
        return MetricReading(
            menu: String(format: "%@: ↓ %@ ↑ %@",
                         L10n.tr(.network),
                         inboundBroken ? "--" : downText,
                         Self.format(rate: up)),
            compact: CompactReading(top: "↑\(Self.compactFormat(rate: up))",
                                    bottom: inboundBroken ? "↓--" : "↓\(downCompact)",
                                    uniformFont: true),
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

    /// Short form for the menu bar, e.g. "0.5K", "43.7K", "6.1M".
    /// Keeps the integer part ≤ 3 digits so the number is at most
    /// 6 chars ("999.9X"), which the menu bar width is sized for.
    private static func compactFormat(rate: Double) -> String {
        switch rate {
        case ..<1_000_000:
            return String(format: "%.1fK", rate / 1000)
        case ..<1_000_000_000:
            return String(format: "%.1fM", rate / 1_000_000)
        default:
            return String(format: "%.1fG", rate / 1_000_000_000)
        }
    }
}
