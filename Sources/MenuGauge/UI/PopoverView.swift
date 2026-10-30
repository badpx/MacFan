import SwiftUI

enum PanelPalette {
    static let card = adaptive(0xFFFFFF, 0x2B2D31)
    /// Metrics sit on a light veil. Header and footer stay clear so they match
    /// the popover arrow. Set this to false to try an all-material panel.
    static let showsContentLift = true
    /// White veil over the popover material. Applied when `showsContentLift`
    /// is true.
    static let contentLift = Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor.white.withAlphaComponent(dark ? 0.07 : 0.62)
    })
    static let secondary = adaptive(0x626972, 0xADB3BC)
    static let line = adaptive(0xDFE2E7, 0x41444B)
    static let accent = adaptive(0x147A67, 0x71D5BA)
    static let tint = adaptive(0xE4F2ED, 0x293F39)

    private static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

/// Bezel, control size, and tint of the Settings “Quit MenuGauge” button only.
struct MenuGaugeButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(PanelPalette.accent)
    }
}

extension View {
    func menuGaugeButtonChrome() -> some View {
        modifier(MenuGaugeButtonChrome())
    }
}

/// Gear and power. Resting state is the bare accent glyph. Hover and pressed
/// reuse the light-green and darker fills of the tinted bordered button,
/// as a square of one shared size. `accent` is already light/dark adaptive.
enum MenuGaugeIconChrome: Equatable {
    case plain, hover, pressed

    static let side: CGFloat = 28
    static let corner: CGFloat = 7
    /// Resting fill of a bordered button tinted with `PanelPalette.accent`.
    static let hoverOpacity: CGFloat = 0.18
    /// That button’s pressed fill, a darker green in both appearances.
    static let pressedOpacity: CGFloat = 0.42

    static func state(hovered: Bool, pressed: Bool) -> MenuGaugeIconChrome {
        if pressed { return .pressed }
        if hovered { return .hover }
        return .plain
    }

    var fill: Color {
        switch self {
        case .plain: return .clear
        case .hover: return PanelPalette.accent.opacity(Self.hoverOpacity)
        case .pressed: return PanelPalette.accent.opacity(Self.pressedOpacity)
        }
    }
}

struct MenuGaugeIconButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        let chrome = MenuGaugeIconChrome.state(hovered: hovered, pressed: configuration.isPressed)
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PanelPalette.accent)
            .frame(width: MenuGaugeIconChrome.side, height: MenuGaugeIconChrome.side)
            .background {
                RoundedRectangle(cornerRadius: MenuGaugeIconChrome.corner, style: .continuous)
                    .fill(chrome.fill)
            }
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
    }
}

struct MenuGaugeIconButton: View {
    var systemName: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(MenuGaugeIconButtonStyle())
        .help(label)
        .accessibilityLabel(label)
        .focusable(false)
    }
}

