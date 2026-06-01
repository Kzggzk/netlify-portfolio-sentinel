import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetDir = root.appendingPathComponent("assets", isDirectory: true)
let iconset = assetDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

// Redesigned icon: a smaller, cleaner macOS-style squircle (10% canvas margin so
// the tile reads "smaller" and well-padded) with a single brand monogram and one
// subtle uptrend accent. No busy chart/dots/text stack like the first version.
func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    // 10% margin all around -> squircle covers ~80% of the canvas (smaller tile).
    let margin = s * 0.10
    let tile = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = tile.width * 0.2237 // modern macOS superellipse-ish corner

    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    clip.addClip()

    // Brand gradient: teal (top) -> deep navy (bottom).
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.67, blue: 0.61, alpha: 1.0),
        NSColor(calibratedRed: 0.05, green: 0.17, blue: 0.39, alpha: 1.0)
    ])!
    bg.draw(in: tile, angle: -90)

    // Soft top sheen for depth.
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.16),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    sheen.draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)

    // Subtle uptrend accent: a small rising sparkline low in the tile.
    let lime = NSColor(calibratedRed: 0.83, green: 0.98, blue: 0.45, alpha: 1.0)
    let spark = NSBezierPath()
    spark.lineWidth = max(2, tile.width * 0.05)
    spark.lineCapStyle = .round
    spark.lineJoinStyle = .round
    let yBase = tile.minY + tile.height * 0.24
    spark.move(to: NSPoint(x: tile.midX - tile.width * 0.20, y: yBase))
    spark.line(to: NSPoint(x: tile.midX - tile.width * 0.06, y: yBase + tile.height * 0.07))
    spark.line(to: NSPoint(x: tile.midX + tile.width * 0.06, y: yBase + tile.height * 0.02))
    spark.line(to: NSPoint(x: tile.midX + tile.width * 0.20, y: yBase + tile.height * 0.13))
    lime.withAlphaComponent(0.95).setStroke()
    spark.stroke()
    // Endpoint dot.
    let dot = tile.width * 0.06
    lime.setFill()
    NSBezierPath(ovalIn: NSRect(
        x: tile.midX + tile.width * 0.20 - dot / 2,
        y: yBase + tile.height * 0.13 - dot / 2,
        width: dot, height: dot
    )).fill()

    // Centered monogram, well padded above the sparkline.
    let letters = "NF" as NSString
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let font = NSFont.systemFont(ofSize: tile.width * 0.38, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.97),
        .paragraphStyle: para
    ]
    let textSize = letters.size(withAttributes: attrs)
    letters.draw(at: NSPoint(
        x: tile.midX - textSize.width / 2,
        y: tile.midY - textSize.height / 2 + tile.height * 0.08
    ), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return image
}

for (name, size) in sizes {
    let image = drawIcon(size: size)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(name)")
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", assetDir.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

print(assetDir.appendingPathComponent("AppIcon.icns").path)
