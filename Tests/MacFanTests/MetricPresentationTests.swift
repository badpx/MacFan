import XCTest
import AppKit
@testable import MacFan

final class MetricPresentationTests: XCTestCase {
    func testAverageIncludesStoppedFansAndRequiresEverySensor() {
        XCTAssertEqual(FanMonitor.average([1800, 2200]), 2000)
        XCTAssertEqual(FanMonitor.average([0, 2000]), 1000)
        XCTAssertEqual(FanMonitor.average([0, 0]), 0)
        XCTAssertEqual(FanMonitor.average([1750]), 1750)
        XCTAssertNil(FanMonitor.average([1800, nil]))
        XCTAssertNil(FanMonitor.average([]))
        XCTAssertNil(FanMonitor.average([.nan, 2000]))
        XCTAssertNil(FanMonitor.average([-1, 2000]))
    }

    func testUnavailableAndZeroNetworkRatesRemainDistinct() {
        XCTAssertEqual(MetricFormat.rate(nil).value, "—")
        XCTAssertEqual(MetricFormat.rate(0).value, "0")
        XCTAssertEqual(MetricFormat.rate(0).unit, "B/s")
        XCTAssertEqual(MetricFormat.rate(32_100).value, "32.1")
        XCTAssertEqual(MetricFormat.rate(32_100).unit, "KB/s")
        XCTAssertEqual(MetricFormat.rate(1_000_000).unit, "MB/s")
        XCTAssertEqual(MetricFormat.rate(1_000_000_000).unit, "GB/s")
        XCTAssertEqual(MetricFormat.rate(.infinity).value, "—")
    }

    func testPartialInboundFailureDoesNotHideUpload() {
        let model = PopoverModel()
        model.readings = ["network": MetricReading(menu: "", value: .network(download: nil, upload: 10_200))]
        XCTAssertTrue(model.hasUnavailableReadings)
        guard case .network(let download, let upload) = model.readings["network"]?.value else {
            return XCTFail("Expected structured network reading")
        }
        XCTAssertNil(download)
        XCTAssertEqual(MetricFormat.rate(upload).value, "10.2")
        model.readings = ["network": MetricReading(menu: "", value: .network(download: 0, upload: 0))]
        XCTAssertFalse(model.hasUnavailableReadings)
    }

    func testStoppedVersusUnavailableFanDescription() {
        let model = PopoverModel()
        model.readings["fan"] = MetricReading(menu: "", value: .fan(0))
        XCTAssertTrue(model.note(for: "fan").contains(L10n.ui(.stopped)))
        model.readings["fan"] = MetricReading(menu: "")
        XCTAssertEqual(model.note(for: "fan"), L10n.ui(.averageUnavailable))
    }

    func testHeatIsContinuousAndClamped() {
        func rgba(_ h: Double) -> [CGFloat] {
            let color = MetricFormat.heatColor(h).usingColorSpace(.sRGB)!
            return [color.redComponent, color.greenComponent, color.blueComponent]
        }
        XCTAssertNotEqual(rgba(0), rgba(0.25))
        XCTAssertNotEqual(rgba(0.25), rgba(0.5))
        XCTAssertNotEqual(rgba(0.5), rgba(1))
        XCTAssertEqual(rgba(-1), rgba(0))
        XCTAssertEqual(rgba(2), rgba(1))
    }
}
