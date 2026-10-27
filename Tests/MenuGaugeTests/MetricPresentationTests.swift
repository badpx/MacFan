import XCTest
import AppKit
@testable import MenuGauge

final class MetricPresentationTests: XCTestCase {
    #if !MAS
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
    #endif

    func testAppStoreEditionOmitsTheFanMetric() {
        let store = MetricCatalog.makeProviders(appStore: true).map(\.id)
        XCTAssertEqual(store, ["cpu", "gpu", "memory", "disk", "temperature", "network"])
        XCTAssertFalse(store.contains(MetricCatalog.fanID))
        XCTAssertFalse(MetricCatalog.offeredDescriptors(appStore: true).contains { $0.id == MetricCatalog.fanID })

        #if !MAS
        let direct = MetricCatalog.makeProviders(appStore: false).map(\.id)
        XCTAssertEqual(direct, ["cpu", "gpu", "memory", "disk", "temperature", "fan", "network"])
        XCTAssertTrue(MetricCatalog.offeredDescriptors(appStore: false).contains { $0.id == MetricCatalog.fanID })
        #endif
    }

    func testAppStoreSelectionDropsASavedFanMetric() {
        let saved = ["cpu", "fan", "memory", "fan"]
        XCTAssertEqual(MetricCatalog.sanitizedSelection(saved, appStore: true), ["cpu", "memory"])
        XCTAssertEqual(MetricCatalog.sanitizedSelection(saved, appStore: false), saved)
        XCTAssertEqual(MetricCatalog.sanitizedSelection([], appStore: true), [])
        XCTAssertEqual(MetricCatalog.sanitizedSelection(["network"], appStore: true), ["network"])
    }

    func testChineseThermalLabelsDistinguishWarmFromHot() {
        XCTAssertEqual(L10n.string(.thermalNominal, language: "zh-Hans"), "正常")
        XCTAssertEqual(L10n.string(.thermalFair, language: "zh-Hans"), "偏高")
        XCTAssertEqual(L10n.string(.thermalSerious, language: "zh-Hans"), "过热")
        XCTAssertEqual(L10n.string(.thermalCritical, language: "zh-Hans"), "危急")
        XCTAssertEqual(L10n.string(.thermalNominal, language: "zh-Hant"), "正常")
        XCTAssertEqual(L10n.string(.thermalFair, language: "zh-Hant"), "偏高")
        XCTAssertEqual(L10n.string(.thermalSerious, language: "zh-Hant"), "過熱")
        XCTAssertEqual(L10n.string(.thermalCritical, language: "zh-Hant"), "危急")
        XCTAssertEqual(L10n.string(.thermalFair, language: "en"), "Fair")
        XCTAssertEqual(L10n.string(.thermalSerious, language: "en"), "Serious")
        XCTAssertEqual(ThermalLevel.nominal.compactToken, "OK")
        XCTAssertEqual(ThermalLevel.fair.compactToken, "WARM")
        XCTAssertEqual(ThermalLevel.serious.compactToken, "HOT")
        XCTAssertEqual(ThermalLevel.critical.compactToken, "MAX")
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
