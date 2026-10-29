import Foundation

/// Hide / restore decisions for menu-bar widgets that no longer fit.
///
/// AppKit stays in `AppDelegate`: it reports whether the status item is
/// actually on screen and whether a layout changed the item's length.
/// This type only tracks the flags those checks depend on, so the
/// transitions can be tested without a menu bar.
struct MenuBarOverflow: Equatable {
    /// Selected widgets suppressed from the right end. 0 = everything shown.
    var hiddenWidgetCount = 0
    /// Widgets drawn by the last layout. 0 = the gauge icon.
    var renderedWidgetCount = 0
    /// The tick after a resize must not trust the status-item position.
    /// WindowServer takes about one refresh to settle.
    var skipVisibilityCheck = false
    /// A restore probe (one widget added back) is waiting to be checked.
    var probeInFlight = false
    /// Last time a probe started or a widget was hidden. Unforced probes
    /// are paced to one per `probeInterval`.
    var lastProbeAttempt = Date.distantPast

    static let probeInterval: TimeInterval = 30

    enum Event: Equatable {
        /// The in-flight probe was still on screen. `stillHidden` is the
        /// count before any follow-up probe.
        case probeSucceeded(stillHidden: Int)
        /// One more widget was suppressed.
        case degraded(hiddenCount: Int)
        /// One suppressed widget was put back. The next settled visibility
        /// check confirms it.
        case probing(stillHidden: Int)
    }

    struct Outcome: Equatable {
        var events: [Event] = []
        var needsRelayout: Bool = false

        static let none = Outcome()
    }

    /// `selectedCount` is how many widgets have a reading this pass.
    mutating func clampHiddenCount(to selectedCount: Int) {
        hiddenWidgetCount = min(hiddenWidgetCount, max(0, selectedCount))
    }

    /// Record the layout just applied. `layoutChanged` is true when the
    /// status-item length or widget frame changed, which is the signal
    /// that the next visibility sample is still stale.
    mutating func noteLayout(renderedCount: Int, layoutChanged: Bool) {
        renderedWidgetCount = renderedCount
        if layoutChanged {
            skipVisibilityCheck = true
        }
    }

    /// The user edited the metric selection. Show everything again and
    /// drop an in-flight probe. The settle flag and the probe clock stay
    /// as they are; the layout that follows records a new length.
    mutating func resetForSelectionChange() {
        hiddenWidgetCount = 0
        probeInFlight = false
    }

    /// Per-tick overflow handling, after `noteLayout`.
    ///
    /// Icon mode (no metric drawn; the logo may still be up) still has to
    /// clear the settle flag. The length change that hid the last metric
    /// sets it, and the non-zero branch below is otherwise the only place
    /// that clears it. Leaving it set blocks `probeRestore` forever.
    ///
    /// `canHideAnotherMetric` is false when hiding one more would empty
    /// the status item: the logo is off and only one metric is left.
    /// When the logo is on, the last metric may still be hidden.
    mutating func checkVisibility(isVisible: Bool, now: Date, canHideAnotherMetric: Bool = true) -> Outcome {
        guard renderedWidgetCount > 0 else {
            skipVisibilityCheck = false
            return Outcome.none
        }
        if skipVisibilityCheck {
            skipVisibilityCheck = false
            return Outcome.none
        }
        if isVisible {
            guard probeInFlight else { return Outcome.none }
            probeInFlight = false
            let stillHidden = hiddenWidgetCount
            var outcome = probeRestore(forced: true, now: now)
            outcome.events.insert(.probeSucceeded(stillHidden: stillHidden), at: 0)
            return outcome
        }
        guard canHideAnotherMetric else {
            probeInFlight = false
            return Outcome.none
        }
        probeInFlight = false
        hiddenWidgetCount += 1
        lastProbeAttempt = now
        return Outcome(events: [.degraded(hiddenCount: hiddenWidgetCount)], needsRelayout: true)
    }

    /// Reveal one suppressed widget. Fails safe: if the space is still
    /// gone, the next visibility check hides it again. A probe that just
    /// succeeded passes `forced` so the next widget is tried immediately
    /// instead of waiting out `probeInterval`.
    mutating func probeRestore(forced: Bool, now: Date) -> Outcome {
        guard hiddenWidgetCount > 0, !probeInFlight, !skipVisibilityCheck else { return Outcome.none }
        guard forced || now.timeIntervalSince(lastProbeAttempt) >= Self.probeInterval else {
            return Outcome.none
        }
        lastProbeAttempt = now
        hiddenWidgetCount -= 1
        probeInFlight = true
        return Outcome(events: [.probing(stillHidden: hiddenWidgetCount)], needsRelayout: true)
    }
}
