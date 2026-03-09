import Foundation

struct FractionSpec {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    static func forAction(_ action: WindowAction) -> FractionSpec? {
        switch action {
        case .leftThird:
            return FractionSpec(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        case .leftTwoThirds:
            return FractionSpec(x: 0, y: 0, width: 2.0 / 3.0, height: 1)
        case .rightThird:
            return FractionSpec(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .rightTwoThirds:
            return FractionSpec(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .topThird:
            return FractionSpec(x: 0, y: 0, width: 1, height: 1.0 / 3.0)
        case .topTwoThirds:
            return FractionSpec(x: 0, y: 0, width: 1, height: 2.0 / 3.0)
        case .bottomThird:
            return FractionSpec(x: 0, y: 2.0 / 3.0, width: 1, height: 1.0 / 3.0)
        case .bottomTwoThirds:
            return FractionSpec(x: 0, y: 1.0 / 3.0, width: 1, height: 2.0 / 3.0)
        default:
            return nil
        }
    }
}

final class FractionCalculation: WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect {
        guard let spec = FractionSpec.forAction(params.action) else {
            return params.windowFrame
        }

        let width = floor(params.visibleFrame.width * spec.width)
        let height = floor(params.visibleFrame.height * spec.height)
        let x: CGFloat
        let y: CGFloat

        switch params.action {
        case .rightThird, .rightTwoThirds:
            x = params.visibleFrame.maxX - width
        default:
            x = params.visibleFrame.minX + floor(params.visibleFrame.width * spec.x)
        }

        switch params.action {
        case .bottomThird, .bottomTwoThirds:
            y = params.visibleFrame.maxY - height
        default:
            y = params.visibleFrame.minY + floor(params.visibleFrame.height * spec.y)
        }

        return CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
    }
}
