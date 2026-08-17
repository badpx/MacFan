import Foundation

/// Network throughput (down/up) computed from getifaddrs byte counters
/// over physical interfaces (en*), sampled between two calls.
///
/// Some VPN/filter drivers (e.g. CorpLink) swallow inbound packets before
/// the interface byte counters are incremented, leaving rx stuck at 0.
/// When outbound traffic clearly flows while cumulative inbound stays at
/// exactly zero, the inbound counter is considered broken and the
/// download rate is shown as "--" instead of a misleading "0B".
final class NetworkMonitor: MetricProvider {

    let id = "network"

    private var previous: (rx: UInt64, tx: UInt64, time: Date)?
    private var cumulativeRx: UInt64 = 0
    private var cumulativeTx: UInt64 = 0
    private var inboundBroken = false

    func sample() -> MetricReading {
        guard let counters = readCounters() else {
            return MetricReading(menu: "网络: --")
        }

        let now = Date()
        defer { previous = (counters.rx, counters.tx, now) }
        guard let previous else { return MetricReading(menu: "网络: --") }

        let elapsed = now.timeIntervalSince(previous.time)
        guard elapsed > 0 else { return MetricReading(menu: "网络: --") }

        let rxDelta = counters.rx &- previous.rx
        let txDelta = counters.tx &- previous.tx
        cumulativeRx &+= rxDelta
        cumulativeTx &+= txDelta
        if rxDelta > 0 {
            inboundBroken = false
        } else if cumulativeRx == 0 && cumulativeTx > 512 * 1024 {
            inboundBroken = true
        }

        let down = Double(rxDelta) / elapsed
        let up = Double(txDelta) / elapsed
        let downText = Self.format(rate: down)
        let downCompact = Self.compactFormat(rate: down)
        return MetricReading(
            menu: String(format: "网络: ↓ %@ ↑ %@",
                         inboundBroken ? "--" : downText,
                         Self.format(rate: up)),
            compact: CompactReading(top: "↑\(Self.compactFormat(rate: up))",
                                    bottom: inboundBroken ? "↓--" : "↓\(downCompact)",
                                    uniformFont: true)
        )
    }

    private func readCounters() -> (rx: UInt64, tx: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let name = String(cString: current.pointee.ifa_name)
            // Physical interfaces only: en0 (Wi-Fi), en1... (Ethernet...).
            guard name.hasPrefix("en"),
                  Int32(current.pointee.ifa_addr.pointee.sa_family) == AF_LINK,
                  let data = current.pointee.ifa_data else { continue }

            let ifData = data.assumingMemoryBound(to: if_data.self).pointee
            rx &+= UInt64(ifData.ifi_ibytes)
            tx &+= UInt64(ifData.ifi_obytes)
        }
        return (rx, tx)
    }

    private static func format(rate: Double) -> String {
        switch rate {
        case ..<1024:
            return String(format: "%.0f B/s", rate)
        case ..<(1024 * 1024):
            return String(format: "%.1f KB/s", rate / 1024)
        default:
            return String(format: "%.1f MB/s", rate / 1_048_576)
        }
    }

    /// Short form for the menu bar, e.g. "43.7K", "6.1M", "128B".
    /// Keeps the integer part ≤ 3 digits so the number is at most
    /// 6 chars ("999.9X"), which the menu bar width is sized for.
    private static func compactFormat(rate: Double) -> String {
        switch rate {
        case ..<1024:
            return String(format: "%.0fB", rate)
        case ..<(1024 * 1024):
            return String(format: "%.1fK", rate / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1fM", rate / 1_048_576)
        default:
            return String(format: "%.1fG", rate / 1_073_741_824)
        }
    }
}
