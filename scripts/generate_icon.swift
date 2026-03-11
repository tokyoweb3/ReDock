#!/usr/bin/env swift
// Generate ReDock app icon — graphite rounded background with a dominant left pane and stacked right panes.
import AppKit

struct AppIconArtwork {
    let backgroundRect: CGRect
    let backgroundCornerRadius: CGFloat
    let panes: [CGRect]

    static func threePane(size: CGFloat) -> AppIconArtwork {
        let canvas = CGRect(x: 0, y: 0, width: size, height: size)
        let backgroundInset = max(size * 0.05, size <= 32 ? 1 : 0)
        let contentInset = max(size * 0.18, size <= 32 ? 2 : 0)
        let columnGap = max(size * 0.05, size <= 32 ? 2 : 0)
        let rowGap = max(size * 0.045, size <= 32 ? 2 : 0)
        let rightInset = max(size * 0.045, size <= 32 ? 1 : 0)
        let verticalInset = max(size * 0.06, size <= 32 ? 1 : 0)

        let content = canvas.insetBy(dx: contentInset, dy: contentInset)
        let leftWidth = floor((content.width - columnGap - rightInset) * 0.6)
        let rightWidth = content.width - columnGap - leftWidth - rightInset
        let leftHeight = content.height - (verticalInset * 2)
        let stackHeight = content.height - (verticalInset * 2) - rowGap
        let topHeight = floor(stackHeight * 0.5)
        let bottomHeight = stackHeight - topHeight

        let leftPane = CGRect(
            x: content.minX,
            y: content.minY + verticalInset,
            width: leftWidth,
            height: leftHeight
        ).integral

        let bottomRightPane = CGRect(
            x: leftPane.maxX + columnGap,
            y: content.minY + verticalInset,
            width: rightWidth,
            height: bottomHeight
        ).integral

        let topRightPane = CGRect(
            x: leftPane.maxX + columnGap,
            y: bottomRightPane.maxY + rowGap,
            width: rightWidth,
            height: topHeight
        ).integral

        return AppIconArtwork(
            backgroundRect: canvas.insetBy(dx: backgroundInset, dy: backgroundInset),
            backgroundCornerRadius: size * 0.18,
            panes: [leftPane, topRightPane, bottomRightPane]
        )
    }
}

func makeIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let artwork = AppIconArtwork.threePane(size: size)
    let bgPath = NSBezierPath(
        roundedRect: artwork.backgroundRect,
        xRadius: artwork.backgroundCornerRadius,
        yRadius: artwork.backgroundCornerRadius
    )

    let color1 = NSColor(red: 0.33, green: 0.36, blue: 0.42, alpha: 1.0)
    let color2 = NSColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)
    let gradient = NSGradient(colorsAndLocations:
        (color1, 0.0),
        (NSColor(red: 0.24, green: 0.27, blue: 0.33, alpha: 1.0), 0.45),
        (color2, 1.0)
    )!
    gradient.draw(in: bgPath, angle: 90)

    NSColor.white.withAlphaComponent(0.96).setFill()
    for pane in artwork.panes {
        let panePath = NSBezierPath(
            roundedRect: pane,
            xRadius: size * 0.04,
            yRadius: size * 0.04
        )
        panePath.fill()
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
