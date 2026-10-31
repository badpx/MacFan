import Foundation
#if !MAS
import Darwin
#endif

/// Display unit for temperature readings. SMC samples are Celsius and get
/// converted at presentation time. The App Store edition has no degree
/// data, so Settings hides this there.
enum TemperatureUnit: String {
    case celsius, fahrenheit

    static let defaultsKey = "temperatureUnit"

    static var current: TemperatureUnit {
        TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .celsius
    }

    var symbol: String { self == .celsius ? "°C" : "°F" }

    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }
}

/// CPU temperature using Lemon's model-specific SMC sensor selection.
/// Apple Silicon reports the mean of valid readings; Intel probes CPU keys
/// in priority order. Unrelated HID/PMU readings must not stand in for CPU data.
/// The Mac App Store edition (`-DMAS`) has no SMC client and reports
/// thermald's thermal pressure instead of a degree value.
///
/// Text color follows thermald's pressure in both editions. The direct
/// edition still shows SMC degrees; the App Store edition replaces the
/// degree value with the pressure state.
final class TemperatureMonitor: MetricProvider {

    let id = "temperature"

    private let pressure: () -> ThermalPressure

    init(pressure: @escaping () -> ThermalPressure = { ThermalPressure.current }) {
        self.pressure = pressure
    }

    #if !MAS
    private let smc = try? SMC()
    private let chipName = TemperatureMonitor.systemChipName()
    #endif

    func sample() -> MetricReading {
        #if MAS
        return Self.thermalReading(pressure: pressure())
        #else
        guard let temperature = Self.cpuTemperature(chipName: chipName, read: { smc?.temperature($0) }) else {
            return MetricReading(menu: "\(L10n.tr(.temperature)): --")
        }
        return Self.degreeReading(temperature: temperature, pressure: pressure())
        #endif
    }

    /// Direct edition's degree reading. The color comes from pressure, not
    /// from the degree value; a hot CPU at nominal pressure stays normal,
    /// and a cool CPU under trapping pressure is already red.
    static func degreeReading(temperature: Double, pressure: ThermalPressure) -> MetricReading {
        let unit = TemperatureUnit.current
        let shown = unit.convert(temperature)
        // The unit letter rides in the menu bar so a switched unit is
        // visible; no degree sign, keeping the widget one character narrower
        // and the same width as the other 4-glyph metrics.
        let unitLetter = unit == .celsius ? "C" : "F"
        return MetricReading(menu: String(format: "%@: %.1f %@", L10n.tr(.temperature), shown, unit.symbol),
                             compact: CompactReading(top: String(format: "%.0f%@", shown, unitLetter),
                                                     bottom: "TEMP",
                                                     topWidthTemplate: "100C"),
                             heat: pressure.heat, value: .temperature(temperature))
    }

    /// App Store stand-in for °C. The direct edition does not use this in
    /// `sample()`; tests lock the wording and the heat ramp.
    static func thermalReading(pressure: ThermalPressure) -> MetricReading {
        MetricReading(menu: "\(L10n.tr(.temperature)): \(L10n.tr(pressure.labelKey))",
                      compact: CompactReading(top: pressure.compactToken,
                                              bottom: "TEMP",
                                              topWidthTemplate: "MAX"),
                      heat: pressure.heat,
                      value: .thermal(pressure))
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

    #if !MAS
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
    #endif
}
