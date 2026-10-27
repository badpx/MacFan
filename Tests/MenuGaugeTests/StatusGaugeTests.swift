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

    func testRoundCapsStillLeaveAVisibleGap() {
        let spans = StatusGauge.segmentSpans()
        let gap = Double(spans[0].end - spans[1].start)
        let clear = StatusGauge.menuCenterlineRadius * gap * .pi / 180 - StatusGauge.menuBand
        XCTAssertEqual(clear, StatusGauge.menuClearGap, accuracy: 0.05)
        XCTAssertGreaterThan(gap, 8)
    }

    func testGaugeIsHiddenWhileAnyMetricIsDrawn() {
        XCTAssertTrue(StatusGauge.showsGauge(renderedMetricCount: 0))
        XCTAssertFalse(StatusGauge.showsGauge(renderedMetricCount: 1))
        XCTAssertFalse(StatusGauge.showsGauge(renderedMetricCount: 4))
        XCTAssertTrue(StatusGauge.showsGauge(renderedMetricCount: -1))
    }

    func testMenuBarImageIsATemplateFillingTheStatusSlot() {
        let image = StatusGaugeImage.image(for: .init(segments: 2, step: 12, dimmed: false))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size.width, 20, accuracy: 0.01)
        XCTAssertEqual(image.size.height, 16, accuracy: 0.01)
        XCTAssertEqual(StatusGaugeImage.bandStroke, 2.4, accuracy: 0.01)
        XCTAssertEqual(StatusGaugeImage.needleWidth, 1.8, accuracy: 0.01)
        XCTAssertEqual(StatusGaugeImage.hubRadius * 2, 2.5, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(StatusGaugeImage.emptyAlpha, 0.35)
        XCTAssertLessThanOrEqual(StatusGaugeImage.emptyAlpha, 0.40)

        let span = 2 * StatusGauge.menuOuterRadius
        XCTAssertGreaterThan(span, 18)
        XCTAssertLessThan(span, 20)

        let hub = StatusGaugeImage.hubOrigin(in: image.size)
        let dip = (StatusGaugeImage.outerRadius - StatusGaugeImage.bandStroke / 2) * sin(10 * .pi / 180)
            + StatusGaugeImage.bandStroke / 2
        let top = hub.y + StatusGaugeImage.outerRadius
        let bottom = hub.y - dip
        XCTAssertGreaterThanOrEqual(bottom, 0)
        XCTAssertLessThanOrEqual(top, image.size.height)
        XCTAssertEqual((top + bottom) / 2, image.size.height / 2, accuracy: 0.05)
        XCTAssertEqual(hub.x, image.size.width / 2, accuracy: 0.01)
    }
}
