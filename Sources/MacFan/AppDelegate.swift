import AppKit

/// Menu bar controller: one status item, one 2s timer, nothing else.
/// Metrics can be toggled in the menu; selected ones are shown directly
/// in the menu bar as two-line widgets (value over label, separated by
/// vertical bars). The selection is persisted in UserDefaults.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    /// Transparent to clicks so the status bar button keeps receiving them.
    private final class PassThroughStackView: NSStackView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// Same as above, for the metric widget containers.
    private final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    /// Ordered metrics; add new providers here.
    private let providers: [MetricProvider] = [
        CPUMonitor(),
        TemperatureMonitor(),
        FanMonitor(),
        MemoryMonitor(),
        DiskMonitor(),
        NetworkMonitor(),
    ]
    private var metricItems: [NSMenuItem] = []
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

        let loginItem = NSMenuItem(title: "开机自启动",
                                   action: #selector(toggleLaunchAtLogin),
                                   keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 MacFan",
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
        menu.item(withTitle: "开机自启动")?.state = LoginItem.isEnabled ? .on : .off
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
    /// to the app icon when nothing is selected.
    private func updateStatusBar() {
        guard let button = statusItem.button else { return }

        let parts = providers
            .filter { selectedIDs.contains($0.id) }
            .compactMap { readings[$0.id]?.compact }

        button.subviews.forEach { $0.removeFromSuperview() }

        guard !parts.isEmpty else {
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

        let stack = PassThroughStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 3
        for (index, part) in parts.enumerated() {
            if index > 0 { stack.addArrangedSubview(makeSeparator()) }
            stack.addArrangedSubview(makeMetricView(part))
        }

        let barHeight = NSStatusBar.system.thickness
        let width = stack.fittingSize.width
        // Set the frame before adding to the button — adding with a zero
        // frame makes the autoresizing-mask constraint (height == 0)
        // fight the arranged subviews' heights on every refresh.
        stack.frame = NSRect(x: 3, y: 0, width: width, height: barHeight)
        stack.autoresizingMask = [.height]
        button.addSubview(stack)
        statusItem.length = width + 6
    }

    /// Two-line widget: value over label (same size for `uniformFont`).
    /// Laid out manually inside a plain container — NSStackView's own
    /// constraints would fight the width anchors. Width is capped at 70pt
    /// per widget; the network widget gets a fixed width with left-aligned
    /// text so digit-count changes extend rightward without shifting the
    /// text away from the separator.
    private func makeMetricView(_ reading: CompactReading) -> NSView {
        let topFont: NSFont
        let bottomFont: NSFont
        if reading.uniformFont {
            topFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)
            bottomFont = topFont
        } else {
            topFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            bottomFont = NSFont.systemFont(ofSize: 6.5, weight: .regular)
        }

        let topLabel = makeLabel(reading.top, font: topFont)
        let bottomLabel = makeLabel(reading.bottom, font: bottomFont)
        let topSize = topLabel.fittingSize
        let bottomSize = bottomLabel.fittingSize

        let naturalWidth = ceil(max(topSize.width, bottomSize.width))
        let width = reading.uniformFont ? CGFloat(48) : min(70, naturalWidth)
        let height = ceil(topSize.height + bottomSize.height)

        let topX = reading.uniformFont ? CGFloat(0) : (width - topSize.width) / 2
        let bottomX = reading.uniformFont ? CGFloat(0) : (width - bottomSize.width) / 2

        let view = PassThroughView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        topLabel.frame = NSRect(x: topX,
                                y: bottomSize.height,
                                width: topSize.width,
                                height: topSize.height)
        bottomLabel.frame = NSRect(x: bottomX,
                                   y: 0,
                                   width: bottomSize.width,
                                   height: bottomSize.height)
        view.addSubview(topLabel)
        view.addSubview(bottomLabel)
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func makeSeparator() -> NSView {
        let separator = makeLabel("|", font: NSFont.systemFont(ofSize: 13, weight: .ultraLight))
        separator.alphaValue = 0.7
        return separator
    }

    private func makeLabel(_ text: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .labelColor
        label.alignment = .center
        return label
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
