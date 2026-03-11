import AppKit
import CoreGraphics

struct StatusBarIconLayout {
    let canvas: CGRect
    let panes: [CGRect]
    let showsOuterFrame: Bool
    let outerPadding: CGFloat
    let paneCornerRadius: CGFloat

    static func threePane(in canvas: CGRect) -> StatusBarIconLayout {
        let outerPadding: CGFloat = 2
        let gutter: CGFloat = 2
        let content = canvas.insetBy(dx: outerPadding, dy: outerPadding)
        let leftWidth = floor((content.width - gutter) * 0.58)
        let rightColumnInset: CGFloat = 1
        let rightWidth = content.width - gutter - leftWidth - rightColumnInset
        let leftVerticalInset: CGFloat = 1
        let rightTopInset: CGFloat = 1
        let rightBottomInset: CGFloat = 1
        let stackAvailableHeight = content.height - rightTopInset - rightBottomInset - gutter
        let stackedHeight = floor(stackAvailableHeight / 2)
        let topHeight = stackedHeight
        let bottomHeight = stackAvailableHeight - topHeight

        let leftPane = CGRect(
            x: content.minX,
            y: content.minY + leftVerticalInset,
            width: leftWidth,
            height: content.height - (leftVerticalInset * 2)
        ).integral

        let bottomRightPane = CGRect(
            x: leftPane.maxX + gutter,
            y: content.minY + rightBottomInset,
            width: rightWidth,
            height: bottomHeight
        ).integral

        let topRightPane = CGRect(
            x: leftPane.maxX + gutter,
            y: bottomRightPane.maxY + gutter,
            width: rightWidth,
            height: topHeight
        ).integral

        return StatusBarIconLayout(
            canvas: canvas,
            panes: [leftPane, topRightPane, bottomRightPane],
            showsOuterFrame: false,
            outerPadding: outerPadding,
            paneCornerRadius: 1.5
        )
    }
}

enum StatusBarIcon {
    static func makeImage(size: CGFloat = 18) -> NSImage {
        let canvas = CGRect(x: 0, y: 0, width: size, height: size)
        let layout = StatusBarIconLayout.threePane(in: canvas)

        let image = NSImage(size: canvas.size)
        image.isTemplate = true
        image.lockFocus()

        NSColor.labelColor.setFill()

        for pane in layout.panes {
            let panePath = NSBezierPath(
                roundedRect: pane,
                xRadius: layout.paneCornerRadius,
                yRadius: layout.paneCornerRadius
            )
            panePath.fill()
        }

        image.unlockFocus()
        return image
    }
}
