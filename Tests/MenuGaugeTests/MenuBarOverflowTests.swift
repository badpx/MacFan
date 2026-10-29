import XCTest
@testable import MenuGauge

/// State transitions for menu-bar overflow. The helper follows
/// `AppDelegate.refresh`: lay out, check visibility, then probe. A
/// relayout that changes how many widgets are drawn also changes the
/// status-item length, which sets the settle flag.
final class MenuBarOverflowTests: XCTestCase {
    private func refresh(
        _ overflow: inout MenuBarOverflow,
        selected: Int,
        visible: Bool,
        at now: Date,
        layoutChanged: Bool,
        canHideAnotherMetric: Bool = true
    ) -> (check: MenuBarOverflow.Outcome, probe: MenuBarOverflow.Outcome) {
        overflow.clampHiddenCount(to: selected)
        overflow.noteLayout(
            renderedCount: selected - overflow.hiddenWidgetCount,
            layoutChanged: layoutChanged)
        let check = overflow.checkVisibility(isVisible: visible, now: now,
                                              canHideAnotherMetric: canHideAnotherMetric)
        if check.needsRelayout {
            overflow.clampHiddenCount(to: selected)
            overflow.noteLayout(
                renderedCount: selected - overflow.hiddenWidgetCount,
                layoutChanged: true)
        }
        let probe = overflow.probeRestore(forced: false, now: now)
        if probe.needsRelayout {
            overflow.clampHiddenCount(to: selected)
            overflow.noteLayout(
                renderedCount: selected - overflow.hiddenWidgetCount,
                layoutChanged: true)
        }
        return (check, probe)
    }

    func testAllHiddenWidgetsReturnOneByOneWhenSpaceComesBack() {
        var overflow = MenuBarOverflow()
        let selected = 2
        var now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        _ = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: true)
        XCTAssertEqual(overflow.renderedWidgetCount, 2)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertFalse(overflow.skipVisibilityCheck)

