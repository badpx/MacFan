import Foundation

/// Byte counters for one `en*` interface, as reported by `if_data`.
///
/// `ifi_ibytes` and `ifi_obytes` are `u_int32_t` (`bsd/net/if_var.h`).
/// `getifaddrs` fills `struct if_data`, not `if_data64`, so each counter
/// rolls over at 4 GiB.
struct NetworkInterfaceCounters: Equatable {
    var rx: UInt32
    var tx: UInt32
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
/// subtract with `UInt64` wrapping arithmetic. That overflows in three
/// cases: an interface disappears (its whole counter leaves the sum), a
/// counter resets, and a single 32-bit counter rolls past 4 GiB. A new
/// interface had the opposite bug: its historical total was counted as
/// traffic for the current interval.
struct NetworkCounterLedger: Equatable {
    /// Largest forward distance credited when a 32-bit counter goes
    /// backwards. A docked 10 Gigabit port moves at most 1.25 GB/s, so
    /// 3 GB covers the 2s refresh plus jitter. Anything larger is a
    /// reset (the counter restarted well below the top of the range) and
    /// contributes 0 for this sample. A counter that does not go
    /// backwards is never capped.
    static let maxPlausibleWrap: UInt64 = 3_000_000_000

    private(set) var baseline: [String: NetworkInterfaceCounters] = [:]

    /// Diff `current` against the stored baselines, then replace them.
    ///
    /// Interfaces seen for the first time only establish a baseline.
    /// Interfaces missing from `current` are dropped, so a later
    /// reappearance starts over instead of inheriting a stale counter.
    mutating func advance(to current: [String: NetworkInterfaceCounters]) -> NetworkByteDelta {
        let delta = Self.delta(from: baseline, to: current)
        baseline = current
        return delta
    }

    static func delta(
        from previous: [String: NetworkInterfaceCounters],
        to current: [String: NetworkInterfaceCounters]
    ) -> NetworkByteDelta {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        for (name, sample) in current {
            guard let prior = previous[name] else { continue }
            rx += counterDelta(current: sample.rx, previous: prior.rx)
            tx += counterDelta(current: sample.tx, previous: prior.tx)
        }
        return NetworkByteDelta(rx: rx, tx: tx)
    }

    /// Bytes this counter advanced. A backwards jump within
    /// `maxPlausibleWrap` is one 32-bit rollover; a larger jump is a reset.
    static func counterDelta(current: UInt32, previous: UInt32) -> UInt64 {
        if current >= previous {
            return UInt64(current - previous)
        }
        let wrapped = UInt64(current &- previous)
        if wrapped <= maxPlausibleWrap {
            return wrapped
        }
        return 0
    }
}
