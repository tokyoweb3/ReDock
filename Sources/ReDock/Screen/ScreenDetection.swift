import AppKit

/// Convenience facade over ScreenRegistry and ScreenGeometry.
/// Kept for backward compatibility during migration; new code should
/// use ScreenRegistry directly.
enum ScreenDetection {
    private static let registry = ScreenRegistry()

    static func screen(for windowFrame: CGRect) -> NSScreen? {
        registry.screen(containing: windowFrame)
    }

    static func visibleFrame(for screen: NSScreen) -> CGRect {
        registry.visibleFrame(for: screen)
    }

    static func nextScreen(from current: NSScreen) -> NSScreen? {
        registry.nextScreen(from: current)
    }

    static func previousScreen(from current: NSScreen) -> NSScreen? {
        registry.previousScreen(from: current)
    }

    static var sortedScreens: [NSScreen] {
        registry.sortedScreens
    }

    static var displayCount: Int {
        registry.displayCount
    }
}
