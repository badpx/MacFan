import Foundation

/// Byte counters for one `en*` interface.
///
/// `ifi_ibytes` / `ifi_obytes` on `if_data64` (from `NET_RT_IFLIST2`) are
/// 64-bit. The `getifaddrs` fallback only has the 32-bit `if_data` fields,
/// zero-extended into these same `UInt64`s. `baudrate` is `ifi_baudrate`
/// in bits per second; 0 means the link speed is unknown.
struct NetworkInterfaceCounters: Equatable {
    var rx: UInt64
    var tx: UInt64
    var baudrate: UInt64 = 0
}

/// Bytes transferred between two samples, summed across interfaces.
struct NetworkByteDelta: Equatable {
    var rx: UInt64
    var tx: UInt64

    static let zero = NetworkByteDelta(rx: 0, tx: 0)
}

/// Per-interface baselines and the pure diff between two readings.
///
/// The monitor used to add every interface into one running total and
/// subtract with `UInt64` wrapping arithmetic. A drop — unplugging a
/// dock NIC, or a counter restart — wrapped to a huge rate. Counters are
/// now 64-bit, so a decrease is a reset and contributes 0 for that
/// sample. The new reading still becomes the baseline. A new interface
/// only establishes a baseline; a missing one is dropped.
struct NetworkCounterLedger: Equatable {
    /// `ifi_baudrate` is a nominal bit rate. A sample may run long and a
    /// link may burst, so a delta is discarded only when it implies more
    /// than twice that rate. A zero baudrate skips the cap.
    static let baudrateMargin: Double = 2

    private(set) var baseline: [String: NetworkInterfaceCounters] = [:]

    /// Diff `current` against the stored baselines, then replace them.
    ///
    /// `elapsed` is the seconds since the previous sample. Zero skips the
    /// baudrate cap (the caller discards that delta anyway).
    mutating func advance(to current: [String: NetworkInterfaceCounters],
                          elapsed: TimeInterval = 0) -> NetworkByteDelta {
        let delta = Self.delta(from: baseline, to: current, elapsed: elapsed)
        baseline = current
        return delta
    }

    static func delta(
        from previous: [String: NetworkInterfaceCounters],
        to current: [String: NetworkInterfaceCounters],
        elapsed: TimeInterval = 0
    ) -> NetworkByteDelta {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        for (name, sample) in current {
            guard let prior = previous[name] else { continue }
            let speed = sample.baudrate > 0 ? sample.baudrate : prior.baudrate
            rx += counterDelta(current: sample.rx, previous: prior.rx,
                               baudrate: speed, elapsed: elapsed)
            tx += counterDelta(current: sample.tx, previous: prior.tx,
                               baudrate: speed, elapsed: elapsed)
        }
        return NetworkByteDelta(rx: rx, tx: tx)
    }

    /// Bytes this counter advanced. A decrease is a reset (0). A forward
    /// jump past the link-speed cap is treated the same way.
    static func counterDelta(current: UInt64, previous: UInt64,
                             baudrate: UInt64 = 0, elapsed: TimeInterval = 0) -> UInt64 {
        guard current >= previous else { return 0 }
        let delta = current - previous
        guard baudrate > 0, elapsed > 0 else { return delta }
        let maxBytes = Double(baudrate) / 8.0 * elapsed * baudrateMargin
        if Double(delta) > maxBytes { return 0 }
        return delta
    }
}
