#!/usr/bin/env swift
// Generate ReDock app icon — a 2x2 window grid on a blue rounded-rect background
import AppKit

func makeIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    // Background: rounded rect
    let bgRect = NSRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.18, yRadius: size * 0.18)

    let color1 = NSColor(red: 0.20, green: 0.35, blue: 0.70, alpha: 1.0)
    let color2 = NSColor(red: 0.10, green: 0.18, blue: 0.45, alpha: 1.0)
    let gradient = NSGradient(starting: color1, ending: color2)!
    gradient.draw(in: bgPath, angle: 90)

    // Window grid (2x2) — white rounded rects
    NSColor.white.withAlphaComponent(0.92).set()
    let margin = size * 0.24
    let gap = size * 0.06
    let cellW = (size * 0.9 - 2 * (margin - size * 0.05) - gap) / 2
    let cellH = (size * 0.9 - 2 * (margin - size * 0.05) - gap) / 2

    for row in 0..<2 {
        for col in 0..<2 {
            let x = margin + CGFloat(col) * (cellW + gap)
            let y = margin + CGFloat(row) * (cellH + gap)
            let cellRect = NSRect(x: x, y: y, width: cellW, height: cellH)
            let cellPath = NSBezierPath(roundedRect: cellRect, xRadius: size * 0.03, yRadius: size * 0.03)
            cellPath.fill()
        }
    }

    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to create PNG\n", stderr)
        return
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

// Generate iconset
let projectDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let iconsetDir = projectDir.appendingPathComponent("build/ReDock.iconset")
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let icon = makeIcon(size: size)
    savePNG(icon, to: iconsetDir.appendingPathComponent(name).path)
}

print("Iconset generated at \(iconsetDir.path)")
