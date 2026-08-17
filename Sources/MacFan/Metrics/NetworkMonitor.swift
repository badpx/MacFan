import Foundation

/// Network throughput (down/up) computed from getifaddrs byte counters
/// over physical interfaces (en*), sampled between two calls.
final class NetworkMonitor: MetricProvider {

    let id = "network"

    private var previous: (rx: UInt64, tx: UInt64, time: Date)?

    func sample() -> MetricReading {
        guard let counters = readCounters() else {
            return MetricReading(menu: "网络: --")
        }

        let now = Date()
        defer { previous = (counters.rx, counters.tx, now) }
        guard let previous else { return MetricReading(menu: "网络: --") }

        let elapsed = now.timeIntervalSince(previous.time)
        guard elapsed > 0 else { return MetricReading(menu: "网络: --") }

        let down = Double(counters.rx &- previous.rx) / elapsed
        let up = Double(counters.tx &- previous.tx) / elapsed
        return MetricReading(
            menu: String(format: "网络: ↓ %@ ↑ %@", Self.format(rate: down), Self.format(rate: up)),
            compact: CompactReading(top: "↑\(Self.compactFormat(rate: up))",
                                    bottom: "↓\(Self.compactFormat(rate: down))",
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
    private static func compactFormat(rate: Double) -> String {
        switch rate {
        case ..<1024:
            return String(format: "%.0fB", rate)
        case ..<(1024 * 1024):
            return String(format: "%.1fK", rate / 1024)
        default:
            return String(format: "%.1fM", rate / 1_048_576)
        }
    }
}
