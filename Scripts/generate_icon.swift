import AppKit

// Generates the MacFan app icon: a squircle with a blue gradient
// background and a white five-blade fan, at every size required
// for an .iconset. Usage: swift Scripts/generate_icon.swift <outdir>

let size: CGFloat = 1024
let bladeCount = 3

func drawIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // Background: squircle with a diagonal blue gradient.
    let inset = size * 0.0
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: size * 0.2237, yRadius: size * 0.2237)
    ctx.saveGState()
    squircle.addClip()
    let colors = [
        NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.98, alpha: 1).cgColor, // top-left light blue
        NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.75, alpha: 1).cgColor, // bottom-right deep blue
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0),
                           options: [])

    let center = CGPoint(x: size / 2, y: size / 2)
    let hubRadius = size * 0.085
    let S = size

    // Blades: comma-shaped, narrow at the hub and sweeping counter-clockwise.
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
    for i in 0..<bladeCount {
        ctx.saveGState()
        ctx.rotate(by: CGFloat(i) * 2 * .pi / CGFloat(bladeCount))

        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 0.06 * S, y: 0.015 * S))
        // Outer edge: flares out and sweeps up (counter-clockwise).
        blade.addCurve(to: CGPoint(x: 0.20 * S, y: 0.30 * S),
                       control1: CGPoint(x: 0.26 * S, y: -0.02 * S),
                       control2: CGPoint(x: 0.33 * S, y: 0.10 * S))
        // Rounded tip.
        blade.addCurve(to: CGPoint(x: 0.045 * S, y: 0.27 * S),
                       control1: CGPoint(x: 0.155 * S, y: 0.385 * S),
                       control2: CGPoint(x: 0.05 * S, y: 0.35 * S))
        // Inner edge back toward the hub.
        blade.addQuadCurve(to: CGPoint(x: 0.06 * S, y: 0.015 * S),
                           control: CGPoint(x: -0.01 * S, y: 0.14 * S))
        blade.closeSubpath()
        ctx.addPath(blade)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Hub: solid circle with a small center dot.
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius,
                               width: hubRadius * 2, height: hubRadius * 2))
    ctx.setFillColor(NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.88, alpha: 1).cgColor)
    let dot = hubRadius * 0.45
    ctx.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot,
                               width: dot * 2, height: dot * 2))

    ctx.restoreGState() // squircle clip
    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, pixelSize: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixelSize,
                               pixelsHigh: pixelSize,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let outdir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outdir)
try! fm.createDirectory(atPath: outdir, withIntermediateDirectories: true)

let icon = drawIcon()
// iconset naming: icon_16x16.png, icon_16x16@2x.png (32px), ...
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in specs {
    savePNG(icon, pixelSize: px, to: URL(fileURLWithPath: outdir).appendingPathComponent(name))
}
// Preview for visual inspection.
savePNG(icon, pixelSize: 1024, to: URL(fileURLWithPath: "build/icon_preview.png"))
print("iconset written to \(outdir)")
