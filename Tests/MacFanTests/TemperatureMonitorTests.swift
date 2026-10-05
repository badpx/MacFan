import XCTest
@testable import MacFan

final class TemperatureMonitorTests: XCTestCase {
    func testAverageFiltersInvalidReadingsAndUsesOnlyValidCount() {
        XCTAssertEqual(TemperatureMonitor.average([40, 60, nil, 0, -5, 20, 110, 120,
                                                  .nan, .infinity, -.infinity]), 50)
        XCTAssertEqual(TemperatureMonitor.average([20.1, 109.9]), 65)
        XCTAssertNil(TemperatureMonitor.average([]))
        XCTAssertNil(TemperatureMonitor.average([nil, 20, 110, .nan]))
    }

    func testM4UsesCPUSMCMeanRatherThanUnrelatedMaximum() {
        let readings: [String: Double] = [
            "Te05": 40, "Tp01": 50, "Tp0b": 60,
            "Te09": 110, "Tp05": 20,
            "TC0P": 85, "TG0D": 90,
        ]
        var requested: [String] = []
        let value = TemperatureMonitor.cpuTemperature(chipName: "Apple M4") { key in
            requested.append(key)
            return readings[key]
        }
        XCTAssertEqual(value, 50)
        XCTAssertEqual(requested.count, 12)
        XCTAssertFalse(requested.contains("TC0P"))
        XCTAssertFalse(requested.contains("TG0D"))
    }

    func testUnavailableCPUDataDoesNotFallBackToOtherSensors() {
        XCTAssertNil(TemperatureMonitor.cpuTemperature(chipName: "Apple M4") { _ in nil })
        for name: String? in ["Apple M6", "Apple M10", nil] {
            XCTAssertNil(TemperatureMonitor.cpuTemperature(chipName: name) { _ in
                XCTFail("Unknown chips must not probe unrelated sensors")
                return 51.82
            })
        }
    }

    func testM1BaseAndVariantsUseDifferentSensorFamilies() {
        XCTAssertEqual(TemperatureMonitor.cpuTemperature(chipName: "Apple M1") {
            ["Tc0a": 40.0, "Tc0b": 60.0, "Tp01": 90.0][$0]
        }, 50)
        for chip in ["Apple M1 Pro", "Apple M1 Max", "Apple M1 Ultra"] {
            XCTAssertEqual(TemperatureMonitor.cpuTemperature(chipName: chip) {
                ["Tc0a": 90.0, "Tp01": 40.0, "Tg05": 60.0][$0]
            }, 50)
        }
    }

    func testIntelKeepsCPUPriorityAndSkipsInvalidValues() {
        XCTAssertEqual(TemperatureMonitor.cpuTemperature(chipName: "Intel(R) Core(TM) i7") {
            ["TC0P": .nan, "TC0D": 120.0, "TC0H": 55.0, "TC0E": 60.0, "TG0D": 90.0][$0]
        }, 55)
        XCTAssertNil(TemperatureMonitor.cpuTemperature(chipName: "Intel(R) Core(TM) i7") { _ in 0 })
    }
}
