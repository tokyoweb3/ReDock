import Foundation

/// Calculate quarter-screen positions (top-left, top-right, bottom-left, bottom-right).
struct QuarterCalculation: WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect {
        let screen = params.visibleFrame
        let halfWidth = floor(screen.width / 2)
        let halfHeight = floor(screen.height / 2)

        switch params.action {
        case .topLeft:
            return CGRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: halfWidth,
                height: halfHeight
            )
        case .topRight:
            return CGRect(
                x: screen.maxX - halfWidth,
                y: screen.origin.y,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomLeft:
            return CGRect(
                x: screen.origin.x,
                y: screen.maxY - halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomRight:
            return CGRect(
                x: screen.maxX - halfWidth,
                y: screen.maxY - halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        default:
            return params.windowFrame
        }
    }
}
