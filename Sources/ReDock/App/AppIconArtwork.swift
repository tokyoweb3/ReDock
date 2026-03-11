import CoreGraphics

struct AppIconPalette {
    let top: SIMD4<Double>
    let middle: SIMD4<Double>
    let bottom: SIMD4<Double>

    static let graphite = AppIconPalette(
        top: SIMD4(0.33, 0.36, 0.42, 1.0),
        middle: SIMD4(0.24, 0.27, 0.33, 1.0),
        bottom: SIMD4(0.12, 0.14, 0.18, 1.0)
    )
}

struct AppIconArtwork {
    let canvas: CGRect
    let backgroundInset: CGFloat
    let backgroundCornerRadiusRatio: CGFloat
    let panes: [CGRect]

    static func threePane(in canvas: CGRect) -> AppIconArtwork {
        let backgroundInset = max(canvas.width * 0.05, canvas.width <= 32 ? 1 : 0)
        let contentInset = max(canvas.width * 0.18, canvas.width <= 32 ? 2 : 0)
        let columnGap = max(canvas.width * 0.05, canvas.width <= 32 ? 2 : 0)
        let rowGap = max(canvas.width * 0.045, canvas.width <= 32 ? 2 : 0)
        let rightInset = max(canvas.width * 0.045, canvas.width <= 32 ? 1 : 0)
        let verticalInset = max(canvas.height * 0.06, canvas.height <= 32 ? 1 : 0)

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
            canvas: canvas,
            backgroundInset: backgroundInset,
            backgroundCornerRadiusRatio: 0.18,
            panes: [leftPane, topRightPane, bottomRightPane]
        )
    }
}
