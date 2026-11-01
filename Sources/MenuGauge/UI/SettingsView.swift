import AppKit
import Combine
import SwiftUI

/// One scrolling settings page. Native grouped form, fixed width.
/// The quit button stays at the bottom-right; closing the window is not quitting.
struct SettingsView: View {
    @ObservedObject var model: PopoverModel
    var onQuit: () -> Void

    /// Window chrome outside the scrollable form: hint card (120 + 2
    /// padding) plus the quit row (4 + ~28 button + 16 padding).
    static let fixedChromeHeight: CGFloat = 170

    /// Vertical gap between a section title and the controls below it.
    private enum SettingsLayout {
        static let sectionHeaderSpacing: CGFloat = 12
    }

    var body: some View {
        VStack(spacing: 0) {
            // No model inputs, so SwiftUI would skip its body on a language
            // change; pin it to the resolved language to force a rebuild.
            RunningHintCard()
                .id(L10n.language)
                .padding(.bottom, 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: SettingsLayout.sectionHeaderSpacing) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            sectionHeader(L10n.tr(.showInMenu))
                            if model.showsMinimumSelectionHint {
                                Text(L10n.tr(.selectAtLeastOne))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                                  spacing: 8) {
                            ForEach(MetricDescriptor.offered) { metric in
                                MetricCard(metric: metric,
                                           selected: model.selectedIDs.contains(metric.id),
                                           reading: model.readings[metric.id]) {
                                    model.onSelection?(metric.id, !model.selectedIDs.contains(metric.id))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    VStack(alignment: .leading, spacing: SettingsLayout.sectionHeaderSpacing) {
                        sectionHeader(L10n.tr(.general))
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L10n.tr(.launchAtLogin))
                                Spacer()
                                Toggle(L10n.tr(.launchAtLogin), isOn: loginBinding)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .controlSize(.mini)
                            }
                            if model.loginState == .requiresApproval {
                                Button(L10n.tr(.systemSettings)) { LoginItem.openSettings() }
                                    .buttonStyle(.link)
                            }
                            generalRowSeparator
                            HStack {
                                Text(L10n.tr(.theme))
                                Spacer()
                                Picker(L10n.tr(.theme), selection: $model.appearanceOverride) {
                                    Text(L10n.tr(.themeAuto)).tag(AppearanceOverride.auto)
                                    Text(L10n.tr(.themeLight)).tag(AppearanceOverride.light)
                                    Text(L10n.tr(.themeDark)).tag(AppearanceOverride.dark)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .controlSize(.small)
                                .fixedSize()
                            }
                            generalRowSeparator
                            HStack {
                                Text(L10n.tr(.language))
                                Spacer()
                                Picker(L10n.tr(.language), selection: $model.languageOverride) {
                                    Text(L10n.tr(.followSystem)).tag("")
                                    ForEach(L10n.translatedLanguages, id: \.self) { code in
                                        Text(L10n.displayName(code)).tag(code)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .fixedSize()
                            }
                            if !AppEdition.isAppStore {
                                generalRowSeparator
                                HStack {
                                    Text(L10n.tr(.temperatureUnit))
                                    Spacer()
                                    Picker(L10n.tr(.temperatureUnit), selection: $model.temperatureUnit) {
                                        Text("°C").tag(TemperatureUnit.celsius)
                                        Text("°F").tag(TemperatureUnit.fahrenheit)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .controlSize(.small)
                                    .fixedSize()
                                }
                            }
                        }
                        // One character in from the header, both sides.
                        .padding(.horizontal, 14)
                    }

                    VStack(alignment: .leading, spacing: SettingsLayout.sectionHeaderSpacing) {
                        sectionHeader(L10n.tr(.about))
                        about
                            .padding(.horizontal, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { value in
                    model.settingsContentHeight = value
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button(L10n.tr(.quitStatusBar), action: onQuit)
                    .menuGaugeButtonChrome()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(PanelPalette.accent)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    /// Hairline between General rows, matching the popover separators.
    private var generalRowSeparator: some View {
        Rectangle().fill(PanelPalette.line).frame(height: 1)
    }

    private var loginBinding: Binding<Bool> {
        Binding(get: { model.loginState == .enabled || model.loginState == .requiresApproval },
                set: { model.onLogin?($0) })
    }

    private var about: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIconGlyph(size: 28)
            Text(AppIdentity.versionLabel)
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Link(L10n.tr(.privacyPolicy), destination: MenuGaugeLinks.privacy)
                Text("·")
                    .foregroundStyle(.secondary)
                Link(L10n.tr(.website), destination: MenuGaugeLinks.website)
            }
            .font(.system(size: 12))
        }
        .padding(.vertical, 2)
    }
}

private struct RunningHintCard: View {
    /// Rows reserved for the text column: two title lines at 13pt plus
    /// four detail lines at 12pt. Longer translations scale down via
    /// minimumScaleFactor instead of stretching the card; shorter ones
    /// leave the extra rows blank.
    private static let titleHeight: CGFloat = 2 * 16
    private static let detailHeight: CGFloat = 4 * 15

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MenuBarHintArt()
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(.runningTitle))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: Self.titleHeight)
                Text(L10n.tr(.runningDetail))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: Self.detailHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        // Flush with the window edges: no dark ring around this header.
        .background(PanelPalette.tint)
        .accessibilityElement(children: .combine)
    }
}

/// One selectable metric in the settings grid: checkbox at the top-right,
/// a live preview of its menu-bar reading in the middle, and the metric
/// name below. Tapping anywhere toggles; the model may refuse the change
/// (at least one item must stay selected), so the checkbox always renders
/// from `selected` rather than local state.
private struct MetricCard: View {
    let metric: MetricDescriptor
    let selected: Bool
    let reading: MetricReading?
    let action: () -> Void

    /// Card fill: #F8F8F8 over the light window, a hair of white over the
    /// dark one.
    private static let fill = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor.white.withAlphaComponent(0.09)
        }
        return NSColor(white: 0.973, alpha: 1)
    })

