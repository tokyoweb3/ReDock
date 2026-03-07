import Foundation

/// Calculate half-screen positions (left, right, top, bottom).
struct HalfCalculation: WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect {
        let screen = params.visibleFrame

        switch params.action {
        case .leftHalf:
            return CGRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: floor(screen.width / 2),
                height: screen.height
            )
        case .rightHalf:
            let halfWidth = floor(screen.width / 2)
            return CGRect(
                x: screen.maxX - halfWidth,
                y: screen.origin.y,
                width: halfWidth,
                height: screen.height
            )
        case .topHalf:
            return CGRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width,
                height: floor(screen.height / 2)
            )
        case .bottomHalf:
            let halfHeight = floor(screen.height / 2)
            return CGRect(
                x: screen.origin.x,
                y: screen.maxY - halfHeight,
                width: screen.width,
                height: halfHeight
            )
        default:
            return params.windowFrame
        }
    }
}
