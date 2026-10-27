import AppKit

// MenuGauge app icon. Keep these in sync with Scripts/render_icon.py.
// Usage: swift Scripts/generate_icon.swift [build/AppIcon.iconset]
//        iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
// Every size is drawn from the vector gauge, not from a scaled 1024 PNG.

let canvas: CGFloat = 1024
let tileOrigin: CGFloat = 96
let tileSide: CGFloat = 832
let tileRadius: CGFloat = 186
let arcStart: CGFloat = 190
let arcSweep: CGFloat = 200
let topGap: CGFloat = 18
let needleDegrees: CGFloat = 37
let glyphWidthRatio: CGFloat = 0.63

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset",
                    isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func bandRatio(pixelSize: Int) -> CGFloat {
    if pixelSize <= 16 { return 0.40 }
    if pixelSize <= 32 { return 0.34 }
    if pixelSize <= 64 { return 0.28 }
    return 0.23
}

func arc(_ path: NSBezierPath, center: CGPoint, radius: CGFloat, from: CGFloat, to: CGFloat) {
    path.appendArc(withCenter: center, radius: radius, startAngle: from, endAngle: to, clockwise: true)
}

func render(pixelSize: Int, fullBleed: Bool = false) throws -> Data {
    let supersample = pixelSize <= 64 ? 4 : 2
    let pixels = pixelSize * supersample
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: pixels, pixelsHigh: pixels,
                                       bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "MenuGaugeIcon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot create icon bitmap"])
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    if fullBleed {
        context.scaleBy(x: canvas / tileSide, y: canvas / tileSide)
        context.translateBy(x: -tileOrigin, y: -tileOrigin)
    }

    let tile = NSRect(x: tileOrigin, y: tileOrigin, width: tileSide, height: tileSide)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tileRadius, yRadius: tileRadius)
    if !fullBleed {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 22,
                          color: color(0x082024).withAlphaComponent(0.25).cgColor)
        color(0x12907A).setFill()
        shape.fill()
        context.restoreGState()
    }
    context.saveGState()
    shape.addClip()
    NSGradient(starting: color(0x12907A), ending: color(0x05505C))!
        .draw(in: tile, angle: -45)
    context.restoreGState()

    let outer = glyphWidthRatio * tileSide / 2
    let band = max(outer * bandRatio(pixelSize: pixelSize), 2 * canvas / CGFloat(pixelSize))
    let centerRadius = outer - band / 2
    let gap: CGFloat = pixelSize <= 32 ? 14 : topGap
    let leftEnd = 90 + gap / 2
    let rightStart = 90 - gap / 2
    let arcEnd = arcStart - arcSweep
    let dip = outer * sin((arcStart - 180) * CGFloat.pi / 180)
    let visualOffset = (outer + (-max(dip, band * 0.35))) / 2
    let hub = CGPoint(x: canvas / 2, y: canvas / 2 - visualOffset)
    let white = NSColor.white
    white.setFill()
    white.setStroke()

    let outlineWidth = max(1.6 * canvas / CGFloat(pixelSize), band * 0.16)
    if pixelSize <= 32 {
        let path = NSBezierPath()
        path.lineWidth = outlineWidth
        path.lineCapStyle = .round
        arc(path, center: hub, radius: centerRadius, from: rightStart, to: arcEnd)
        path.stroke()
    } else {
        let inner = outer - band
        for radius in [outer - outlineWidth / 2, inner + outlineWidth / 2] {
            let path = NSBezierPath()
            path.lineWidth = outlineWidth
            path.lineCapStyle = .round
            arc(path, center: hub, radius: radius, from: rightStart, to: arcEnd)
            path.stroke()
        }
    }

    let filled = NSBezierPath()
    filled.lineWidth = band
    filled.lineCapStyle = .round
    arc(filled, center: hub, radius: centerRadius, from: arcStart, to: leftEnd)
    filled.stroke()

    let radians = needleDegrees * CGFloat.pi / 180
    let direction = CGPoint(x: cos(radians), y: sin(radians))
    let normal = CGPoint(x: -direction.y, y: direction.x)
    let length = (outer - band) * 0.9
    let base = band * (pixelSize <= 32 ? 0.62 : 0.48)
    let tip = CGPoint(x: hub.x + direction.x * length, y: hub.y + direction.y * length)
    let back = CGPoint(x: hub.x - direction.x * band * 0.15, y: hub.y - direction.y * band * 0.15)
    let needle = NSBezierPath()
    needle.move(to: tip)
    needle.line(to: CGPoint(x: back.x + normal.x * base / 2, y: back.y + normal.y * base / 2))
    needle.line(to: CGPoint(x: back.x - normal.x * base / 2, y: back.y - normal.y * base / 2))
    needle.close()
    needle.fill()
    let hubRadius = band * (pixelSize <= 32 ? 0.42 : 0.34)
    NSBezierPath(ovalIn: NSRect(x: hub.x - hubRadius, y: hub.y - hubRadius,
                                width: hubRadius * 2, height: hubRadius * 2)).fill()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MenuGaugeIcon", code: 3)
    }
    if supersample == 1 { return png }
    guard let big = NSImage(data: png),
          let small = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: pixelSize, pixelsHigh: pixelSize,
                                       bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let smallContext = NSGraphicsContext(bitmapImageRep: small) else {
        throw NSError(domain: "MenuGaugeIcon", code: 4)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = smallContext
    big.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
             from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let scaled = small.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MenuGaugeIcon", code: 5)
    }
    return scaled
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in sizes {
    try render(pixelSize: pixels).write(to: directory.appendingPathComponent(name))
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
try render(pixelSize: 1024).write(to: root.appendingPathComponent("Design/MacFan-UI/MenuGauge-AppIcon.png"))
try render(pixelSize: 1024).write(to: directory.deletingLastPathComponent().appendingPathComponent("icon_preview.png"))
try render(pixelSize: 64).write(to: root.appendingPathComponent("website/favicon.png"))
let composerAssets = root.appendingPathComponent("Resources/MenuGaugeFlat.icon/Assets", isDirectory: true)
try FileManager.default.createDirectory(at: composerAssets, withIntermediateDirectories: true)
try render(pixelSize: 1024, fullBleed: true).write(to: composerAssets.appendingPathComponent("Artwork.png"))
print("Iconset: \(directory.path)")
print("Then: iconutil -c icns \(directory.path) -o Resources/AppIcon.icns")
