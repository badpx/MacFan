import Foundation

/// Fan speed(s) via SMC. Machines without fans (e.g. MacBook Air)
/// report "N/A".
final class FanMonitor: MetricProvider {

    private let smc = try? SMC()

    func sample() -> String {
        guard let smc else { return "风扇: N/A" }

        let count = smc.fanCount()
        guard count > 0 else { return "风扇: N/A" }

        let rpms = (0..<count).compactMap { smc.fanRPM($0) }
        guard !rpms.isEmpty else { return "风扇: N/A" }

        if rpms.count == 1 {
            return String(format: "风扇: %.0f RPM", rpms[0])
        }
        let all = rpms.map { String(format: "%.0f", $0) }.joined(separator: " / ")
        return "风扇: \(all) RPM"
    }
}
