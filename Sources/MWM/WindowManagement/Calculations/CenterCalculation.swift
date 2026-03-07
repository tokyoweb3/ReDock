import Foundation

/// Center the window on screen without changing its size.
/// If the window is larger than the screen, it will be shrunk to fit.
struct CenterCalculation: WindowCalculation {
    func calculate(_ params: CalculationParameters) -> CGRect {
        let screen = params.visibleFrame
        let window = params.windowFrame

        let width = min(window.width, screen.width)
        let height = min(window.height, screen.height)

        return CGRect(
            x: screen.origin.x + floor((screen.width - width) / 2),
            y: screen.origin.y + floor((screen.height - height) / 2),
            width: width,
            height: height
        )
    }
}
