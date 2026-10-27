import XCTest
@testable import MenuGauge

final class StatusGaugeTests: XCTestCase {
    func testNeedleStepQuantizesCPUPercentIntoTwentyFourStops() {
        XCTAssertEqual(StatusGauge.needleSteps, 24)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 0), 0)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 100), 23)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 50), 12)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: -20), 0)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 140), 23)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: .nan), 0)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: .infinity), 0)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 1), 0)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 96), 22)
        XCTAssertEqual(StatusGauge.needleStep(cpuPercent: 99), 23)
    }

    func testNeedleTravelsFromTheLeftEndOfTheArcToTheRight() {
        XCTAssertEqual(StatusGauge.needleDegrees(step: 0), 190, accuracy: 0.001)
        XCTAssertEqual(StatusGauge.needleDegrees(step: 23), -10, accuracy: 0.001)
        XCTAssertEqual(StatusGauge.needleDegrees(step: 99), -10, accuracy: 0.001)
    }

    func testThermalStateLightsOneSegmentPerLevel() {
        XCTAssertEqual(StatusGauge.segmentCount(for: ThermalLevel.nominal), 1)
        XCTAssertEqual(StatusGauge.segmentCount(for: ThermalLevel.fair), 2)
        XCTAssertEqual(StatusGauge.segmentCount(for: ThermalLevel.serious), 3)
        XCTAssertEqual(StatusGauge.segmentCount(for: ThermalLevel.critical), 4)

        XCTAssertEqual(StatusGauge.segmentCount(for: ProcessInfo.ThermalState.nominal), 1)
        XCTAssertEqual(StatusGauge.segmentCount(for: ProcessInfo.ThermalState.fair), 2)
        XCTAssertEqual(StatusGauge.segmentCount(for: ProcessInfo.ThermalState.serious), 3)
        XCTAssertEqual(StatusGauge.segmentCount(for: ProcessInfo.ThermalState.critical), 4)
    }

    func testArcIsSplitIntoFourSpans() {
        let spans = StatusGauge.segmentSpans()
        XCTAssertEqual(spans.count, 4)
        XCTAssertEqual(spans[0].start, 190, accuracy: 0.001)
        XCTAssertEqual(spans[3].end, -10, accuracy: 0.001)
        for span in spans {
            XCTAssertGreaterThan(span.start, span.end)
        }
    }
}
