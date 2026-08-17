import Foundation

/// System temperature. On Apple Silicon this reads the HID temperature
/// sensors and reports the hottest one; on Intel it falls back to common
/// SMC temperature keys.
final class TemperatureMonitor: MetricProvider {

    private let hid = HIDSensors()
    private let smc = try? SMC()

    /// SMC keys worth probing on Intel Macs (CPU/GPU die, palm rest...).
    private let smcFallbackKeys = ["TC0P", "TC0D", "TG0D", "TC0E"]

    func sample() -> String {
        if let temperature = hidTemperature() {
            return String(format: "温度: %.1f °C", temperature)
        }
        if let temperature = smcTemperature() {
            return String(format: "温度: %.1f °C", temperature)
        }
        return "温度: --"
    }

    private func hidTemperature() -> Double? {
        hid?.temperatureReadings().map(\.value).max()
    }

    private func smcTemperature() -> Double? {
        guard let smc else { return nil }
        for key in smcFallbackKeys {
            if let value = smc.temperature(key), value > 0 {
                return value
            }
        }
        return nil
    }
}
