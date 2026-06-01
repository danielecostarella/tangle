#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)
let output = root.appendingPathComponent("build/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for size in sizes {
    let pixels = Int(size.points * size.scale)
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor(red: 0.063, green: 0.094, blue: 0.125, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: CGFloat(pixels) * 0.22, yRadius: CGFloat(pixels) * 0.22).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize = CGFloat(pixels) * 0.46
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let textRect = NSRect(x: 0, y: CGFloat(pixels) * 0.43, width: CGFloat(pixels), height: CGFloat(pixels) * 0.5)
    "T".draw(in: textRect, withAttributes: attributes)

    drawWave(
        in: NSRect(
            x: CGFloat(pixels) * 0.22,
            y: CGFloat(pixels) * 0.28,
            width: CGFloat(pixels) * 0.56,
            height: CGFloat(pixels) * 0.12
        ),
        color: NSColor(red: 0.157, green: 0.839, blue: 0.639, alpha: 1),
        lineWidth: CGFloat(pixels) * 0.055
    )

    drawWave(
        in: NSRect(
            x: CGFloat(pixels) * 0.22,
            y: CGFloat(pixels) * 0.17,
            width: CGFloat(pixels) * 0.56,
            height: CGFloat(pixels) * 0.12
        ),
        color: NSColor(red: 0.345, green: 0.651, blue: 1, alpha: 1),
        lineWidth: CGFloat(pixels) * 0.055
    )

    image.unlockFocus()

    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(size.name)")
    }

    try png.write(to: iconset.appendingPathComponent(size.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

func drawWave(in rect: NSRect, color: NSColor, lineWidth: CGFloat) {
    let path = NSBezierPath()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    color.setStroke()

    path.move(to: NSPoint(x: rect.minX, y: rect.midY))
    path.curve(
        to: NSPoint(x: rect.maxX, y: rect.midY),
        controlPoint1: NSPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY)
    )
    path.stroke()
}
