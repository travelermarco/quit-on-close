// Generates AppIcon.icns from scratch (no external assets/tools beyond
// AppKit + iconutil, both part of the OS). Run with:
//   swift Scripts/generate_icon.swift
//
// Design: a macOS-style rounded square ("squircle") in the same red as the
// traffic-light close button, with a bold white X (the Windows close glyph)
// centered on it - a visual pun on what the app actually does: it makes the
// Mac's red button behave like Windows' X.

import AppKit

func drawIcon(pixelSize: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let size = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.38, alpha: 1.0), // macOS close-button red, lightened
        NSColor(calibratedRed: 0.80, green: 0.12, blue: 0.10, alpha: 1.0)  // deep red
    ])
    ctx.saveGState()
    backgroundPath.addClip()
    gradient?.draw(in: backgroundPath, angle: -90)
    ctx.restoreGState()

    let strokeWidth = size * 0.09
    let inset = size * 0.305
    let xPath = NSBezierPath()
    xPath.lineWidth = strokeWidth
    xPath.lineCapStyle = .round
    xPath.move(to: NSPoint(x: inset, y: inset))
    xPath.line(to: NSPoint(x: size - inset, y: size - inset))
    xPath.move(to: NSPoint(x: size - inset, y: inset))
    xPath.line(to: NSPoint(x: inset, y: size - inset))

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.025,
        color: NSColor.black.withAlphaComponent(0.35).cgColor
    )
    NSColor.white.setStroke()
    xPath.stroke()
    ctx.restoreGState()

    return rep
}

func save(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for \(url.lastPathComponent)")
    }
    try? data.write(to: url)
    print("Wrote \(url.path)")
}

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let mapping: [(name: String, size: Int, scale: Int)] = [
    ("icon_16x16", 16, 1),
    ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1),
    ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1),
    ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1),
    ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1),
    ("icon_512x512@2x", 512, 2),
]

for entry in mapping {
    let pixelSize = entry.size * entry.scale
    let rep = drawIcon(pixelSize: pixelSize)
    save(rep, to: outDir.appendingPathComponent("\(entry.name).png"))
}
