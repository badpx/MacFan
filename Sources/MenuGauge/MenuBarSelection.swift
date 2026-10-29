import AppKit
import Foundation

/// What the menu bar is allowed to show, and how a saved selection is read.
///
/// The logo and the metrics share one persisted list (`menuBarMetrics`).
/// The logo id is not a sampled metric: it is drawn to the left of them.
enum MenuBarSelection {
    /// How long the "select at least one" caption stays up when the user
    /// is already down to a single item and tries to turn that off.
    /// Turning a second item on hides it immediately.
    static let minimumHintDuration: TimeInterval = 4

    /// `stored` is nil when the key has never been written.
    ///
    /// A fresh install has no metrics selected (that is still the default)
    /// and the logo on, which is the gauge the first launch already showed.
    /// An empty array is the previous "gauge only" save and migrates to the
    /// logo. A non-empty list without the logo is left alone, so an upgrade
    /// that was showing metrics does not gain an icon. The result is never empty.
    static func resolved(stored: [String]?, appStore: Bool) -> [String] {
        let cleaned = MetricCatalog.sanitizedSelection(stored ?? [], appStore: appStore)
        let metrics = cleaned.filter { $0 != MetricCatalog.logoID }
        let logoOn = cleaned.contains(MetricCatalog.logoID)
        if stored == nil || (metrics.isEmpty && !logoOn) {
            return [MetricCatalog.logoID]
        }
        var seenLogo = false
        return cleaned.filter { id in
            guard id == MetricCatalog.logoID else { return true }
            if seenLogo { return false }
            seenLogo = true
            return true
        }
    }

    /// Never write an empty selection. Callers that reject the last toggle
    /// should not reach this; it is the backstop.
    static func persisted(_ selection: [String]) -> [String] {
        selection.isEmpty ? [MetricCatalog.logoID] : selection
    }

    struct Toggle: Equatable {
        var selection: [String]
        /// The user tried to turn off the only remaining item. `selection`
        /// is unchanged.
        var rejectedLastItem: Bool
    }

    /// `knownIDs` is the logo plus the metrics this edition can show.
    /// Anything else is ignored.
    static func toggle(_ id: String, enabled: Bool, in selection: [String], knownIDs: Set<String>) -> Toggle {
        guard knownIDs.contains(id) else {
            return Toggle(selection: selection, rejectedLastItem: false)
        }
        var next = selection.filter { $0 != id }
        if enabled {
            next.append(id)
        }
        if next.isEmpty {
            return Toggle(selection: selection, rejectedLastItem: true)
        }
        return Toggle(selection: next, rejectedLastItem: false)
    }
}

/// Whether the gauge image is drawn, and whether overflow may drop another metric.
enum MenuBarDisplay {
    /// The logo is on the left when the user selected it. It is also drawn
    /// when no metric is left to draw, so a status item never goes blank
    /// (a missing reading, not a saved empty selection).
    static func showsLogo(logoSelected: Bool, renderedMetricCount: Int) -> Bool {
        logoSelected || renderedMetricCount <= 0
    }

    /// Metrics drop from the right. The logo, when it is on, stays after
    /// the last metric. When it is off, the last metric stays instead.
    static func canHideAnotherMetric(logoSelected: Bool, visibleMetricCount: Int) -> Bool {
        visibleMetricCount > 0 && (logoSelected || visibleMetricCount > 1)
    }
}

/// Frames for one status item. The button's own image is only used in
/// logo-only mode (`NSStatusItem.squareLength`). Beside metrics, the gauge
/// is drawn inside the widget view: `NSStatusBarButton` centers `button.image`
/// over the whole item and ignores `imageLeading`, which painted the gauge
/// on top of the text.
struct MenuBarItemLayout: Equatable {
    /// Space before the first mark and after the last one. The menu bar
    /// already separates neighboring items, so this stays small. The same
    /// value is used on both ends, with or without the logo.
    static let outerInset: CGFloat = 2
    /// Clear space between the logo image and the first metric.
    static let logoGap: CGFloat = 4

    var showsLogo: Bool
    var barHeight: CGFloat
    var widgetsWidth: CGFloat

    /// X of the first metric. The view covers the item from x = 0.
    var widgetsOriginX: CGFloat {
        if showsLogo {
            return Self.outerInset + StatusGaugeImage.pointSize.width + Self.logoGap
        }
        return Self.outerInset
    }

    /// Status-item length, including both outer insets. Not used for
    /// logo-only mode, which stays `NSStatusItem.squareLength`.
    var length: CGFloat {
        widgetsOriginX + widgetsWidth + Self.outerInset
    }

    /// Distance from the item's left edge to the logo (or to the first
    /// metric, when the logo is off).
    var leadingInset: CGFloat {
        showsLogo ? logoImageRect().minX : widgetsOriginX
    }

    /// Distance from the last widget's box to the item's right edge.
    var trailingInset: CGFloat {
        length - widgetsRect.maxX
    }

    /// Gauge image, vertically centered. The view is flipped (y grows down).
    func logoImageRect(imageSize: CGSize = StatusGaugeImage.pointSize) -> CGRect {
        guard showsLogo else { return .zero }
        let y = (barHeight - imageSize.height) / 2
        return CGRect(x: Self.outerInset, y: y, width: imageSize.width, height: imageSize.height)
    }

    var widgetsRect: CGRect {
        CGRect(x: widgetsOriginX, y: 0, width: widgetsWidth, height: barHeight)
    }

    /// The gauge ink ends before the metrics begin.
    var logoOverlapsWidgets: Bool {
        guard showsLogo, widgetsWidth > 0 else { return false }
        return logoImageRect().maxX > widgetsOriginX
    }
}

/// Caption beside the "show in menu bar" title after a rejected toggle.
struct MinimumSelectionHint: Equatable {
    private(set) var visible = false
    private var deadline: Date?

    mutating func noteRejected(at now: Date) {
        visible = true
        deadline = now.addingTimeInterval(MenuBarSelection.minimumHintDuration)
    }

    mutating func noteSelectionCount(_ count: Int, at now: Date) {
        if count > 1 {
            visible = false
            deadline = nil
            return
        }
        if let deadline, now >= deadline {
            visible = false
            self.deadline = nil
        }
    }
}

/// Keyboard focus for the Settings window. SwiftUI otherwise makes the
/// first switch first responder as soon as the window opens, and that
/// draws the blue ring before the user has used the keyboard.
struct SettingsFocusDecider: Equatable {
    private(set) var keyboardNavigationArmed = false

    enum Decision: Equatable {
        /// Leave the window itself first responder. No control draws a ring.
        case windowItself
        /// A control may be first responder. The ring is drawn only after Tab.
        case control(showRing: Bool)
    }

    mutating func decide(requestedView: Bool, userClickInside: Bool) -> Decision {
        guard requestedView else { return .windowItself }
        if keyboardNavigationArmed { return .control(showRing: true) }
        if userClickInside { return .control(showRing: false) }
        return .windowItself
    }

    mutating func noteTab() {
        keyboardNavigationArmed = true
    }

    mutating func disarm() {
        keyboardNavigationArmed = false
    }
}
