import Foundation

/// Fan speed(s) via SMC. Machines without fans (e.g. MacBook Air)
/// report "N/A".
final class FanMonitor: MetricProvider {

    let id = "fan"

    private let smc = try? SMC()

    func sample() -> MetricReading {
        let fanLabel = L10n.tr(.fan)
        guard let smc else { return MetricReading(menu: "\(fanLabel): N/A") }

        let count = smc.fanCount()
        guard count > 0 else { return MetricReading(menu: "\(fanLabel): N/A") }

        guard let rpm = Self.average((0..<count).map { smc.fanRPM($0) }) else {
            return MetricReading(menu: "\(fanLabel): N/A")
        }
        return MetricReading(menu: String(format: "%@: %.0f RPM", fanLabel, rpm),
                             compact: CompactReading(top: String(format: "%.0f", rpm),
                                                     bottom: "RPM",
                                                     topWidthTemplate: "9999"),
                             value: .fan(rpm))
    }

    /// Zero is a valid stopped fan. A missing sensor must not silently turn
    /// a two-fan average into a single-fan reading.
    static func average(_ readings: [Double?]) -> Double? {
        guard !readings.isEmpty else { return nil }
        let values = readings.compactMap { $0 }
        guard values.count == readings.count,
              values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
