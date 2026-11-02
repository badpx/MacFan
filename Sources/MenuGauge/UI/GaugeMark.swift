import AppKit
import SwiftUI

/// The bundled application icon, the same image the quit confirmation shows.
struct AppIconGlyph: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Crop of the menu bar with the real status-item gauge called out.
/// The glyph is `StatusGaugeImage`, not a separate drawing. Decorative:
/// the card title and body carry the explanation.
struct MenuBarHintArt: View {
    /// Fixed sample so the hint does not animate. Two segments and the
    /// midpoint needle are enough to read as the live menu-bar gauge.
    static let gaugeKey = StatusGaugeImage.Key(segments: 2, step: 12, dimmed: false)
    static let artSize = CGSize(width: 144, height: 86)
    /// Horizontal middle of the menu-bar sample. The arrow tip uses this x.
    static var ringCenter: CGPoint { CGPoint(x: artSize.width / 2, y: 26) }
    static let ringDiameter: CGFloat = 36
    /// The hint art keeps the light-mode treatment in both appearances: a
    /// pale sample card with a dark gauge reads clearly on the dark surface.
    static let highlight = Color(red: 14.0 / 255.0, green: 124.0 / 255.0, blue: 134.0 / 255.0)
    private static let artStart = Color(red: 211.0 / 255.0, green: 240.0 / 255.0, blue: 243.0 / 255.0)
    private static let artEnd = Color(red: 231.0 / 255.0, green: 232.0 / 255.0, blue: 251.0 / 255.0)
    private static let artInk = Color(red: 24.0 / 255.0, green: 32.0 / 255.0, blue: 36.0 / 255.0)

    /// Just outside the ring, under its center. The tail sits a short way
    /// below-left, the same offset the left-hand gauge used, so the curve
    /// stays short and nearly straight. The control point shares the tip’s
    /// x, so the head still meets the ring from below.
    static var arrowTip: CGPoint {
        CGPoint(x: ringCenter.x, y: ringCenter.y + ringDiameter / 2 + 3)
    }
    static let arrowTailOffset = CGPoint(x: -16, y: 31)
    static var arrowTail: CGPoint {
        CGPoint(x: arrowTip.x + arrowTailOffset.x, y: arrowTip.y + arrowTailOffset.y)
    }
    static var arrowControl: CGPoint { CGPoint(x: arrowTip.x, y: arrowTip.y + 17) }

    private var gaugeImage: NSImage {
        StatusGaugeImage.paintedImage(
            for: Self.gaugeKey,
            color: NSColor(srgbRed: 24.0 / 255.0, green: 32.0 / 255.0, blue: 36.0 / 255.0, alpha: 1))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Self.artStart, Self.artEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
            CalloutArrow()
                .stroke(Self.highlight, style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round))
                .frame(width: Self.artSize.width, height: Self.artSize.height)
            ZStack {
                Circle()
                    .stroke(Self.highlight, lineWidth: 2)
                    .frame(width: Self.ringDiameter, height: Self.ringDiameter)
                Image(nsImage: gaugeImage)
            }
            .position(Self.ringCenter)
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.system(size: 9, weight: .semibold))
                Text("9:41")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Self.artInk)
            .position(x: Self.ringCenter.x + Self.ringDiameter / 2 + 26, y: Self.ringCenter.y)
        }
        .frame(width: Self.artSize.width, height: Self.artSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

/// Arrow in the art’s own coordinates (origin top-left, y downward).
private struct CalloutArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = MenuBarHintArt.arrowTip
        let control = MenuBarHintArt.arrowControl
        var path = Path()
        path.move(to: MenuBarHintArt.arrowTail)
        path.addQuadCurve(to: tip, control: control)
        let along = CGPoint(x: tip.x - control.x, y: tip.y - control.y)
        let length = max(0.001, hypot(along.x, along.y))
        let ux = along.x / length
        let uy = along.y / length
        let px = -uy
        let py = ux
        let head: CGFloat = 7
        let base = CGPoint(x: tip.x - ux * head, y: tip.y - uy * head)
        path.move(to: CGPoint(x: base.x + px * head * 0.75, y: base.y + py * head * 0.75))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: base.x - px * head * 0.75, y: base.y - py * head * 0.75))
        return path
    }
}
