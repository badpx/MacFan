import AppKit
import Foundation

/// Network throughput (down/up) over physical interfaces (en*).
///
/// Counters come from `sysctl` `NET_RT_IFLIST2` (`if_data64`, 64-bit
/// `ifi_ibytes` / `ifi_obytes`). That call is public and needs no
/// sandbox entitlement. If it fails, `getifaddrs` supplies the 32-bit
/// `if_data` counters zero-extended to 64-bit; a decrease is then a
/// reset rather than a guessed 4 GiB wrap, so one sample can under-count
/// across a rollover but cannot show a multi-gigabyte spike.
/// Each interface keeps its own baseline (`NetworkCounterLedger`).
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
        let elapsed = previousTime.map { now.timeIntervalSince($0) } ?? 0
        let delta = ledger.advance(to: counters, elapsed: elapsed)
        lastSample = now
        guard previousTime != nil, elapsed > 0 else {
            return MetricReading(menu: "\(L10n.tr(.network)): --")
        }

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
        if let counters = Self.readInterfaceCounters64() {
            return counters
        }
        return Self.readInterfaceCounters32()
    }

    /// 64-bit counters from `NET_RT_IFLIST2`. Nil only when `sysctl` fails;
    /// an empty map means the call worked and no `en*` interface is up.
    private static func readInterfaceCounters64() -> [String: NetworkInterfaceCounters]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, Int32(NET_RT_IFLIST2), 0]
        for _ in 0..<2 {
            var length = 0
            if sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) != 0 || length <= 0 {
                return nil
            }
            let buffer = UnsafeMutableRawPointer.allocate(
                byteCount: length, alignment: MemoryLayout<if_msghdr2>.alignment)
            defer { buffer.deallocate() }
            if sysctl(&mib, u_int(mib.count), buffer, &length, nil, 0) != 0 {
                continue
            }
            return parseInterfaceList2(buffer, length: length)
        }
        return nil
    }

    private static func parseInterfaceList2(_ buffer: UnsafeMutableRawPointer,
                                            length: Int) -> [String: NetworkInterfaceCounters] {
        var counters: [String: NetworkInterfaceCounters] = [:]
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let header = buffer.advanced(by: offset)
                .assumingMemoryBound(to: if_msghdr.self).pointee
            let messageLength = Int(header.ifm_msglen)
            if messageLength <= 0 { break }
            if Int32(header.ifm_type) == RTM_IFINFO2,
               offset + MemoryLayout<if_msghdr2>.size <= length {
                let info = buffer.advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr2.self).pointee
                if let name = interfaceName(index: info.ifm_index), name.hasPrefix("en") {
                    let data = info.ifm_data
                    counters[name] = NetworkInterfaceCounters(
                        rx: data.ifi_ibytes, tx: data.ifi_obytes, baudrate: data.ifi_baudrate)
                }
            }
            offset += messageLength
        }
        return counters
    }

    /// 32-bit `getifaddrs` counters, widened. A later decrease (including a
    /// real 4 GiB rollover) is a reset, not a wrap.
    private static func readInterfaceCounters32() -> [String: NetworkInterfaceCounters]? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var counters: [String: NetworkInterfaceCounters] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en"),
                  Int32(current.pointee.ifa_addr.pointee.sa_family) == AF_LINK,
                  let data = current.pointee.ifa_data else { continue }

            let ifData = data.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = NetworkInterfaceCounters(
                rx: UInt64(ifData.ifi_ibytes),
                tx: UInt64(ifData.ifi_obytes),
                baudrate: UInt64(ifData.ifi_baudrate))
        }
        return counters
    }

    private static func interfaceName<Index: BinaryInteger>(index: Index) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        let name: String? = buffer.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress,
                  if_indextoname(UInt32(truncatingIfNeeded: index), base) != nil else { return nil }
            return String(cString: base)
        }
        guard let name, !name.isEmpty else { return nil }
        return name
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
