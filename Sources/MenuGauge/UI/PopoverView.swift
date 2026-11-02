import SwiftUI

enum PanelPalette {
    static let background = adaptive(0xF7F9FA, 0x14181C)
    static let card = adaptive(0xFFFFFF, 0x1C2227)
    static let text = adaptive(0x182024, 0xE8F0F2)
    static let secondary = adaptive(0x5F6B72, 0xA7B0B8)
    static let line = adaptive(0xDFE5E8, 0x2A3035)
    static let accent = adaptive(0x0E7C86, 0x5FCFDD)
    static let onAccent = adaptive(0xFFFFFF, 0x071114)
    static let tint = adaptive(0xE2F4F6, 0x14343A)
    static let link = adaptive(0x0B63CE, 0x6CB6FF)
    static let critical = adaptive(0xC7352B, 0xFF453A)
    static let hintStart = adaptive(0xE6F6F8, 0x102A30)
    static let hintEnd = adaptive(0xEDF1FB, 0x1B2230)

    static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

/// Bezel, control size, and destructive tint of the Settings “Quit MenuGauge”
/// button only. `critical` is intentional: quitting is destructive, so the
/// button reads as a warning action in both appearances.
struct MenuGaugeButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(PanelPalette.critical)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(PanelPalette.critical)
    }
}

extension View {
    func menuGaugeButtonChrome() -> some View {
        modifier(MenuGaugeButtonChrome())
    }
}

/// Gear and power. Resting state is the bare accent glyph. Hover and pressed
/// use accent-tinted fills at increasing opacity inside one shared square;
/// `accent` is already light/dark adaptive.
enum MenuGaugeIconChrome: Equatable {
    case plain, hover, pressed

    static let side: CGFloat = 28
    static let corner: CGFloat = 7
    /// Hover fill: a light accent wash.
    static let hoverOpacity: CGFloat = 0.18
    /// Pressed fill: a stronger accent wash, not a different hue.
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
            footer
        }
        .font(.system(size: 13))
        .foregroundStyle(PanelPalette.text)
        .frame(width: 384, height: model.height)
        .background(PanelPalette.background)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppIconGlyph(size: 20)
                    .padding(4)
                    .background(PanelPalette.tint,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color(MetricFormat.heatColor(heat)))
            Text(caption)
                .font(.system(size: 10.5))
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
        return row(symbol: "fan", accent: MetricAccent.color(for: "fan")) {
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
        return row(symbol: symbol, accent: MetricAccent.color(for: id)) {
            Text(text)
                .foregroundStyle(Color(MetricFormat.heatColor(reading?.heat)))
        }
    }

    private var networkRow: some View {
        var down: Double?
        var up: Double?
        if case .network(let d, let u) = model.readings["network"]?.value { down = d; up = u }
        return row(symbol: "arrow.up.arrow.down", accent: MetricAccent.color(for: "network")) {
            Text("↑ \(rateText(up))")
            Text("↓ \(rateText(down))")
                .foregroundStyle(PanelPalette.secondary)
        }
    }

    private func rateText(_ bytes: Double?) -> String {
        let rate = MetricFormat.rate(bytes)
        return rate.unit.isEmpty ? rate.value : "\(rate.value) \(rate.unit)"
    }

    private func row<Content: View>(symbol: String, accent: Color,
                                    @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 20)
            HStack(spacing: 14) { content() }
                .font(.system(size: 13))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
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
