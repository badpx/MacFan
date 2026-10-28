import AppKit
import Combine
import SwiftUI

/// Menu bar controller with a native popover and one shared 2s sampler.
/// Metrics are toggled in the Settings window; selected ones are shown
/// directly in the menu bar as two-line widgets (value over label,
/// separated by vertical bars). The selection is persisted in
/// UserDefaults.standard under "menuBarMetrics". That domain follows the
/// bundle identifier com.badpx.macfan, so the MenuGauge rename keeps an
/// existing choice.
/// When the menu bar runs out of room the system silently hides the
/// status item; the controller then drops widgets from the right end
/// and periodically probes for free space to bring them back.
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    /// Single view that draws every menu bar widget in one draw(_:).
    /// An earlier version used per-metric NSTextFields in an NSStackView;
    /// keeping that hierarchy alive made AppKit continuously re-render
    /// status-item snapshots (~50% CPU). One flat view keeps the per-tick
    /// cost near zero. Clicks fall through to the status bar button via
    /// the nil hit test. The gauge is not drawn here: it is the button's
    /// template image, and only while no metric is showing.
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
    private let gauge = MenuBarGauge()
    private let popover = NSPopover()
    private let panelModel = PopoverModel()
    private lazy var settings = SettingsWindowController(model: panelModel)
    private var keyMonitor: Any?
    /// Set only after the user confirms. Lets the Dock's Quit, which calls
    /// terminate directly, share one confirmation with the panel and ⌘Q.
    private var quitConfirmed = false
    private var quitPromptOpen = false
    private var launchedAtLogin = false
    /// Bumps when Settings is shown or closed, so a deferred order-front
    /// cannot reopen a window the user already dismissed.
    private var settingsPresentation = 0
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    /// Ordered metrics. The App Store edition omits the fan provider.
    private let providers: [MetricProvider] = MetricCatalog.makeProviders(appStore: AppEdition.isAppStore)
    /// Latest reading per provider id, refreshed every timer tick.
    private var readings: [String: MetricReading] = [:]

    // MARK: Menu bar overflow (graceful degradation)

    /// Selected widgets suppressed from the right end because the
    /// system hid the status item when the menu bar ran out of room
    /// (network, the widest, drops first). 0 = everything is shown.
    private var hiddenWidgetCount = 0
    /// Widgets rendered by the last updateStatusBar pass (0 = icon mode).
    private var renderedWidgetCount = 0
    /// Relayouts take about one tick to settle in WindowServer, so the
    /// tick right after a resize must not trust the window position.
    private var skipVisibilityCheck = false
    /// A restore probe (one widget added back) is awaiting its check.
    private var probeInFlight = false
    /// Last restore-probe attempt; paces probes to one per 30 seconds.
    private var lastProbeAttempt = Date.distantPast
    private let selectionKey = "menuBarMetrics"
    private var selectedIDs: [String] {
        get {
            let saved = UserDefaults.standard.stringArray(forKey: selectionKey) ?? []
            return MetricCatalog.sanitizedSelection(saved, appStore: AppEdition.isAppStore)
        }
        set { UserDefaults.standard.set(newValue, forKey: selectionKey) }
    }

    /// Drops a fan id left behind by the direct edition so the settings
    /// count and the overflow logic do not reserve a row this build cannot show.
    private func sanitizeStoredSelection() {
        let saved = UserDefaults.standard.stringArray(forKey: selectionKey) ?? []
        let cleaned = MetricCatalog.sanitizedSelection(saved, appStore: AppEdition.isAppStore)
        if cleaned != saved {
            UserDefaults.standard.set(cleaned, forKey: selectionKey)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before any status item or window. A second process must not flash UI.
        if yieldToExistingInstance() { return }
        observeInstanceHandoff()
        // The open-application Apple event is only current during launch.
        launchedAtLogin = LoginLaunch.isCurrentEvent()
        sanitizeStoredSelection()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: panelModel))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        gauge.onUpdate = { [weak self] in self?.applyGaugeAppearance() }
        gauge.start()
        panelModel.onSelection = { [weak self] id, enabled in self?.setMetric(id, enabled: enabled) }
        panelModel.onLogin = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
        panelModel.onQuit = { [weak self] in self?.quit() }
        panelModel.onOpenSettings = { [weak self] in self?.showSettings() }
        settings.onQuit = { [weak self] in self?.quit() }
        settings.onClose = { [weak self] in self?.settingsWindowDidClose() }
        installMainMenu()
        // Resize as soon as the view reports a new measured content height,
        // instead of waiting for the next 2s refresh tick.
        panelModel.$contentHeight
            .sink { [weak self] _ in self?.resizePopover() }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLoginState),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)

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

        // Restore probes: menu bar space frees up when the front app
        // changes (its menus shrink) or the display setup changes.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(probeRestoreIfDue),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(probeRestoreIfDue),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        updateStatusBar()
        presentSettingsIfFirstLaunch()
    }

    /// Same bundle id, different PID: website build beside the App Store
    /// build, `open -n`, or the executable launched directly. Ask the copy
    /// that already has the menu-bar icon to show Settings, then exit
    /// without building any UI. `--ui-snapshot` is not a second instance.
    private func yieldToExistingInstance() -> Bool {
        let current = NSRunningApplication.current
        let peers = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated }
            .map {
                SingleInstancePeer(bundleIdentifier: $0.bundleIdentifier,
                                   processIdentifier: $0.processIdentifier)
            }
        guard SingleInstance.shouldYield(
            bundleIdentifier: current.bundleIdentifier,
            currentPID: current.processIdentifier,
            peers: peers,
            arguments: CommandLine.arguments
        ) else { return false }

        let bundleIdentifier = current.bundleIdentifier
        DistributedNotificationCenter.default().postNotificationName(
            SingleInstance.handoffNotification,
            object: bundleIdentifier,
            userInfo: [SingleInstance.senderPIDKey: Int(current.processIdentifier)],
            deliverImmediately: true)
        for app in NSWorkspace.shared.runningApplications where
            app.bundleIdentifier == bundleIdentifier &&
            app.processIdentifier != current.processIdentifier &&
            !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        // `terminate` during didFinishLaunching can be ignored, and the
        // quit path would otherwise present a confirmation. Exit with no UI.
        exit(0)
    }

    /// Sandboxed copies of this bundle id can hear each other without a new
    /// entitlement. Activation alone does not reopen the app, so Settings
    /// is shown from here, the same path as `applicationShouldHandleReopen`.
    private func observeInstanceHandoff() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(anotherInstanceRequestedSettings(_:)),
            name: SingleInstance.handoffNotification,
            object: Bundle.main.bundleIdentifier,
            suspensionBehavior: .deliverImmediately)
    }

    @objc private func anotherInstanceRequestedSettings(_ notification: Notification) {
        let sender = (notification.userInfo?[SingleInstance.senderPIDKey] as? NSNumber)?.int32Value
        if sender == ProcessInfo.processInfo.processIdentifier { return }
        showSettings()
    }

    /// A normal first launch shows Settings so the app is obviously running.
    /// Login-item launches skip it and leave the flag unset.
    private func presentSettingsIfFirstLaunch() {
        let done = UserDefaults.standard.bool(forKey: LaunchPresentation.firstLaunchKey)
        guard LaunchPresentation.shouldShowSettings(launchedAtLogin: launchedAtLogin,
                                                    hasCompletedFirstLaunch: done) else { return }
        UserDefaults.standard.set(true, forKey: LaunchPresentation.firstLaunchKey)
        // After didFinishLaunching returns, activation-policy changes stick
        // and the window can come forward.
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitConfirmed || SessionQuit.isEndingSession(NSAppleEventManager.shared().currentAppleEvent) {
            return .terminateNow
        }
        // Dock Quit calls terminate directly. Cancel that and show the
        // same confirmation the panel and ⌘Q use.
        DispatchQueue.main.async { [weak self] in self?.quit() }
        return .terminateCancel
    }

    private func refresh() {
        for provider in providers { readings[provider.id] = provider.sample() }
        if case .percent(let cpu) = readings["cpu"]?.value {
            gauge.noteCPU(cpu)
        } else {
            gauge.noteCPU(nil)
        }
        gauge.refreshThermal()
        updateStatusBar()
        checkVisibilityAndDegrade()
        probeRestoreIfDue()
        syncPopover()
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        refresh()
        syncPopover(force: true)
        resizePopover()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Deliberately not made key: a key window puts an initial focus
        // ring on the first control. Esc / ⌘Q still work via the local
        // key monitor, which sees events for the active app regardless.
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.popover.isShown else { return event }
                if event.keyCode == 53 { self.popover.performClose(nil); return nil }
                let command = event.modifierFlags.contains(.command)
                let key = event.charactersIgnoringModifiers
                if command, key == "q" {
                    self.quit()
                    return nil
                }
                if command, key == "," {
                    // Leave the monitor before it closes the popover.
                    DispatchQueue.main.async { self.showSettings() }
                    return nil
                }
                return event
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Sizes the popover to the measured content height plus the fixed
    /// chrome (header + footer), so every metric row fits exactly and no
    /// scroll bar appears. Falls back to an estimate before the first layout.
    private func resizePopover() {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let available = max(300, (screen?.visibleFrame.height ?? 900) - 32)
        let chrome = PopoverView.chromeHeight
        let fallback: CGFloat = 330
        let desired = panelModel.contentHeight > 0
            ? ceil(panelModel.contentHeight + chrome) : fallback
        let height = min(desired, available)
        if panelModel.height != height { panelModel.height = height }
        popover.contentSize = NSSize(width: 384, height: height)
    }

    private func syncPopover(force: Bool = false) {
        guard force || popover.isShown || settings.isVisible else { return }
        panelModel.readings = readings
        panelModel.selectedIDs = selectedIDs
        panelModel.hiddenCount = hiddenWidgetCount
        panelModel.loginState = LoginItem.state
    }

    @objc private func refreshLoginState() {
        guard popover.isShown || settings.isVisible else { return }
        panelModel.loginState = LoginItem.state
    }

    // MARK: - Menu bar widgets

    /// Metrics replace the gauge, matching the old fan symbol. The template
    /// image is assigned to the status button so AppKit tints it for light,
    /// dark, and the highlighted menu bar. With any metric drawn, the image
    /// is cleared and only the text view remains.
    private func updateStatusBar() {
        guard let button = statusItem.button else { return }
        defer { syncPopover() }

        button.setAccessibilityLabel(gauge.accessibilityLabel)
        button.setAccessibilityValue(providers.filter { selectedIDs.contains($0.id) }
            .compactMap { readings[$0.id]?.menu }.joined(separator: ", "))

        let selectedParts = providers
            .filter { selectedIDs.contains($0.id) }
            .compactMap { readings[$0.id]?.compact }
        hiddenWidgetCount = min(hiddenWidgetCount, selectedParts.count)
        // Suppressed widgets drop off the right end first.
        let parts = Array(selectedParts.dropLast(hiddenWidgetCount))
        renderedWidgetCount = parts.count

        guard !StatusGauge.showsGauge(renderedMetricCount: parts.count) else {
            widgetsView?.removeFromSuperview()
            widgetsView = nil
            button.title = ""
            showGaugeImage()
            if statusItem.length != NSStatusItem.squareLength {
                statusItem.length = NSStatusItem.squareLength
                skipVisibilityCheck = true
            }
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
        let length = width + 6
        if view.frame.minX != 3 || view.frame.width != width || view.frame.height != barHeight
            || statusItem.length != length {
            view.frame = NSRect(x: 3, y: 0, width: width, height: barHeight)
            statusItem.length = length
            skipVisibilityCheck = true
        }
        view.needsDisplay = true
    }

    /// Template images are tinted only when they are the status button's image.
    private func showGaugeImage() {
        guard let button = statusItem.button else { return }
        let image = gauge.image
        image.isTemplate = true
        guard button.image !== image else { return }
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func applyGaugeAppearance() {
        statusItem.button?.setAccessibilityLabel(gauge.accessibilityLabel)
        guard widgetsView == nil else { return }
        showGaugeImage()
    }

    /// Per-tick overflow handling. When a status item no longer fits,
    /// the system parks its window outside the displayable menu bar
    /// strip while every public visibility property keeps reporting
    /// "visible" — the window position is the only reliable signal.
    /// On detection, drop one more widget; on a successful restore
    /// probe, immediately try the next one.
    private func checkVisibilityAndDegrade() {
        guard renderedWidgetCount > 0 else { return }
        if skipVisibilityCheck {
            skipVisibilityCheck = false
            return
        }
        if statusItemIsVisible() {
            if probeInFlight {
                probeInFlight = false
                NSLog("MenuGauge: restore probe succeeded, \(hiddenWidgetCount) widget(s) still hidden")
                probeRestore(forced: true)
            }
            return
        }
        probeInFlight = false
        hiddenWidgetCount += 1
        // Freshly degraded: wait before probing again.
        lastProbeAttempt = Date()
        NSLog("MenuGauge: menu bar full, hiding rightmost widget (\(hiddenWidgetCount) hidden)")
        updateStatusBar()
    }

    /// Tries to reveal one more suppressed widget. Fails safe: if the
    /// space still isn't there, the next visibility check re-hides it.
    @objc private func probeRestoreIfDue() {
        probeRestore(forced: false)
    }

    private func probeRestore(forced: Bool) {
        guard hiddenWidgetCount > 0, !probeInFlight, !skipVisibilityCheck else { return }
        let now = Date()
        guard forced || now.timeIntervalSince(lastProbeAttempt) >= 30 else { return }
        lastProbeAttempt = now
        hiddenWidgetCount -= 1
        probeInFlight = true
        NSLog("MenuGauge: probing menu bar space (\(hiddenWidgetCount) widget(s) still hidden)")
        updateStatusBar()
    }

    /// Whether the status item is actually drawn in the menu bar.
    /// When the system hides an item for lack of space, every public
    /// visibility property keeps lying (isVisible/isHidden/window.isVisible)
    /// and the window is parked at some unreachable position — but its
    /// occlusionState loses the .visible bit. Verified empirically on
    /// single- and multi-display setups.
    private func statusItemIsVisible() -> Bool {
        guard let window = statusItem.button?.window else { return false }
        if ProcessInfo.processInfo.environment["MACFAN_DEBUG_LAYOUT"] != nil {
            NSLog("MenuGauge: window=\(NSStringFromRect(window.frame)) occlusion=\(window.occlusionState.rawValue)")
        }
        return window.occlusionState.contains(.visible)
    }

    // MARK: - Actions

    private func setMetric(_ id: String, enabled: Bool) {
        guard providers.contains(where: { $0.id == id }) else { return }
        var selection = selectedIDs.filter { $0 != id }
        if enabled { selection.append(id) }
        selectedIDs = selection
        panelModel.selectedIDs = selection
        hiddenWidgetCount = 0
        probeInFlight = false
        updateStatusBar()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        panelModel.loginError = nil
        do { try LoginItem.setEnabled(enabled) }
        catch { panelModel.loginError = error.localizedDescription }
        panelModel.loginState = LoginItem.state
    }

    private func quit() {
        if quitConfirmed {
            NSApp.terminate(nil)
            return
        }
        if quitPromptOpen { return }
        quitPromptOpen = true
        let reopen = popover.isShown
        popover.performClose(nil)
        // Ask before terminating so a misclick in the menu doesn't kill
        // the app. Closing Settings never reaches this.
        let alert = NSAlert()
        alert.messageText = L10n.tr(.quitConfirm)
        alert.addButton(withTitle: L10n.tr(.quitShort))
        alert.addButton(withTitle: L10n.tr(.cancel))
        // Accessory app: bring the alert to the front explicitly.
        NSApp.activate(ignoringOtherApps: true)
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        quitPromptOpen = false
        if confirmed {
            quitConfirmed = true
            NSApp.terminate(nil)
        } else if reopen {
            showPopover()
        }
    }

    /// Gear, ⌘,, first launch and Finder reopen all come through here.
    /// The window is ordered front. While it is open the app is a normal
    /// app so ⌘Tab and ⌘W work; closing it returns to the menu bar.
    private func showSettings() {
        settingsPresentation += 1
        let presentation = settingsPresentation
        if popover.isShown { popover.performClose(nil) }
        panelModel.selectedIDs = selectedIDs
        panelModel.loginState = LoginItem.state
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        settings.show()
        // Policy changes can land the window behind other apps. A second
        // order-front on the next turn corrects that, unless it has since closed.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.settingsPresentation == presentation else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.settings.orderFront()
        }
    }

    private func settingsWindowDidClose() {
        settingsPresentation += 1
        let presentation = settingsPresentation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.settingsPresentation == presentation else { return }
            guard !self.settings.isVisible, !self.quitConfirmed else { return }
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    /// Shown while Settings is key. ⌘, and ⌘Q are also watched from the
    /// popover, because an accessory app does not display this menu.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "MenuGauge")
        appItem.submenu = appMenu

        let settingsItem = NSMenuItem(title: L10n.tr(.settings) + "…",
                                      action: #selector(showSettingsFromMenu(_:)),
                                      keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.tr(.quit),
                                  action: #selector(quitFromMenu(_:)),
                                  keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: L10n.tr(.windowMenu))
        windowItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: L10n.tr(.closeWindow),
                                      action: #selector(NSWindow.performClose(_:)),
                                      keyEquivalent: "w"))
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }

    @objc private func showSettingsFromMenu(_ sender: Any?) {
        showSettings()
    }

    @objc private func quitFromMenu(_ sender: Any?) {
        quit()
    }
}
