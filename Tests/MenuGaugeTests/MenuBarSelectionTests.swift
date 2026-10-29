import XCTest
@testable import MenuGauge

final class MenuBarSelectionTests: XCTestCase {
    private let metrics: Set<String> = [MetricCatalog.logoID, "cpu", "memory", "network"]

    func testFreshInstallAndEmptySaveBothShowTheLogoOnly() {
        XCTAssertEqual(MenuBarSelection.resolved(stored: nil, appStore: false), [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.resolved(stored: nil, appStore: true), [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.resolved(stored: [], appStore: false), [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.resolved(stored: [], appStore: true), [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.persisted([]), [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.persisted(["cpu"]), ["cpu"])
    }

    func testUpgradeKeepsAMetricsOnlySelection() {
        XCTAssertEqual(MenuBarSelection.resolved(stored: ["cpu", "memory"], appStore: false),
                       ["cpu", "memory"])
        XCTAssertEqual(MenuBarSelection.resolved(stored: ["network"], appStore: true), ["network"])
        XCTAssertFalse(MenuBarSelection.resolved(stored: ["cpu"], appStore: false).contains(MetricCatalog.logoID))
    }

    func testStoredLogoIsKeptAndAFanOnlyAppStoreSaveMigrates() {
        XCTAssertEqual(MenuBarSelection.resolved(stored: ["logo", "cpu"], appStore: false), ["logo", "cpu"])
        XCTAssertEqual(MenuBarSelection.resolved(stored: ["cpu", "logo", "logo"], appStore: true),
                       ["cpu", "logo"])
        XCTAssertEqual(MenuBarSelection.resolved(stored: [MetricCatalog.fanID], appStore: true),
                       [MetricCatalog.logoID])
        XCTAssertEqual(MenuBarSelection.resolved(stored: ["cpu", MetricCatalog.fanID], appStore: true),
                       ["cpu"])
        XCTAssertEqual(MenuBarSelection.resolved(stored: [MetricCatalog.logoID, MetricCatalog.fanID], appStore: true),
                       [MetricCatalog.logoID])
    }

    func testLastEnabledItemCannotBeTurnedOff() {
        let onlyCPU = MenuBarSelection.toggle("cpu", enabled: false, in: ["cpu"], knownIDs: metrics)
        XCTAssertTrue(onlyCPU.rejectedLastItem)
        XCTAssertEqual(onlyCPU.selection, ["cpu"])

        let onlyLogo = MenuBarSelection.toggle(MetricCatalog.logoID, enabled: false,
                                                in: [MetricCatalog.logoID], knownIDs: metrics)
        XCTAssertTrue(onlyLogo.rejectedLastItem)
        XCTAssertEqual(onlyLogo.selection, [MetricCatalog.logoID])

        let dropCPU = MenuBarSelection.toggle("cpu", enabled: false, in: ["cpu", "logo"], knownIDs: metrics)
        XCTAssertFalse(dropCPU.rejectedLastItem)
        XCTAssertEqual(dropCPU.selection, ["logo"])

        let dropLogo = MenuBarSelection.toggle("logo", enabled: false, in: ["logo", "memory"], knownIDs: metrics)
        XCTAssertFalse(dropLogo.rejectedLastItem)
        XCTAssertEqual(dropLogo.selection, ["memory"])

        let add = MenuBarSelection.toggle("network", enabled: true, in: ["logo"], knownIDs: metrics)
        XCTAssertFalse(add.rejectedLastItem)
        XCTAssertEqual(add.selection, ["logo", "network"])

        let unknown = MenuBarSelection.toggle("fan", enabled: false, in: ["cpu"], knownIDs: metrics)
        XCTAssertFalse(unknown.rejectedLastItem)
        XCTAssertEqual(unknown.selection, ["cpu"])
    }

    func testMinimumHintClearsWhenASecondItemIsOnOrAfterTheTimeout() {
        var hint = MinimumSelectionHint()
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        hint.noteRejected(at: start)
        XCTAssertTrue(hint.visible)

        hint.noteSelectionCount(1, at: start.addingTimeInterval(1))
        XCTAssertTrue(hint.visible)

        var opened = hint
        opened.noteSelectionCount(2, at: start.addingTimeInterval(1))
        XCTAssertFalse(opened.visible)

        hint.noteSelectionCount(1, at: start.addingTimeInterval(MenuBarSelection.minimumHintDuration))
        XCTAssertFalse(hint.visible)
        XCTAssertEqual(MenuBarSelection.minimumHintDuration, 4)
    }

    func testLogoIsFirstInBothEditionsAndMetricsHideBeforeIt() {
        let store = MetricCatalog.offeredDescriptors(appStore: true).map(\.id)
        let direct = MetricCatalog.offeredDescriptors(appStore: false).map(\.id)
        XCTAssertEqual(store.first, MetricCatalog.logoID)
        XCTAssertEqual(direct.first, MetricCatalog.logoID)
        XCTAssertEqual(store.dropFirst().first, "cpu")
        XCTAssertFalse(store.contains(MetricCatalog.fanID))
        XCTAssertTrue(direct.contains(MetricCatalog.fanID))

        XCTAssertTrue(MenuBarDisplay.canHideAnotherMetric(logoSelected: true, visibleMetricCount: 1))
        XCTAssertFalse(MenuBarDisplay.canHideAnotherMetric(logoSelected: false, visibleMetricCount: 1))
        XCTAssertTrue(MenuBarDisplay.canHideAnotherMetric(logoSelected: false, visibleMetricCount: 2))
        XCTAssertFalse(MenuBarDisplay.canHideAnotherMetric(logoSelected: true, visibleMetricCount: 0))
    }

    func testSettingsFocusRingWaitsForTab() {
        var focus = SettingsFocusDecider()
        XCTAssertEqual(focus.decide(requestedView: true, userClickInside: false), .windowItself)
        XCTAssertEqual(focus.decide(requestedView: false, userClickInside: false), .windowItself)
        XCTAssertEqual(focus.decide(requestedView: true, userClickInside: true), .control(showRing: false))

        focus.noteTab()
        XCTAssertEqual(focus.decide(requestedView: true, userClickInside: false), .control(showRing: true))

        focus.disarm()
        XCTAssertEqual(focus.decide(requestedView: true, userClickInside: false), .windowItself)
    }
}
