import AppKit

/// Manages screen enumeration, sorting, and identification.
///
/// Sort order: `minX ASC, minY ASC` (left-to-right, top-to-bottom).
/// This is shared across UI, shortcuts, and layout save/restore.
final class ScreenRegistry {
    /// Sorted screens in CG coordinate order (left-to-right, top-to-bottom).
    var sortedScreens: [NSScreen] {
        NSScreen.screens.sorted { a, b in
            let aFrame = ScreenGeometry.frameInCG(for: a)
            let bFrame = ScreenGeometry.frameInCG(for: b)
            if aFrame.origin.x != bFrame.origin.x {
                return aFrame.origin.x < bFrame.origin.x
            }
            return aFrame.origin.y < bFrame.origin.y
        }
    }

    /// Number of connected displays.
    var displayCount: Int {
        NSScreen.screens.count
    }

    /// Find the screen containing the majority of a CG-coordinate rect.
    func screen(containing cgRect: CGRect) -> NSScreen? {
        ScreenGeometry.screen(containing: cgRect)
    }

    /// Get the visible frame for a screen in CG global coordinates.
    func visibleFrame(for screen: NSScreen) -> CGRect {
        ScreenGeometry.visibleFrameInCG(for: screen)
    }

    /// Get fingerprints for all connected displays.
    func fingerprints() -> [DisplayFingerprint] {
        sortedScreens.map { DisplayFingerprint.from($0) }
    }

    /// Find the next screen in sorted order (wraps around).
    func nextScreen(from current: NSScreen) -> NSScreen? {
        let screens = sortedScreens
        guard screens.count > 1 else { return nil }
        guard let index = screens.firstIndex(of: current) else { return nil }
        return screens[(index + 1) % screens.count]
    }

    /// Find the previous screen in sorted order (wraps around).
    func previousScreen(from current: NSScreen) -> NSScreen? {
        let screens = sortedScreens
        guard screens.count > 1 else { return nil }
        guard let index = screens.firstIndex(of: current) else { return nil }
        return screens[(index - 1 + screens.count) % screens.count]
    }

    /// Find an NSScreen matching a DisplayFingerprint (for layout restore).
    func screen(matching fingerprint: DisplayFingerprint) -> NSScreen? {
        let screens = sortedScreens
        // Exact displayID match first
        if let exact = screens.first(where: {
            DisplayFingerprint.from($0).displayID == fingerprint.displayID && fingerprint.displayID != 0
        }) {
            return exact
        }
        // Approximate match (name + size)
        if let approx = screens.first(where: {
            DisplayFingerprint.from($0).approximatelyMatches(fingerprint)
        }) {
            return approx
        }
        // Fallback: same sorted index position
        return nil
    }
}
