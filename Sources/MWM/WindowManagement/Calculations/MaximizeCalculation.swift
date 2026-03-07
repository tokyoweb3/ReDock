import Foundation

/// Maximize the window to fill the entire visible screen area.
struct MaximizeCalculation: WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect {
        params.visibleFrame
    }
}
