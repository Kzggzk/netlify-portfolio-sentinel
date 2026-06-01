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

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.62, blue: 0.56, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.42, alpha: 1)
    ])!
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.08, dy: CGFloat(size) * 0.08), xRadius: CGFloat(size) * 0.20, yRadius: CGFloat(size) * 0.20)
    bg.draw(in: path, angle: 135)

    NSColor.white.withAlphaComponent(0.92).setStroke()
    let line = NSBezierPath()
    line.lineWidth = max(3, CGFloat(size) * 0.045)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: NSPoint(x: CGFloat(size) * 0.22, y: CGFloat(size) * 0.35))
    line.line(to: NSPoint(x: CGFloat(size) * 0.40, y: CGFloat(size) * 0.49))
    line.line(to: NSPoint(x: CGFloat(size) * 0.55, y: CGFloat(size) * 0.43))
    line.line(to: NSPoint(x: CGFloat(size) * 0.78, y: CGFloat(size) * 0.70))
    line.stroke()

    NSColor(calibratedRed: 0.91, green: 0.98, blue: 0.52, alpha: 1).setFill()
    for point in [
        NSPoint(x: CGFloat(size) * 0.22, y: CGFloat(size) * 0.35),
        NSPoint(x: CGFloat(size) * 0.40, y: CGFloat(size) * 0.49),
        NSPoint(x: CGFloat(size) * 0.55, y: CGFloat(size) * 0.43),
        NSPoint(x: CGFloat(size) * 0.78, y: CGFloat(size) * 0.70)
    ] {
        let dotSize = CGFloat(size) * 0.075
        NSBezierPath(ovalIn: NSRect(x: point.x - dotSize / 2, y: point.y - dotSize / 2, width: dotSize, height: dotSize)).fill()
    }

    let letters = "NF" as NSString
    let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.23, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.92)
    ]
    let textSize = letters.size(withAttributes: attrs)
    letters.draw(
        at: NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: CGFloat(size) * 0.17),
        withAttributes: attrs
    )

    image.unlockFocus()
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
