import AppKit

// Match the popover's SF Symbols `fan` silhouette and teal palette.
// Usage: swift Scripts/generate_icon.swift [build/AppIcon.iconset]
//        iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
// Every size is drawn directly from the vector symbol, not a scaled PNG.

let canvas: CGFloat = 1024
let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset",
                    isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func render(pixelSize: Int, fullBleed: Bool = false) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: pixelSize, pixelsHigh: pixelSize,
                                       bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap),
          let symbol = NSImage(systemSymbolName: "fan", accessibilityDescription: "MacFan") else {
        throw NSError(domain: "MacFanIcon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot create fan symbol or bitmap"])
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    context.scaleBy(x: CGFloat(pixelSize) / canvas, y: CGFloat(pixelSize) / canvas)

    // Icon Composer supplies the macOS mask and outer shadow. Expand the
    // existing tile to its canvas; baking in the legacy margins adds a second tile.
    if fullBleed {
        context.scaleBy(x: canvas / 832, y: canvas / 832)
        context.translateBy(x: -96, y: -96)
    }

    // Optical inset aligns the tile with other macOS application icons.
    let tile = NSRect(x: 96, y: 96, width: 832, height: 832)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)
    if !fullBleed {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -9), blur: 20,
                          color: color(0x163E33).withAlphaComponent(0.14).cgColor)
        color(0xE4F2ED).setFill()
        shape.fill()
        context.restoreGState()

        context.saveGState()
        shape.addClip()
        NSGradient(starting: color(0xEDF7F2), ending: color(0xDBEEE5))!
            .draw(in: tile, angle: -90)
        context.restoreGState()

        color(0x147A67).withAlphaComponent(0.10).setStroke()
        let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 1, dy: 1), xRadius: 185, yRadius: 185)
        edge.lineWidth = 2
        edge.stroke()
    } else {
        NSGradient(starting: color(0xEDF7F2), ending: color(0xDBEEE5))!
            .draw(in: tile, angle: -90)
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: 560, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color(0x147A67)]))
    guard let fan = symbol.withSymbolConfiguration(configuration) else {
        throw NSError(domain: "MacFanIcon", code: 2)
    }
    let side: CGFloat = pixelSize <= 32 ? 596 : 572
    let ratio = fan.size.width / fan.size.height
    let width = ratio >= 1 ? side : side * ratio
    let height = ratio >= 1 ? side / ratio : side
    fan.draw(in: NSRect(x: (canvas - width) / 2, y: (canvas - height) / 2,
                       width: width, height: height),
             from: .zero, operation: .sourceOver, fraction: 1)

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MacFanIcon", code: 3)
    }
    return png
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
let preview = directory.deletingLastPathComponent().appendingPathComponent("icon_preview.png")
try render(pixelSize: 1024).write(to: preview)
let composerAssets = URL(fileURLWithPath: "Resources/MacFanFlat.icon/Assets", isDirectory: true)
try FileManager.default.createDirectory(at: composerAssets, withIntermediateDirectories: true)
try render(pixelSize: 1024, fullBleed: true)
    .write(to: composerAssets.appendingPathComponent("Artwork.png"))
print("Iconset: \(directory.path)")
print("Preview: \(preview.path)")
