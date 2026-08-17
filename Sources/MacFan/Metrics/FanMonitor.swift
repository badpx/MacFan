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

        let rpms = (0..<count).compactMap { smc.fanRPM($0) }
        guard !rpms.isEmpty else { return MetricReading(menu: "\(fanLabel): N/A") }

        // Menu lists every fan ("风扇: fan1 1359 | fan2 1456"); the menu
        // bar shows a single number — the fastest fan.
        let menu: String
        if rpms.count == 1 {
            menu = String(format: "%@: %.0f RPM", fanLabel, rpms[0])
        } else {
            let fans = rpms.enumerated()
                .map { String(format: "fan%d %.0f", $0.offset + 1, $0.element) }
                .joined(separator: " | ")
            menu = "\(fanLabel): \(fans)"
        }
        let rpm = rpms.max() ?? 0
        return MetricReading(menu: menu,
                             compact: CompactReading(top: String(format: "%.0f", rpm),
                                                     bottom: "RPM"))
    }
}
