import SwiftUI

/// Small product mark: teal tile, white gauge. Used in the panel header
/// and the About row. The menu-bar status icon is a separate template image.
struct GaugeMark: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvas in
            let rect = CGRect(origin: .zero, size: canvas)
            let tile = Path(roundedRect: rect, cornerRadius: size * 0.22, style: .continuous)
            context.fill(tile, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.071, green: 0.565, blue: 0.478),
                    Color(red: 0.020, green: 0.314, blue: 0.361),
                ]),
                startPoint: CGPoint(x: rect.maxX, y: rect.minY),
                endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
            let hub = CGPoint(x: rect.midX, y: rect.midY + size * 0.02)
            let radius = size * 0.30
            let band = max(1, size * 0.09)
            // Screen angles increase clockwise from the right. The gap sits at the bottom.
            var arc = Path()
            arc.addArc(center: hub, radius: radius,
                       startAngle: .degrees(170), endAngle: .degrees(10), clockwise: true)
            context.stroke(arc, with: .color(.white),
                           style: StrokeStyle(lineWidth: band, lineCap: .round))
            let radians = 38.0 * Double.pi / 180
            let tip = CGPoint(x: hub.x + CGFloat(cos(radians)) * (radius - band),
                              y: hub.y - CGFloat(sin(radians)) * (radius - band))
            var shaft = Path()
            shaft.move(to: hub)
            shaft.addLine(to: tip)
            context.stroke(shaft, with: .color(.white),
                           style: StrokeStyle(lineWidth: band * 0.7, lineCap: .round))
            let hubSize = band * 0.95
            context.fill(Path(ellipseIn: CGRect(x: hub.x - hubSize / 2, y: hub.y - hubSize / 2,
                                                width: hubSize, height: hubSize)),
                         with: .color(.white))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Crop of the menu bar's top-right corner, with the gauge called out.
/// Decorative: the card title and body carry the explanation.
struct MenuBarHintArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.33, green: 0.27, blue: 0.58),
                        Color(red: 0.62, green: 0.36, blue: 0.58),
                        Color(red: 0.95, green: 0.58, blue: 0.42),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.98, green: 0.82, blue: 0.28), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    TemplateGauge(size: 11)
                }
                Image(systemName: "wifi")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
                Text("9:41")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 6)
            .padding(.leading, 12)
            HintArrow()
                .stroke(Color(red: 0.98, green: 0.78, blue: 0.22),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 46, height: 32)
                .offset(x: 4, y: 30)
        }
        .frame(width: 132, height: 74)
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

/// White menu-bar gauge, not the teal app tile. Angles match the status icon:
/// open at the bottom, needle toward the upper right.
private struct TemplateGauge: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let hub = CGPoint(x: canvas.width / 2, y: canvas.height / 2 + 0.5)
            let radius = size * 0.36
            var arc = Path()
            arc.addArc(center: hub, radius: radius,
                       startAngle: .degrees(170), endAngle: .degrees(10), clockwise: true)
            context.stroke(arc, with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            let radians = 38.0 * Double.pi / 180
            let tip = CGPoint(x: hub.x + CGFloat(cos(radians)) * (radius - 1.2),
                              y: hub.y - CGFloat(sin(radians)) * (radius - 1.2))
            var shaft = Path()
            shaft.move(to: hub)
            shaft.addLine(to: tip)
            context.stroke(shaft, with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

private struct HintArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.minX + 22, y: rect.minY + 2)
        path.move(to: CGPoint(x: rect.minX + 6, y: rect.maxY - 2))
        path.addQuadCurve(to: tip, control: CGPoint(x: rect.minX + 2, y: rect.midY))
        path.move(to: CGPoint(x: tip.x - 6, y: tip.y + 5))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x + 6, y: tip.y + 3))
        return path
    }
}
