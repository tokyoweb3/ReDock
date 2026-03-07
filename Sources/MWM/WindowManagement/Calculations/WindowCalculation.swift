import Foundation

/// Parameters for window frame calculation.
struct CalculationParameters {
    let windowFrame: CGRect
    let visibleFrame: CGRect
    let action: WindowAction
}

/// Protocol for window position/size calculations.
/// Each WindowAction has a corresponding calculation (Strategy pattern).
protocol WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect
}
