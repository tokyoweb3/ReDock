import AppKit

/// Centralized coordinate conversion between AppKit and Core Graphics.
///
/// macOS has two coordinate systems:
///   - AppKit (NSScreen): origin at bottom-left of main screen, Y increases upward
///   - Core Graphics / AXUIElement: origin at top-left of main screen, Y increases downward
///
/// MWM uses CG global coordinates internally. All conversion goes through this type.
enum ScreenGeometry {
    /// Convert an AppKit `visibleFrame` to CG global coordinates.
    /// The visibleFrame excludes the menu bar and Dock.
    static func visibleFrameInCG(for screen: NSScreen) -> CGRect {
        appKitToCG(screen.visibleFrame)
    }

    /// Convert an AppKit `frame` (full screen bounds) to CG global coordinates.
    static func frameInCG(for screen: NSScreen) -> CGRect {
        appKitToCG(screen.frame)
    }

    /// Convert any AppKit rect to CG global coordinates.
    static func appKitToCG(_ rect: CGRect) -> CGRect {
        let mainHeight = mainScreenHeight
        return CGRect(
            x: rect.origin.x,
            y: mainHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Convert a CG global rect back to AppKit coordinates.
    static func cgToAppKit(_ rect: CGRect) -> CGRect {
        let mainHeight = mainScreenHeight
        return CGRect(
            x: rect.origin.x,
            y: mainHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Find which NSScreen contains the majority of a CG-coordinate rect.
    static func screen(containing cgRect: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            intersectionArea(frameInCG(for: a), cgRect) < intersectionArea(frameInCG(for: b), cgRect)
        }
    }

    // MARK: - Private

    /// Primary display height (the display at CG origin, always screens[0]).
    /// NSScreen.main changes based on focused window — must NOT be used for coordinate conversion.
    private static var mainScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