        now += 2
        let hideFirst = refresh(&overflow, selected: selected, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(hideFirst.check.events, [.degraded(hiddenCount: 1)])
        XCTAssertFalse(hideFirst.probe.needsRelayout)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertEqual(overflow.renderedWidgetCount, 1)
        XCTAssertTrue(overflow.skipVisibilityCheck)

        // The settle tick must not hide another widget, and must not probe yet.
        now += 2
        let settled = refresh(&overflow, selected: selected, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(settled.check, MenuBarOverflow.Outcome.none)
        XCTAssertFalse(settled.probe.needsRelayout)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertFalse(overflow.skipVisibilityCheck)

        now += 2
        let hideLast = refresh(&overflow, selected: selected, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(hideLast.check.events, [.degraded(hiddenCount: 2)])
        XCTAssertFalse(hideLast.probe.needsRelayout)
        XCTAssertEqual(overflow.renderedWidgetCount, 0)
        XCTAssertTrue(overflow.skipVisibilityCheck)
        let hiddenAt = overflow.lastProbeAttempt

        // Icon mode still clears the settle flag. Space is not back yet,
        // and the probe clock has not elapsed, so nothing is restored.
        now += 2
        let icon = refresh(&overflow, selected: selected, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(icon.check, MenuBarOverflow.Outcome.none)
        XCTAssertFalse(icon.probe.needsRelayout)
        XCTAssertFalse(overflow.skipVisibilityCheck)
        XCTAssertEqual(overflow.hiddenWidgetCount, 2)
        XCTAssertEqual(overflow.renderedWidgetCount, 0)

        now = hiddenAt.addingTimeInterval(MenuBarOverflow.probeInterval - 1)
        let tooSoon = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        XCTAssertFalse(tooSoon.probe.needsRelayout)
        XCTAssertEqual(overflow.hiddenWidgetCount, 2)

        now = hiddenAt.addingTimeInterval(MenuBarOverflow.probeInterval)
        let firstBack = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        XCTAssertEqual(firstBack.probe.events, [.probing(stillHidden: 1)])
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertEqual(overflow.renderedWidgetCount, 1)
        XCTAssertTrue(overflow.probeInFlight)
        XCTAssertTrue(overflow.skipVisibilityCheck)

        now += 2
        let settleProbe = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        XCTAssertEqual(settleProbe.check, MenuBarOverflow.Outcome.none)
        XCTAssertFalse(settleProbe.probe.needsRelayout)
        XCTAssertTrue(overflow.probeInFlight)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertFalse(overflow.skipVisibilityCheck)

        now += 2
        let secondBack = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        XCTAssertEqual(secondBack.check.events, [
            .probeSucceeded(stillHidden: 1),
            .probing(stillHidden: 0),
        ])
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertEqual(overflow.renderedWidgetCount, 2)
        XCTAssertTrue(overflow.probeInFlight)

        now += 2
        _ = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        now += 2
        let done = refresh(&overflow, selected: selected, visible: true, at: now, layoutChanged: false)
        XCTAssertEqual(done.check.events, [.probeSucceeded(stillHidden: 0)])
        XCTAssertFalse(done.check.needsRelayout)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertEqual(overflow.renderedWidgetCount, 2)
        XCTAssertFalse(overflow.probeInFlight)
    }

    func testNonZeroDegradeSettlesAndAFailedProbeHidesTheWidgetAgain() {
        var overflow = MenuBarOverflow()
        var now = Date(timeIntervalSinceReferenceDate: 2_000_000)

        // A length change in the opening layout is consumed before the
        // visibility signal is trusted, so a crowded bar does not hide a
        // widget on the same tick it was resized.
        let opening = refresh(&overflow, selected: 2, visible: false, at: now, layoutChanged: true)
        XCTAssertEqual(opening.check, MenuBarOverflow.Outcome.none)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertFalse(overflow.skipVisibilityCheck)

        now += 2
        let degraded = refresh(&overflow, selected: 2, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(degraded.check.events, [.degraded(hiddenCount: 1)])
        XCTAssertEqual(overflow.renderedWidgetCount, 1)
        XCTAssertTrue(overflow.skipVisibilityCheck)
        let degradedAt = overflow.lastProbeAttempt

        now += 2
        let settled = refresh(&overflow, selected: 2, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(settled.check, MenuBarOverflow.Outcome.none)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertFalse(overflow.skipVisibilityCheck)

        now = degradedAt.addingTimeInterval(MenuBarOverflow.probeInterval)
        let probed = refresh(&overflow, selected: 2, visible: true, at: now, layoutChanged: false)
        XCTAssertEqual(probed.probe.events, [.probing(stillHidden: 0)])
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertEqual(overflow.renderedWidgetCount, 2)
        XCTAssertTrue(overflow.probeInFlight)
        XCTAssertTrue(overflow.skipVisibilityCheck)

        // Still settling: a "not visible" signal must not undo the probe.
        now += 2
        let settling = refresh(&overflow, selected: 2, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(settling.check, MenuBarOverflow.Outcome.none)
        XCTAssertTrue(overflow.probeInFlight)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)

        now += 2
        let rejected = refresh(&overflow, selected: 2, visible: false, at: now, layoutChanged: false)
        XCTAssertEqual(rejected.check.events, [.degraded(hiddenCount: 1)])
        XCTAssertFalse(overflow.probeInFlight)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertEqual(overflow.renderedWidgetCount, 1)
    }

    func testSelectionChangeShowsEveryWidgetAndDropsTheInFlightProbe() {
        var overflow = MenuBarOverflow()
        overflow.hiddenWidgetCount = 2
        overflow.probeInFlight = true
        overflow.skipVisibilityCheck = true
        let clock = Date(timeIntervalSinceReferenceDate: 50)
        overflow.lastProbeAttempt = clock

        overflow.resetForSelectionChange()

        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertFalse(overflow.probeInFlight)
        XCTAssertTrue(overflow.skipVisibilityCheck)
        XCTAssertEqual(overflow.lastProbeAttempt, clock)
    }

    func testCrowdedBarKeepsTheLastMetricWhenTheLogoIsOff() {
        var overflow = MenuBarOverflow()
        var now = Date(timeIntervalSinceReferenceDate: 3_000_000)
        _ = refresh(&overflow, selected: 1, visible: false, at: now,
                    layoutChanged: true, canHideAnotherMetric: false)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertEqual(overflow.renderedWidgetCount, 1)

        now += 2
        let blocked = refresh(&overflow, selected: 1, visible: false, at: now,
                              layoutChanged: false, canHideAnotherMetric: false)
        XCTAssertEqual(blocked.check, MenuBarOverflow.Outcome.none)
        XCTAssertFalse(blocked.probe.needsRelayout)
        XCTAssertEqual(overflow.hiddenWidgetCount, 0)
        XCTAssertEqual(overflow.renderedWidgetCount, 1)
    }

    func testLogoStaysUpWhenOverflowHidesTheLastMetric() {
        var overflow = MenuBarOverflow()
        var now = Date(timeIntervalSinceReferenceDate: 4_000_000)
        _ = refresh(&overflow, selected: 1, visible: true, at: now, layoutChanged: true)
        now += 2
        let hidden = refresh(&overflow, selected: 1, visible: false, at: now,
                             layoutChanged: false, canHideAnotherMetric: true)
        XCTAssertEqual(hidden.check.events, [.degraded(hiddenCount: 1)])
        XCTAssertEqual(overflow.renderedWidgetCount, 0)
        XCTAssertTrue(overflow.skipVisibilityCheck)

        now += 2
        let icon = refresh(&overflow, selected: 1, visible: true, at: now, layoutChanged: false)
        XCTAssertFalse(overflow.skipVisibilityCheck)
        XCTAssertEqual(overflow.hiddenWidgetCount, 1)
        XCTAssertEqual(icon.probe.needsRelayout, false)
        XCTAssertTrue(MenuBarDisplay.showsLogo(logoSelected: true, renderedMetricCount: 0))
        XCTAssertTrue(MenuBarDisplay.canHideAnotherMetric(logoSelected: true, visibleMetricCount: 1))
        XCTAssertFalse(MenuBarDisplay.canHideAnotherMetric(logoSelected: false, visibleMetricCount: 1))
    }
}
