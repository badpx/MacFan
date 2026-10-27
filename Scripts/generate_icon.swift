import AppKit

// MenuGauge app icon. Keep these in sync with Scripts/render_icon.py.
// Usage: swift Scripts/generate_icon.swift [build/AppIcon.iconset]
//        swift Scripts/generate_icon.swift <dir> --iconset-only
//        iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
// Every size is drawn from the vector gauge, not from a scaled 1024 PNG.
//
// Numbers below are pixels of the padded 1024 preview. Full-bleed artwork
// scales them with the tile. Each segment is one annular sector: outer arc,
// semicircular cap, inner arc, semicircular cap. Cap radius is half the band.

let canvas: CGFloat = 1024
let tileOrigin: CGFloat = 96
let tileSide: CGFloat = 832
let tileRadius: CGFloat = 186
let arcStart: CGFloat = 190
let arcEnd: CGFloat = -10
let outerRadius: CGFloat = 310
let bandThickness: CGFloat = 100
let outlineStroke: CGFloat = 23
let segmentGap: CGFloat = 26
let needleDegrees: CGFloat = 38
let needleBaseWidth: CGFloat = 44
let needleTipWidth: CGFloat = 12
let hubRadiusDesign: CGFloat = 40

let args = Array(CommandLine.arguments.dropFirst())
let iconsetOnly = args.contains("--iconset-only")
let directoryPath = args.first { !$0.hasPrefix("-") } ?? "build/AppIcon.iconset"
let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
    let rad = degrees * CGFloat.pi / 180
    return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
}

/// Angle from vertical to each cap center, so the rounded ends sit `gap` apart.
func halfGapDegrees(mid: CGFloat, cap: CGFloat, gap: CGFloat) -> CGFloat {
    let target = gap / 2
    var lo: CGFloat = 0
    var hi: CGFloat = CGFloat.pi / 2.5
    for _ in 0..<48 {
        let midAngle = (lo + hi) / 2
        let opening = mid * sin(midAngle) - cap * cos(midAngle)
        if opening < target { lo = midAngle } else { hi = midAngle }
    }
    return (lo + hi) / 2 * 180 / CGFloat.pi
}

/// Closed annular sector. `start` sweeps clockwise to `end`.
/// Caps are semicircles of radius (outer - inner) / 2, flush with both edges.
func annularSector(center: CGPoint, outer: CGFloat, inner: CGFloat,
                   start: CGFloat, end: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let mid = (outer + inner) / 2
    let cap = (outer - inner) / 2
    path.appendArc(withCenter: center, radius: outer, startAngle: start, endAngle: end, clockwise: true)
    // Clockwise end: semicircle through the outside tangent (end - 90°).
    path.appendArc(withCenter: point(center, mid, end), radius: cap,
                   startAngle: end, endAngle: end + 180, clockwise: true)
    path.appendArc(withCenter: center, radius: inner, startAngle: end, endAngle: start, clockwise: false)
    // Counterclockwise end: semicircle through the outside tangent (start + 90°).
    path.appendArc(withCenter: point(center, mid, start), radius: cap,
                   startAngle: start + 180, endAngle: start, clockwise: true)
    path.close()
    return path
}

func needlePath(length: CGFloat, base: CGFloat, tip: CGFloat) -> NSBezierPath {
    let tipR = tip / 2
    let reach = max(tipR + 0.5, length - tipR)
    let rad = needleDegrees * CGFloat.pi / 180
    let direction = CGPoint(x: cos(rad), y: sin(rad))
    // Side at needleDegrees - 90°. The tip arc runs through needleDegrees.
    let normal = CGPoint(x: sin(rad), y: -cos(rad))
    let tipCenter = CGPoint(x: direction.x * reach, y: direction.y * reach)
    let path = NSBezierPath()
    path.move(to: CGPoint(x: normal.x * base / 2, y: normal.y * base / 2))
    path.appendArc(withCenter: tipCenter, radius: tipR,
                   startAngle: needleDegrees - 90, endAngle: needleDegrees + 90, clockwise: false)
    path.line(to: CGPoint(x: -normal.x * base / 2, y: -normal.y * base / 2))
    path.close()
    return path
}

