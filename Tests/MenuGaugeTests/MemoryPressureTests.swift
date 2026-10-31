import XCTest
@testable import MenuGauge

final class MemoryPressureTests: XCTestCase {
    func testKernelValuesAndHeatMapping() {
        XCTAssertEqual(MemoryPressure.normal.rawValue, 1)
        XCTAssertEqual(MemoryPressure.warning.rawValue, 2)
        XCTAssertEqual(MemoryPressure.critical.rawValue, 4)
        XCTAssertNil(MemoryPressure.normal.heat)
        XCTAssertEqual(MemoryPressure.warning.heat, 0)
        XCTAssertEqual(MemoryPressure.critical.heat, 1)
    }

    func testUnknownKernelValueFallsBackToNormal() {
        XCTAssertEqual(MemoryPressure.from(kernelValue: 0), .normal)
        XCTAssertEqual(MemoryPressure.from(kernelValue: 3), .normal)
        XCTAssertEqual(MemoryPressure.from(kernelValue: 1), .normal)
        XCTAssertEqual(MemoryPressure.from(kernelValue: 2), .warning)
        XCTAssertEqual(MemoryPressure.from(kernelValue: 4), .critical)
    }

    func testMemoryMonitorUsesPressureForHeat() {
        XCTAssertNil(MemoryMonitor(pressure: { .normal }).sample().heat)
        XCTAssertEqual(MemoryMonitor(pressure: { .warning }).sample().heat, 0)
        XCTAssertEqual(MemoryMonitor(pressure: { .critical }).sample().heat, 1)
    }
}