    /// Painted per render so a light/dark switch re-resolves labelColor
    /// (the drawing handler runs against the current appearance).
    private var logoImage: NSImage {
        StatusGaugeImage.paintedImage(for: MenuBarHintArt.gaugeKey, color: .labelColor)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    preview
                        .frame(height: 30)
                    Text(metric.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 8)
                checkbox
                    .padding(1)
            }
            .background(Self.fill,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(metric.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var checkbox: some View {
        if selected {
            Image(systemName: "checkmark.square.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, PanelPalette.accent)
                .font(.system(size: 15))
        } else {
            Image(systemName: "square")
                .foregroundStyle(.secondary.opacity(0.55))
                .font(.system(size: 15))
        }
    }

    @ViewBuilder private var preview: some View {
        if metric.id == MetricCatalog.logoID {
            Image(nsImage: logoImage)
        } else if let compact = reading?.compact {
            if compact.uniformFont {
                VStack(spacing: 2) {
                    Text(compact.top)
                    Text(compact.bottom)
                }
                .font(.system(size: 9, weight: .medium))
            } else {
                VStack(spacing: 1) {
                    Text(compact.top)
                        .font(.system(size: 13, weight: .semibold))
                    Text(compact.bottom)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("--")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// Settings window that does not show a focus ring until the user presses
/// Tab. SwiftUI makes the first switch first responder when the window
/// becomes key; that assignment is refused so the ring stays off. Tab
/// still enters the key-view loop, because the window itself is first
/// responder. A later click may focus the clicked control, without a ring,
/// so the switch still toggles.
final class SettingsWindow: NSWindow {
    private var focus = SettingsFocusDecider()
    private var clearingFocus = false
    /// `NSEvent.timestamp` of the event that made the window key, or the
    /// matching media time. A focus change caused by that same event is
    /// not a click inside the window.
    private var becameKeyAt: TimeInterval = -1

    func disarmKeyboardFocus() {
        focus.disarm()
    }

    override func becomeKey() {
        becameKeyAt = NSApp.currentEvent?.timestamp ?? ProcessInfo.processInfo.systemUptime
        super.becomeKey()
    }

    override func resignKey() {
        focus.disarm()
        super.resignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 48 {
            focus.noteTab()
            setFocusRings(.default)
        }
        super.sendEvent(event)
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if clearingFocus {
            return super.makeFirstResponder(responder)
        }
        let decision = focus.decide(requestedView: responder is NSView,
                                    userClickInside: userClickedInsideAfterOpen())
        switch decision {
        case .windowItself where responder is NSView:
            clearingFocus = true
            defer { clearingFocus = false }
            return super.makeFirstResponder(nil)
        case .windowItself:
            return super.makeFirstResponder(responder)
        case .control(let showRing):
            if !showRing { setFocusRings(.none) }
            if let view = responder as? NSView {
                view.focusRingType = showRing ? .default : .none
            }
            return super.makeFirstResponder(responder)
        }
    }

    private func userClickedInsideAfterOpen() -> Bool {
        guard let event = NSApp.currentEvent else { return false }
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            break
        default:
            return false
        }
        guard event.timestamp > becameKeyAt, let contentView else { return false }
        let point = contentView.convert(event.locationInWindow, from: nil)
        return contentView.bounds.contains(point)
    }

    private func setFocusRings(_ type: NSFocusRingType, in root: NSView? = nil) {
        guard let root = root ?? contentView else { return }
        root.focusRingType = type
        for subview in root.subviews {
            setFocusRings(type, in: subview)
        }
    }
}

/// Owns the single Settings window. Closing it tells the delegate so the
/// app can return to an accessory (menu-bar-only) activation policy.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let model: PopoverModel
    var onQuit: (() -> Void)?
    var onClose: (() -> Void)?
    private var window: NSWindow?
    private var didCenter = false
    private var cancellables: Set<AnyCancellable> = []

    init(model: PopoverModel) {
        self.model = model
        super.init()
        // Keep the window exactly as tall as the form: once the scrollable
        // content is measured, grow or shrink the fixed window so nothing
        // ever needs to scroll (unless the screen itself is too short).
        model.$settingsContentHeight
            .sink { [weak self] _ in self?.fitWindowToContent() }
            .store(in: &cancellables)
    }

    var isVisible: Bool { window?.isVisible == true }

    /// Picked up after a language change while the window is open.
    func refreshTitle() {
        window?.title = L10n.tr(.settingsTitle)
    }

    /// Applies the theme override; nil restores the system appearance.
    func applyAppearance(_ override: AppearanceOverride) {
        window?.appearance = override.nsAppearance
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        refreshTitle()
        fitWindowToContent()
        if !window.isVisible {
            (window as? SettingsWindow)?.disarmKeyboardFocus()
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !didCenter {
            window.center()
            didCenter = true
        }
        window.makeKeyAndOrderFront(nil)
    }

    func orderFront() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    /// Resizes the fixed window to the measured form height plus the
    /// header card and quit row, capped by the visible screen height.
    private func fitWindowToContent() {
        guard let window, model.settingsContentHeight > 0 else { return }
        let visibleHeight = window.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height ?? 800
        let height = min(SettingsView.fixedChromeHeight + ceil(model.settingsContentHeight),
                         max(440, visibleHeight - 28))
        let size = NSSize(width: window.frame.width > 0 ? window.contentLayoutRect.width : 440,
                          height: height)
        guard window.contentMinSize != size else { return }
        window.contentMinSize = size
        window.contentMaxSize = size
        window.setContentSize(size)
    }

    private func makeWindow() -> NSWindow {
        let size = Self.preferredContentSize()
        let window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = L10n.tr(.settingsTitle)
        window.appearance = model.appearanceOverride.nsAppearance
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.collectionBehavior = window.collectionBehavior.union(.moveToActiveSpace)
        window.delegate = self
        window.initialFirstResponder = nil
        window.contentMinSize = size
        window.contentMaxSize = size
        let host = NSHostingController(rootView: SettingsView(model: model, onQuit: { [weak self] in
            self?.onQuit?()
        }))
        // The form's ideal height must not resize this fixed window.
        host.sizingOptions = .init()
        window.contentViewController = host
        window.setContentSize(size)
        window.initialFirstResponder = nil
        return window
    }

    /// Initial size before the form is measured; `fitWindowToContent()`
    /// then pins the window to the exact content height. Narrow enough
    /// that the five metric cards end up nearly square.
    static func preferredContentSize(visibleHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? 800) -> NSSize {
        let height = min(640, max(440, visibleHeight - 28))
        return NSSize(width: 440, height: height)
    }
}
