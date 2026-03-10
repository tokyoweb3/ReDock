import AppKit
import os

final class WindowPlacementService {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "WindowPlacement")

    func apply(target: DropZoneTarget, to window: WindowInfo, on screen: NSScreen) {
        guard window.isResizable else {
            Self.logger.debug("Skipping drop-zone apply for non-resizable window")
            return
        }

        let visibleFrame = ScreenGeometry.visibleFrameInCG(for: screen)
        let frame = Self.targetFrame(for: target, window: window, visibleFrame: visibleFrame)
        window.element.setFrame(frame)
    }

    static func targetFrame(for target: DropZoneTarget, window: WindowInfo, visibleFrame: CGRect) -> CGRect {
        switch target {
        case .basic(let action):
            let params = CalculationParameters(
                windowFrame: window.frame,
                visibleFrame: visibleFrame,
                action: action
            )
            return CalculationFactory.calculation(for: action)?.calculate(params) ?? window.frame
        }
    }
}
