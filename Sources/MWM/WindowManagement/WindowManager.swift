import AppKit
import os

/// Core window management engine.
/// Coordinates between AccessibilityElement, ScreenRegistry, and Calculations.
final class WindowManager: WindowManaging {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "WindowManager")

    private let screenRegistry: ScreenRegistry

    init(screenRegistry: ScreenRegistry) {
        self.screenRegistry = screenRegistry
    }

    func execute(_ action: WindowAction) {
        switch action {
        case .toggleFullScreen:
            toggleFullScreen()
        case .nextScreen:
            moveToScreen(direction: .next)
        case .previousScreen:
            moveToScreen(direction: .previous)
        default:
            applyCalculation(for: action)
        }
    }

    // MARK: - Private

    private func applyCalculation(for action: WindowAction) {
        guard let window = AccessibilityElement.focusedWindow(),
              let windowFrame = window.frame,
              let screen = screenRegistry.screen(containing: windowFrame) else {
            Self.logger.debug("No focused window or screen found for action: \(action.rawValue)")
            return
        }

        guard window.isResizable else {
            Self.logger.debug("Window is not resizable, skipping action: \(action.rawValue)")
            return
        }

        let visibleFrame = screenRegistry.visibleFrame(for: screen)
        let params = CalculationParameters(
            windowFrame: windowFrame,
            visibleFrame: visibleFrame,
            action: action
        )

        guard let calculation = CalculationFactory.calculation(for: action) else { return }
        let newFrame = calculation.calculate(params)
        window.setFrame(newFrame)
    }

    private func toggleFullScreen() {
        guard let window = AccessibilityElement.focusedWindow() else { return }
        let current: Bool = window.isFullscreen
        window.setAttribute("AXFullScreen", value: (!current) as AnyObject)
    }

    private enum ScreenDirection {
        case next, previous
    }

    private func moveToScreen(direction: ScreenDirection) {
        guard let window = AccessibilityElement.focusedWindow(),
              let windowFrame = window.frame,
              let currentScreen = screenRegistry.screen(containing: windowFrame) else {
            return
        }

        let targetScreen: NSScreen? = switch direction {
        case .next: screenRegistry.nextScreen(from: currentScreen)
        case .previous: screenRegistry.previousScreen(from: currentScreen)
        }

        guard let target = targetScreen else { return }

        let currentVisible = screenRegistry.visibleFrame(for: currentScreen)
        let targetVisible = screenRegistry.visibleFrame(for: target)

        // Preserve relative position and scale proportionally
        let relX = (windowFrame.origin.x - currentVisible.origin.x) / currentVisible.width
        let relY = (windowFrame.origin.y - currentVisible.origin.y) / currentVisible.height
        let relW = windowFrame.width / currentVisible.width
        let relH = windowFrame.height / currentVisible.height

        let newFrame = CGRect(
            x: targetVisible.origin.x + floor(relX * targetVisible.width),
            y: targetVisible.origin.y + floor(relY * targetVisible.height),
            width: floor(relW * targetVisible.width),
            height: floor(relH * targetVisible.height)
        )

        window.setFrame(newFrame)
    }
}