struct GlyphDesign {
    var outer: CGFloat
    var inner: CGFloat
    var stroke: CGFloat
    var gap: CGFloat
    var hub: CGFloat
    var base: CGFloat
    var tip: CGFloat
    var length: CGFloat
}

func glyphDesign(pixelSize: Int) -> GlyphDesign {
    let floorScale = canvas / CGFloat(pixelSize)
    func atLeast(_ design: CGFloat, _ outputPx: CGFloat) -> CGFloat {
        max(design, outputPx * floorScale)
    }
    var band = bandThickness
    var stroke = outlineStroke
    var gap = segmentGap
    var hub = hubRadiusDesign
    var base = needleBaseWidth
    var tip = needleTipWidth
    if pixelSize <= 16 {
        band = atLeast(band, 3.15)
        stroke = atLeast(stroke, 1.15)
        hub = atLeast(hub, 1.45)
        base = atLeast(base, 1.9)
        tip = atLeast(tip, 1.05)
        gap = atLeast(gap, 1.05)
    } else if pixelSize <= 32 {
        band = atLeast(band, 5.2)
        stroke = atLeast(stroke, 1.7)
        hub = atLeast(hub, 2.4)
        base = atLeast(base, 3.1)
        tip = atLeast(tip, 1.35)
        gap = atLeast(gap, 1.7)
    }
    band = min(band, outerRadius * 0.72)
    stroke = min(stroke, band * 0.38)
    if band - 2 * stroke < stroke * 0.45 { stroke = band / 3 }
    let inner = outerRadius - band
    let length = max(inner * 0.45, inner - 30)
    return GlyphDesign(outer: outerRadius, inner: inner, stroke: stroke, gap: gap,
                       hub: hub, base: base, tip: tip, length: length)
}

func translate(_ path: NSBezierPath, by delta: CGPoint) {
    var transform = AffineTransform()
    transform.translate(x: delta.x, y: delta.y)
    path.transform(using: transform)
}

func drawGlyph(pixelSize: Int) {
    let design = glyphDesign(pixelSize: pixelSize)
    let cap = (design.outer - design.inner) / 2
    let mid = (design.outer + design.inner) / 2
    let beta = halfGapDegrees(mid: mid, cap: cap, gap: design.gap)
    let leftEnd = 90 + beta
    let rightStart = 90 - beta
    let origin = CGPoint.zero
    let filled = annularSector(center: origin, outer: design.outer, inner: design.inner,
                               start: arcStart, end: leftEnd)
    let outlined = annularSector(center: origin, outer: design.outer, inner: design.inner,
                                 start: rightStart, end: arcEnd)
    let hole = annularSector(center: origin, outer: design.outer - design.stroke,
                             inner: design.inner + design.stroke,
                             start: rightStart, end: arcEnd)
    let needle = needlePath(length: design.length, base: design.base, tip: design.tip)
    let hub = NSBezierPath(ovalIn: NSRect(x: -design.hub, y: -design.hub,
                                          width: design.hub * 2, height: design.hub * 2))
    var bounds = filled.bounds
    bounds = bounds.union(outlined.bounds)
    bounds = bounds.union(needle.bounds)
    bounds = bounds.union(hub.bounds)
    let delta = CGPoint(x: canvas / 2 - bounds.midX, y: canvas / 2 - bounds.midY)
    for path in [filled, outlined, hole, needle, hub] {
        translate(path, by: delta)
    }
    let white = NSColor.white
    white.setFill()
    filled.fill()
    // Stroke stays inside the same outer and inner radius as the filled segment.
    outlined.windingRule = .evenOdd
    outlined.append(hole)
    outlined.fill()
    needle.fill()
    hub.fill()
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

    drawGlyph(pixelSize: pixelSize)

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
if iconsetOnly {
    print("Iconset: \(directory.path)")
    exit(0)
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
