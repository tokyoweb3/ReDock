import Foundation

/// Returns the appropriate calculation strategy for each WindowAction.
enum CalculationFactory {
    private static let halfCalculation = HalfCalculation()
    private static let fractionCalculation = FractionCalculation()
    private static let quarterCalculation = QuarterCalculation()
    private static let centerCalculation = CenterCalculation()
    private static let maximizeCalculation = MaximizeCalculation()
    private static let resizeCalculation = ResizeCalculation()

    static func calculation(for action: WindowAction) -> WindowCalculation? {
        switch action {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            return halfCalculation
        case .leftThird, .leftTwoThirds, .rightThird, .rightTwoThirds,
                .topThird, .topTwoThirds, .bottomThird, .bottomTwoThirds:
            return fractionCalculation
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return quarterCalculation
        case .center:
            return centerCalculation
        case .maximize:
            return maximizeCalculation
        case .increase, .decrease:
            return resizeCalculation
        case .toggleFullScreen, .nextScreen, .previousScreen:
            return nil
        }
    }
}
