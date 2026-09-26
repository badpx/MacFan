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
            header
            HStack(spacing: 3) {
                pageButton(.overview, title: L10n.ui(.overview))
                pageButton(.configuration, title: L10n.ui(.configuration))
            }
            .padding(3)
            .background(PanelPalette.track, in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .onChange(of: model.page) { _ in model.onPage?() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.hiddenCount > 0 { banner(L10n.tr(.menuBarOverflow)) }
                    if model.page == .overview { overview } else { configuration }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .id(model.page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.primary)
        .frame(width: 384, height: model.height)
        .background(PanelPalette.background)
    }

    private func pageButton(_ page: PopoverPage, title: String) -> some View {
        Button { model.page = page } label: {
            Text(title).font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 28)
                .foregroundStyle(model.page == page ? Color.primary : PanelPalette.secondary)
                .background(model.page == page ? PanelPalette.card : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.page == page ? .isSelected : [])
        .onMoveCommand { direction in
            if direction == .left { model.page = .overview }
            if direction == .right { model.page = .configuration }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "fan")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(PanelPalette.accent)
                .frame(width: 32, height: 32)
                .background(PanelPalette.tint, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("MacFan").font(.system(size: 17, weight: .semibold))
                Text(L10n.ui(.tagline)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Circle().fill(PanelPalette.accent).frame(width: 5, height: 5)
                Text(L10n.ui(.refresh)).font(.system(size: 11))
            }
            .foregroundStyle(PanelPalette.secondary)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }

    private var overview: some View {
        Group {
            if model.hasUnavailableReadings { banner(L10n.ui(.partial)) }
            VStack(spacing: 8) {
                heading(L10n.ui(.processors), detail: L10n.ui(.utilization))
                HStack(spacing: 10) {
                    processor("cpu", title: "CPU")
                    processor("gpu", title: "GPU")
                }
            }
            VStack(spacing: 8) {
                heading(L10n.ui(.storage))
                VStack(spacing: 0) {
                    capacity("memory", title: L10n.tr(.memory), symbol: "memorychip", decimals: 1)
                    Rectangle().fill(PanelPalette.line).frame(height: 1)
                    capacity("disk", title: L10n.tr(.disk), symbol: "internaldrive", decimals: 0)
                }
                .padding(.horizontal, 14)
                .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(spacing: 8) {
                heading(L10n.ui(.cooling))
                HStack(spacing: 10) {
                    sensor("temperature", title: L10n.tr(.temperature), symbol: "thermometer.medium", unit: "°C", decimals: 1)
                    sensor("fan", title: L10n.tr(.fan), symbol: "fan", unit: "RPM", decimals: 0)
                }
            }
            VStack(spacing: 8) {
                heading(L10n.tr(.network), detail: L10n.ui(.transfer))
                network
            }
        }
    }

    private func processor(_ id: String, title: String) -> some View {
        let value = model.readings[id]?.value?.scalar
        return VStack(alignment: .leading, spacing: 6) {
            label(title, symbol: "cpu")
            number(MetricFormat.number(value), unit: "%", size: 30)
            if let value {
                SegmentMeter(value: value)
                    .frame(height: 16).padding(.top, 4)
                    .accessibilityHidden(true)
            } else {
                Text(model.readings[id] == nil ? L10n.ui(.sampling) : L10n.ui(.unavailable))
                    .font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                    .frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func capacity(_ id: String, title: String, symbol: String, decimals: Int) -> some View {
        let reading = model.readings[id]
        var used: Double?
        var total: Double?
        if case .capacity(let u, let t) = reading?.value { used = u; total = t }
        let percent = used.flatMap { u in total.flatMap { $0 > 0 ? u / $0 * 100 : nil } }
        let color = Color(MetricFormat.heatColor(reading?.heat))
        return VStack(spacing: 8) {
            HStack {
                label(title, symbol: symbol)
                Spacer(minLength: 4)
                if let used, let total {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(MetricFormat.number(used, decimals: decimals)).fontWeight(.medium)
                        Text("/ \(MetricFormat.number(total, decimals: 0)) GB")
                            .font(.system(size: 11))
                            .foregroundStyle(reading?.heat == nil ? PanelPalette.secondary : color)
                    }.monospacedDigit().foregroundStyle(color)
                } else { Text("—").foregroundStyle(PanelPalette.secondary) }
            }
            if let percent {
                GeometryReader { geometry in
                    Capsule().fill(PanelPalette.track)
                    Capsule().fill(reading?.heat == nil ? PanelPalette.accent : color)
                        .frame(width: geometry.size.width * min(max(percent / 100, 0), 1))
                }.frame(height: 4).accessibilityHidden(true)
                HStack {
                    Text("\(L10n.tr(.used)) \(MetricFormat.number(percent, decimals: 0))%" +
                         (reading?.heat.map { " · " + L10n.ui($0 >= 1 ? .high : .elevated) } ?? ""))
                        .foregroundStyle(reading?.heat == nil ? PanelPalette.secondary : color)
                    Spacer(minLength: 2)
                    Text("\(L10n.ui(.available)) \(MetricFormat.number(max(0, (total ?? 0) - (used ?? 0)), decimals: decimals)) GB")
                        .foregroundStyle(PanelPalette.secondary)
                }.font(.system(size: 11)).monospacedDigit()
            } else {
                Text(model.note(for: id)).font(.system(size: 11))
                    .foregroundStyle(PanelPalette.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private func sensor(_ id: String, title: String, symbol: String, unit: String, decimals: Int) -> some View {
        let reading = model.readings[id]
        return VStack(alignment: .leading, spacing: 6) {
            label(title, symbol: symbol)
            number(MetricFormat.number(reading?.value?.scalar, decimals: decimals), unit: unit,
                   size: 24, heat: reading?.heat)
            if reading?.value == nil || reading?.heat != nil {
                Text(model.note(for: id)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var network: some View {
        var down: Double?
        var up: Double?
        if case .network(let d, let u) = model.readings["network"]?.value { down = d; up = u }
        return HStack(spacing: 14) {
            speed(down, title: L10n.ui(.download), symbol: "arrow.down")
            Rectangle().fill(PanelPalette.line).frame(width: 1)
            speed(up, title: L10n.ui(.upload), symbol: "arrow.up")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func speed(_ rate: Double?, title: String, symbol: String) -> some View {
        let formatted = MetricFormat.rate(rate)
        return VStack(alignment: .leading, spacing: 4) {
            label(title, symbol: symbol)
            number(formatted.value, unit: formatted.unit, size: 22)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                            .accessibilityLabel("\(L10n.ui(.showInMenu)): \(metric.title)")
                    }
                    .frame(minHeight: 43)
                }
            }
            .padding(.horizontal, 14)
            .background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
            Text(L10n.ui(.configHint)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.tr(.launchAtLogin))
                    Spacer()
                    Toggle(L10n.tr(.launchAtLogin), isOn: Binding(
                        get: { model.loginState == .enabled || model.loginState == .requiresApproval },
                        set: { model.onLogin?($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(PanelPalette.accent)
                }
                Text(loginDescription).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.loginState == .requiresApproval {
                    Button(L10n.ui(.systemSettings)) { LoginItem.openSettings() }
                        .font(.system(size: 11)).buttonStyle(.link)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(PanelPalette.card, in: RoundedRectangle(cornerRadius: 12))
            Text(L10n.ui(.product)).font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                .frame(maxWidth: .infinity).padding(.top, 4)
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
                Button { model.onQuit?() } label: {
                    HStack(spacing: 10) { Text(L10n.tr(.quit)); Text("⌘ Q") }
                }
                .buttonStyle(.plain).keyboardShortcut("q", modifiers: .command)
            }
            .font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
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

    private func number(_ value: String, unit: String, size: CGFloat, heat: Double? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.system(size: size, weight: .medium)).monospacedDigit()
            Text(unit).font(.system(size: 11))
                .foregroundStyle(heat == nil ? PanelPalette.secondary : Color(MetricFormat.heatColor(heat)))
        }
        .foregroundStyle(Color(MetricFormat.heatColor(heat)))
        .lineLimit(1)
    }

    private func banner(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(PanelPalette.tint, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SegmentMeter: View {
    let value: Double
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: 2).fill(PanelPalette.track)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(PanelPalette.accent)
                                .frame(width: max(0, (geometry.size.width - 57) / 20) *
                                       min(max(value / 5 - Double(index), 0), 1))
                        }
                }
            }
        }
    }
}
