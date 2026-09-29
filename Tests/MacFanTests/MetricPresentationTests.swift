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
        XCTAssertEqual(MetricFormat.rate(nil).value, "N/A")
        XCTAssertEqual(MetricFormat.rate(nil).unit, "")
        XCTAssertEqual(MetricFormat.rate(0).value, "0")
        XCTAssertEqual(MetricFormat.rate(0).unit, "B/s")
        XCTAssertEqual(MetricFormat.rate(32_100).value, "32.1")
        XCTAssertEqual(MetricFormat.rate(32_100).unit, "KB/s")
        XCTAssertEqual(MetricFormat.rate(1_000_000).unit, "MB/s")
        XCTAssertEqual(MetricFormat.rate(1_000_000_000).unit, "GB/s")
        XCTAssertEqual(MetricFormat.rate(.infinity).value, "N/A")
    }

    func testPartialInboundFailureDoesNotHideUpload() {
        let model = PopoverModel()
        model.readings = ["network": MetricReading(menu: "", value: .network(download: nil, upload: 10_200))]
        guard case .network(let download, let upload) = model.readings["network"]?.value else {
            return XCTFail("Expected structured network reading")
        }
        XCTAssertEqual(MetricFormat.rate(download).value, "N/A")
        XCTAssertEqual(MetricFormat.rate(upload).value, "10.2")
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
