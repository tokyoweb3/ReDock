import Foundation

/// Increase or decrease window size by a step while keeping it centered.
struct ResizeCalculation: WindowCalculation {
    private let stepRatio: CGFloat = 0.05

    func calculate(_ params: CalculationParameters) -> CGRect {
        let screen = params.visibleFrame
        let window = params.windowFrame

        let multiplier: CGFloat = params.action == .increase ? 1 : -1
        let widthDelta = floor(screen.width * stepRatio) * multiplier
        let heightDelta = floor(screen.height * stepRatio) * multiplier

        let newWidth = max(100, min(screen.width, window.width + widthDelta))
        let newHeight = max(100, min(screen.height, window.height + heightDelta))

        let xShift = (newWidth - window.width) / 2
        let yShift = (newHeight - window.height) / 2

        var newFrame = CGRect(
            x: window.origin.x - xShift,
            y: window.origin.y - yShift,
            width: newWidth,
            height: newHeight
        )

        // Clamp to screen bounds
        newFrame.origin.x = max(screen.origin.x, min(newFrame.origin.x, screen.maxX - newFrame.width))
        newFrame.origin.y = max(screen.origin.y, min(newFrame.origin.y, screen.maxY - newFrame.height))

        return newFrame
    }
}
