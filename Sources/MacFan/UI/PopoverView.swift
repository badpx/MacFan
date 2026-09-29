import SwiftUI

enum PanelPalette {
    static let background = adaptive(0xF5F6F8, 0x202225)
    static let card = adaptive(0xFFFFFF, 0x2B2D31)
    static let secondary = adaptive(0x626972, 0xADB3BC)
    static let line = adaptive(0xDFE2E7, 0x41444B)
    static let track = adaptive(0xE8EBEF, 0x3A3E44)
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

struct PopoverView: View {
    @ObservedObject var model: PopoverModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.hiddenCount > 0 { banner(L10n.tr(.menuBarOverflow)) }
                    if model.page == .overview { overview } else { configuration }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { value in
                    model.contentHeight = value
                }
            }
            .id(model.page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.primary)
        .frame(width: 384, height: model.height)
        .background(PanelPalette.background)
        .onChange(of: model.page) { _ in
            model.contentHeight = 0
            model.onPage?()
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 32) {
                tabButton(.overview, title: L10n.ui(.overview))
                tabButton(.configuration, title: L10n.ui(.configuration))
            }
            .padding(.top, 10)
            Rectangle().fill(PanelPalette.line).frame(height: 1)
        }
    }

    private func tabButton(_ page: PopoverPage, title: String) -> some View {
        let active = model.page == page
        return Button { model.page = page } label: {
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 14, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.primary : PanelPalette.secondary)
                Capsule()
                    .fill(active ? PanelPalette.accent : Color.clear)
                    .frame(width: 22, height: 2.5)
            }
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityAddTraits(active ? .isSelected : [])
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
            stat(value: temperatureValue, caption: L10n.ui(.cpuTemperature),
                 heat: model.readings["temperature"]?.heat)
            stat(value: usageValue("gpu"), caption: L10n.ui(.gpuUsage))
        }
    }

    private func usageValue(_ id: String) -> String {
        guard let scalar = model.readings[id]?.value?.scalar else { return "N/A" }
        return MetricFormat.number(scalar, decimals: 0) + "%"
    }

    private var temperatureValue: String {
        guard let scalar = model.readings["temperature"]?.value?.scalar else { return "N/A" }
        return MetricFormat.number(scalar, decimals: 0) + "°C"
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
            fanRow
            rowLine
            capacityRow(id: "memory", symbol: "memorychip",
                        word: L10n.ui(.available), showAvailable: true, decimals: 1)
            rowLine
            capacityRow(id: "disk", symbol: "internaldrive",
                        word: L10n.ui(.available), showAvailable: true, decimals: 0)
            rowLine
            networkRow
        }
    }

    private var rowLine: some View {
        Rectangle().fill(PanelPalette.line).frame(height: 1)
            .padding(.leading, 30)
    }

    private var fanRow: some View {
        let rpm = model.readings["fan"]?.value?.scalar
        let value = rpm.map { MetricFormat.number($0, decimals: 0) + " RPM" } ?? "N/A"
        return row(symbol: "fan") {
            Text("\(L10n.tr(.fan)) \(value)")
        }
    }

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

    // MARK: Configuration

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(L10n.ui(.showInMenu), detail: String(format: L10n.ui(.selected), model.selectedIDs.count))
            VStack(spacing: 0) {
                ForEach(MetricDescriptor.all) { metric in
                    if metric.id != "cpu" { Rectangle().fill(PanelPalette.line).frame(height: 1) }
                    HStack {
                        label(metric.title, symbol: metric.symbol)
                        Spacer()
                        Toggle(metric.title, isOn: Binding(get: { model.selectedIDs.contains(metric.id) },
                                             set: { model.onSelection?(metric.id, $0) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                            .tint(PanelPalette.accent)
                            .focusable(false)
                            .accessibilityLabel("\(L10n.ui(.showInMenu)): \(metric.title)")
                    }
                    .frame(minHeight: 34)
                }
            }
            .padding(.horizontal, 12)
            .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 10))
            Text(L10n.ui(.configHint)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.tr(.launchAtLogin))
                    Spacer()
                    Toggle(L10n.tr(.launchAtLogin), isOn: Binding(
                        get: { model.loginState == .enabled || model.loginState == .requiresApproval },
                        set: { model.onLogin?($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(PanelPalette.accent)
                        .focusable(false)
                }
                Text(loginDescription).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.loginState == .requiresApproval {
                    Button(L10n.ui(.systemSettings)) { LoginItem.openSettings() }
                        .font(.system(size: 11)).buttonStyle(.link).focusable(false)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(12).background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 10))
            Text(L10n.ui(.product)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                .frame(maxWidth: .infinity).padding(.top, 2)
        }
    }

    private var loginDescription: String {
        if let error = model.loginError { return error }
        switch model.loginState {
        case .requiresApproval: return L10n.ui(.loginPending)
        case .unavailable: return L10n.ui(.loginUnavailable)
        default: return L10n.ui(.loginHint)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(PanelPalette.line).frame(height: 1)
            HStack {
                Text(String(format: L10n.ui(.menuCount), model.selectedIDs.count))
                Spacer()
                if model.page == .overview {
                    Text(versionText)
                } else {
                    Button { model.onQuit?() } label: {
                        HStack(spacing: 10) { Text(L10n.tr(.quit)); Text("⌘ Q") }
                    }
                    .buttonStyle(.plain).focusable(false)
                }
            }
            .font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
    }

    private var versionText: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String, !version.isEmpty else { return "MacFan" }
        return "MacFan v\(version)"
    }

    private func label(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
            .foregroundStyle(PanelPalette.secondary)
    }

    private func heading(_ title: String, detail: String = "") -> some View {
        HStack {
            Text(title).fontWeight(.medium)
            Spacer(minLength: 2)
            if !detail.isEmpty { Text(detail) }
        }.font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
    }

    private func banner(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(PanelPalette.tint, in: RoundedRectangle(cornerRadius: 8))
    }
}