/// The popover arrow is the system material behind the content. This view
/// stays transparent so that material, including wallpaper vibrancy, shows
/// through the header and footer instead of a painted color.
private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func layout() {
        super.layout()
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

final class PopoverHostingController: NSHostingController<PopoverView> {
    override func loadView() {
        view = ClearHostingView(rootView: rootView)
    }
}

struct PopoverView: View {
    @ObservedObject var model: PopoverModel

    /// Header plus footer. The scroll view reports only the page body, and
    /// these paddings are what `chromeHeight` adds back. Keep them together
    /// so the popover does not grow a scrollbar for a point of padding.
    private enum Chrome {
        static let headerTop: CGFloat = 10
        static let headerRow: CGFloat = 32
        static let headerBottom: CGFloat = 8
        static let rule: CGFloat = 1
        static let footerRow: CGFloat = 32
        static let footerPad: CGFloat = 8
        static var height: CGFloat {
            headerTop + headerRow + headerBottom + rule + footerPad * 2 + footerRow + rule
        }
    }

    static var chromeHeight: CGFloat { Chrome.height }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.hiddenCount > 0 { banner(L10n.tr(.menuBarOverflow)) }
                    overview
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { value in
                    model.contentHeight = value
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(PanelPalette.showsContentLift ? PanelPalette.contentLift : Color.clear)
            footer
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.primary)
        .frame(width: 384, height: model.height)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                AppIconGlyph(size: 18)
                Text("MenuGauge")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
            }
            .frame(height: Chrome.headerRow)
            .padding(.horizontal, 16)
            .padding(.top, Chrome.headerTop)
            .padding(.bottom, Chrome.headerBottom)
            Rectangle().fill(PanelPalette.line).frame(height: Chrome.rule)
        }
        .frame(maxWidth: .infinity)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            stats
            Rectangle().fill(PanelPalette.line).frame(height: 1)
                .padding(.vertical, 12)
            rows
        }
    }

    // MARK: Big stats

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: usageValue("cpu"), caption: L10n.ui(.cpuUsage))
            stat(value: temperatureValue, caption: temperatureCaption,
                 heat: model.readings["temperature"]?.heat)
            stat(value: usageValue("gpu"), caption: L10n.ui(.gpuUsage))
        }
    }

    private func usageValue(_ id: String) -> String {
        guard let scalar = model.readings[id]?.value?.scalar else { return "N/A" }
        return MetricFormat.number(scalar, decimals: 0) + "%"
    }

    /// Direct edition shows a degree value in the unit chosen in Settings.
    /// The App Store edition stores a thermal state instead, and must not
    /// fall through to "N/A" for a missing scalar.
    private var temperatureValue: String {
        if case .thermal(let pressure) = model.readings["temperature"]?.value {
            return L10n.tr(pressure.labelKey)
        }
        guard let scalar = model.readings["temperature"]?.value?.scalar else { return "N/A" }
        let unit = TemperatureUnit.current
        return MetricFormat.number(unit.convert(scalar), decimals: 0) + unit.symbol
    }

    private var temperatureCaption: String {
        if case .thermal = model.readings["temperature"]?.value {
            return L10n.tr(.thermalState)
        }
        return L10n.ui(.cpuTemperature)
    }

    private func stat(value: String, caption: String, heat: Double? = nil) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color(MetricFormat.heatColor(heat)))
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(PanelPalette.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Detail rows

    private var rows: some View {
        VStack(spacing: 0) {
            #if !MAS
            fanRow
            #endif
            capacityRow(id: "memory", symbol: "memorychip",
                        word: L10n.ui(.available), showAvailable: true, decimals: 1)
            capacityRow(id: "disk", symbol: "internaldrive",
                        word: L10n.ui(.available), showAvailable: true, decimals: 0)
            networkRow
        }
    }

    #if !MAS
    private var fanRow: some View {
        let rpm = model.readings["fan"]?.value?.scalar
        let value = rpm.map { MetricFormat.number($0, decimals: 0) + " RPM" } ?? "N/A"
        return row(symbol: "fan") {
            Text("\(L10n.tr(.fan)) \(value)")
        }
    }
    #endif

    private func capacityRow(id: String, symbol: String, word: String,
                             showAvailable: Bool, decimals: Int) -> some View {
        let reading = model.readings[id]
        var text = "N/A"
        if case .capacity(let used, let total) = reading?.value {
            let shown = showAvailable ? max(0, total - used) : used
            text = "\(word) \(MetricFormat.number(shown, decimals: decimals)) GB · " +
                   String(format: L10n.ui(.ofTotal), MetricFormat.number(total, decimals: 0))
        }
        return row(symbol: symbol) {
            Text(text)
                .foregroundStyle(Color(MetricFormat.heatColor(reading?.heat)))
        }
    }

    private var networkRow: some View {
        var down: Double?
        var up: Double?
        if case .network(let d, let u) = model.readings["network"]?.value { down = d; up = u }
        return row(symbol: "arrow.up.arrow.down") {
            Text("↑ \(rateText(up))")
            Text("↓ \(rateText(down))")
                .foregroundStyle(PanelPalette.secondary)
        }
    }

    private func rateText(_ bytes: Double?) -> String {
        let rate = MetricFormat.rate(bytes)
        return rate.unit.isEmpty ? rate.value : "\(rate.value) \(rate.unit)"
    }

    private func row<Content: View>(symbol: String,
                                    @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(PanelPalette.secondary)
                .frame(width: 20)
            HStack(spacing: 14) { content() }
                .font(.system(size: 13))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(PanelPalette.line).frame(height: Chrome.rule)
            HStack {
                MenuGaugeIconButton(systemName: "gearshape", label: L10n.tr(.settings)) {
                    model.onOpenSettings?()
                }
                Spacer(minLength: 0)
                MenuGaugeIconButton(systemName: "power", label: quitHelp) {
                    model.onQuit?()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Chrome.footerRow)
            .padding(.horizontal, 16)
            .padding(.vertical, Chrome.footerPad)
        }
    }

    /// Spoken name and tooltip. ⌘Q still quits; the button itself is only the power icon.
    private var quitHelp: String { "\(L10n.tr(.quitShort)) ⌘Q" }

    private func banner(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(PanelPalette.tint, in: RoundedRectangle(cornerRadius: 8))
    }
}
