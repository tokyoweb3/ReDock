import AppKit
import os

/// Detects whether Stage Manager is active and provides filtering for staged windows.
enum StageManagerDetector {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "StageManager")

    /// Whether Stage Manager is currently enabled globally.
    static var isEnabled: Bool {
        // Stage Manager setting is stored in com.apple.WindowManager
        // GloballyEnabled = true means Stage Manager is active
        let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        let enabled = defaults?.bool(forKey: "GloballyEnabled") ?? false
        return enabled
    }

    /// Whether Stage Manager is enabled on the built-in display.
    static var isEnabledOnBuiltIn: Bool {
        let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        return defaults?.bool(forKey: "GloballyEnabled") ?? false
    }

    /// Subroles used by Stage Manager for its strip/shelf windows.
    /// These should be excluded from normal window enumeration.
    static let excludedSubroles: Set<String> = [
        "AXUnknown"
    ]

    /// Checks if a window is likely a Stage Manager strip/thumbnail window.
    /// These are small proxy windows shown in the left strip and should be ignored.
    static func isStageManagerStrip(
        subrole: String?,
        frame: CGRect,
        screenBounds: CGRect
    ) -> Bool {
        guard isEnabled else { return false }

        // Stage Manager strip windows are narrow and positioned at the far left
        let stripMaxWidth: CGFloat = 200
        let isNarrow = frame.width < stripMaxWidth
        let isAtLeftEdge = frame.origin.x < screenBounds.origin.x + 10

        // Strip thumbnails are also relatively small vertically
        let isSmall = frame.height < screenBounds.height * 0.3

        return isNarrow && isAtLeftEdge && isSmall
    }

    /// Filters out Stage Manager artifacts from a window list.
    /// Removes strip thumbnails and other Stage Manager UI elements.
    static func filterWindows(_ windows: [WindowInfo], screenBounds: CGRect) -> [WindowInfo] {
        guard isEnabled else { return windows }

        return windows.filter { window in
            // Exclude windows with unknown subrole (Stage Manager artifacts)
            if let subrole = window.subrole, excludedSubroles.contains(subrole) {
                logger.debug("Excluding Stage Manager artifact: \(window.appName) (subrole: \(subrole))")
                return false
            }

            // Exclude strip thumbnail windows
            if isStageManagerStrip(subrole: window.subrole, frame: window.frame, screenBounds: screenBounds) {
                logger.debug("Excluding Stage Manager strip window: \(window.appName)")
                return false
            }

            return true
        }
    }
}
