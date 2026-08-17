import AppKit

/// Menu bar controller: one status item, one 2s timer, nothing else.
/// Metrics can be toggled in the menu; selected ones are shown directly
/// in the menu bar as two-line widgets (value over label, separated by
/// vertical bars). The selection is persisted in UserDefaults.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    /// Single view that draws every menu bar widget in one draw(_:).
    /// An earlier version used per-metric NSTextFields in an NSStackView;
    /// keeping that hierarchy alive made AppKit continuously re-render
    /// status-item snapshots (~50% CPU). One flat view with manual text
    /// drawing keeps the per-tick cost near zero. Clicks fall through to
    /// the status bar button via the nil hit test.
    private final class WidgetsView: NSView {
        struct Part {
            var top: String
            var bottom: String
            var uniformFont: Bool
            var topWidthTemplate: String?
        }

        var parts: [Part] = []

        /// y = 0 at the top, so "top" text really draws on top.
        override var isFlipped: Bool { true }

        static let topFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        static let bottomFont = NSFont.systemFont(ofSize: 7.5, weight: .regular)
        static let uniformFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        static let separatorFont = NSFont.systemFont(ofSize: 14, weight: .ultraLight)
        static let separatorWidth: CGFloat = 12
        static let maxWidgetWidth: CGFloat = 70
        /// Fixed width for the network widget: worst case "↑999.9M"
        /// measures ~41.8pt in `uniformFont`, rounded up.
        static let uniformWidgetWidth: CGFloat = 42

        /// (x origin, width) per part, separators included implicitly.
        private var origins: [CGFloat] = []
        private var widths: [CGFloat] = []

        /// Recomputes layout from `parts`. Returns the total width needed.
        /// The separator column is the whole inter-widget gap so the bar
        /// glyph sits centered between neighbouring values.
        @discardableResult
        func relayout() -> CGFloat {
            origins.removeAll()
            widths.removeAll()
            var x: CGFloat = 0
            for (index, part) in parts.enumerated() {
                if index > 0 { x += Self.separatorWidth }
                let width: CGFloat
                if part.uniformFont {
                    width = Self.uniformWidgetWidth
                } else {
                    let topWidth = Self.measure(part.topWidthTemplate ?? part.top, font: Self.topFont)
                    let bottomWidth = Self.measure(part.bottom, font: Self.bottomFont)
                    width = min(Self.maxWidgetWidth, ceil(max(topWidth, bottomWidth)))
                }
                origins.append(x)
                widths.append(width)
                x += width
            }
            return x
        }

        override func draw(_ dirtyRect: NSRect) {
            let height = bounds.height
            let color = NSColor.labelColor
            for (index, part) in parts.enumerated() {
                if index > 0 {
                    let sepX = origins[index] - Self.separatorWidth
                    drawText("|", font: Self.separatorFont,
                             color: color.withAlphaComponent(0.7),
                             in: NSRect(x: sepX, y: 0,
                                        width: Self.separatorWidth, height: height),
                             align: .center)
                }
                let origin = origins[index]
                let width = widths[index]
                if part.uniformFont {
                    // Network widget: up over down, same size, left aligned.
                    drawText(part.top, font: Self.uniformFont, color: color,
                             in: NSRect(x: origin, y: 2, width: width, height: height / 2 - 2),
                             align: .left)
                    drawText(part.bottom, font: Self.uniformFont, color: color,
                             in: NSRect(x: origin, y: height / 2, width: width, height: height / 2 - 1),
                             align: .left)
                } else {
                    drawText(part.top, font: Self.topFont, color: color,
                             in: NSRect(x: origin, y: 1, width: width, height: 14),
                             align: .center)
                    drawText(part.bottom, font: Self.bottomFont, color: color,
                             in: NSRect(x: origin, y: 15, width: width, height: 9),
                             align: .center)
                }
            }
        }

        private func drawText(_ text: String, font: NSFont, color: NSColor,
                              in rect: NSRect, align: NSTextAlignment) {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.lineBreakMode = .byClipping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
            // NSString.draw(in:) lays out from the top of the rect, so
            // offset explicitly to keep the glyphs vertically centered.
            let textHeight = (text as NSString).size(withAttributes: attributes).height
            let centered = NSRect(x: rect.minX,
                                  y: rect.midY - textHeight / 2,
                                  width: rect.width,
                                  height: textHeight)
            (text as NSString).draw(in: centered, withAttributes: attributes)
        }

        static func measure(_ text: String, font: NSFont) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private var widgetsView: WidgetsView?

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    /// Ordered metrics; add new providers here.
    private let providers: [MetricProvider] = [
        CPUMonitor(),
        GPUMonitor(),
        MemoryMonitor(),
        DiskMonitor(),
        TemperatureMonitor(),
        FanMonitor(),
        NetworkMonitor(),
    ]
    private var metricItems: [NSMenuItem] = []
    private var loginMenuItem: NSMenuItem!
    /// Latest reading per provider id, refreshed every timer tick.
    private var readings: [String: MetricReading] = [:]

    private let selectionKey = "menuBarMetrics"
    private var selectedIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: selectionKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: selectionKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu = NSMenu()
        menu.delegate = self

        for provider in providers {
            let item = NSMenuItem(title: "--",
                                  action: #selector(toggleMetric(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = provider.id
            item.state = selectedIDs.contains(provider.id) ? .on : .off
            menu.addItem(item)
            metricItems.append(item)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: L10n.tr(.launchAtLogin),
                                   action: #selector(toggleLaunchAtLogin),
                                   keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)
        loginMenuItem = loginItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.tr(.quit),
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Warm up delta-based samplers (CPU/network need two samples),
        // then take the first real reading 1s later.
        providers.forEach { _ = $0.sample() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
        // .common modes: keeps ticking while the menu is open
        // (an open menu puts the run loop into event tracking mode).
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Refresh right before the menu opens so values are never stale.
    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        for item in metricItems {
            if let id = item.representedObject as? String {
                item.state = selectedIDs.contains(id) ? .on : .off
            }
        }
        loginMenuItem.state = LoginItem.isEnabled ? .on : .off
    }

    private func refresh() {
        for (item, provider) in zip(metricItems, providers) {
            let reading = provider.sample()
            readings[provider.id] = reading
            item.title = reading.menu
        }
        updateStatusBar()
    }

    // MARK: - Menu bar widgets

    /// Shows the selected metrics directly in the menu bar; falls back
    /// to the app icon when nothing is selected. Per tick this only
    /// rewrites the strings of one flat view and asks it to redraw;
    /// the status item is resized solely when the total width changes.
    private func updateStatusBar() {
        guard let button = statusItem.button else { return }

        let parts = providers
            .filter { selectedIDs.contains($0.id) }
            .compactMap { readings[$0.id]?.compact }

        guard !parts.isEmpty else {
            widgetsView?.removeFromSuperview()
            widgetsView = nil
            button.title = ""
            let symbolName = NSImage(systemSymbolName: "fan", accessibilityDescription: nil) != nil
                ? "fan" : "gauge.medium"
            button.image = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: "MacFan")
            button.image?.isTemplate = true
            statusItem.length = NSStatusItem.squareLength
            return
        }

        button.image = nil
        button.title = ""

        let view: WidgetsView
        if let existing = widgetsView {
            view = existing
        } else {
            view = WidgetsView()
            button.addSubview(view)
            widgetsView = view
        }

        view.parts = parts.map {
            WidgetsView.Part(top: $0.top, bottom: $0.bottom, uniformFont: $0.uniformFont,
                             topWidthTemplate: $0.topWidthTemplate)
        }
        let width = view.relayout()

        let barHeight = NSStatusBar.system.thickness
        if view.frame.width != width || view.frame.height != barHeight {
            view.frame = NSRect(x: 3, y: 0, width: width, height: barHeight)
            statusItem.length = width + 6
        }
        view.needsDisplay = true
    }

    // MARK: - Actions

    @objc private func toggleMetric(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var selection = selectedIDs
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
        selectedIDs = selection
        sender.state = selection.contains(id) ? .on : .off
        updateStatusBar()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItem.setEnabled(sender.state != .on)
        sender.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
