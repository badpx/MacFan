import Foundation
import Darwin

/// CPU temperature using Lemon's model-specific SMC sensor selection.
/// Apple Silicon reports the mean of valid readings; Intel probes CPU keys
/// in priority order. Unrelated HID/PMU readings must not stand in for CPU data.
final class TemperatureMonitor: MetricProvider {

    let id = "temperature"

    private let smc = try? SMC()
    private let chipName = TemperatureMonitor.systemChipName()

    func sample() -> MetricReading {
        guard let temperature = Self.cpuTemperature(chipName: chipName, read: { smc?.temperature($0) }) else {
            return MetricReading(menu: "\(L10n.tr(.temperature)): --")
        }
        // Warn from 75 °C (light orange) ramping to red at 85 °C.
        let heat: Double? = temperature >= 75
            ? min((temperature - 75) / 10, 1) : nil
        return MetricReading(menu: String(format: "%@: %.1f °C", L10n.tr(.temperature), temperature),
                             compact: CompactReading(top: String(format: "%.0f°", temperature),
                                                     bottom: "TEMP",
                                                     topWidthTemplate: "100°"),
                             heat: heat, value: .temperature(temperature))
    }

    /// Same strict bounds as Lemon: missing, non-finite, <=20 and >=110
    /// readings are excluded, and missing sensors do not count in the divisor.
    static func average(_ readings: [Double?]) -> Double? {
        let valid = readings.compactMap { $0 }.filter { $0.isFinite && $0 > 20 && $0 < 110 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }

    static func cpuTemperature(chipName: String?, read: (String) -> Double?) -> Double? {
        guard let chipName else { return nil }
        if chipName.hasPrefix("Apple ") {
            return average(appleSiliconKeys(chipName: chipName).map(read))
        }
        // Match Lemon's legacy Intel priority and validity range.
        for key in ["TC0P", "TC0D", "TC0H", "TC0E", "TC0F", "TCAD"] {
            if let value = read(key), value.isFinite, value > 0, value <= 110 {
                return value
            }
        }
        return nil
    }

    /// Sensor keys and aggregation policy verified against Lemon 5.3.7:
    /// https://github.com/Tencent/lemon-cleaner/blob/master/Tools/LemonDaemon/LemonDaemon/Monitor/SMC/CmcTemperature.m
    /// M1 Pro/Max/Ultra, M2 and M3 lists include GPU sensors for parity with Lemon.
    /// Unknown generations deliberately return unavailable rather than a PMU temperature.
    static func appleSiliconKeys(chipName: String) -> [String] {
        let components = chipName.split(separator: " ")
        guard components.count >= 2, components[0] == "Apple" else { return [] }
        switch components[1] {
        case "M1":
            if components.count == 2 {
                return ["Tc0a", "Tc0b", "Tc0x", "Tc0z", "Tc7a", "Tc7b", "Tc7x", "Tc7z",
                        "Tc8a", "Tc8b", "Tc9a", "Tc9b", "Tc9x", "Tc9z"]
            }
            return ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P",
                    "Tp0X", "Tp0b", "Tg05", "Tg0D", "Tg0L", "Tg0T"]
        case "M2":
            return ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D",
                    "Tp0X", "Tp0b", "Tp0f", "Tp0j", "Tg0f", "Tg0j"]
        case "M3":
            return ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B",
                    "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E",
                    "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"]
        case "M4":
            return ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D",
                    "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        case "M5":
            return ["Te04", "Te08", "Te0C", "Te0R", "Tp00", "Tp04", "Tp0C", "Tp0G",
                    "Tp0O", "Tp0R", "Tp0X", "Tp0a", "Tp0p", "Tp0u", "Tp0y"]
        default:
            return []
        }
    }

    private static func systemChipName() -> String? {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
