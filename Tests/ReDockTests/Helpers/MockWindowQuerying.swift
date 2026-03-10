import ApplicationServices
import CoreGraphics
import Foundation
@testable import ReDock

/// A fake WindowQuerying that returns pre-configured windows.
/// Used for integration tests without requiring Accessibility permissions.
final class MockWindowQuerying: WindowQuerying {
    var windows: [WindowInfo] = []
    var focused: WindowInfo?

    func allVisibleWindows() -> [WindowInfo] {
        windows
    }

    func focusedWindow() -> WindowInfo? {
        focused
    }

    // MARK: - Helpers

    static func makeFakeElement() -> AccessibilityElement {
        AccessibilityElement(AXUIElementCreateSystemWide())
    }

    static func makeWindowInfo(
        bundleID: String = "com.apple.finder",
        appName: String = "Finder",
        title: String? = "Documents",
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow",
        frame: CGRect = CGRect(x: 0, y: 0, width: 960, height: 1080),
        isMinimized: Bool = false,
        isFullscreen: Bool = false,
        isResizable: Bool = true
    ) -> WindowInfo {
        WindowInfo(
            appBundleID: bundleID,
            appName: appName,
            title: title,
            role: role,
            subrole: subrole,
            frame: frame,
            isMinimized: isMinimized,
            isFullscreen: isFullscreen,
            isResizable: isResizable,
            element: makeFakeElement()
        )
    }

    static func makeSnapshot(
        bundleID: String = "com.apple.finder",
        appName: String = "Finder",
        title: String? = "Documents",
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow",
        relativeFrame: RelativeFrame = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1),
        displayID: UInt32 = 1,
        isMinimized: Bool = false,
        wasFullscreen: Bool = false
    ) -> WindowSnapshot {
        WindowSnapshot(
            id: UUID(),
            appBundleID: bundleID,
            appName: appName,
            title: title,
            role: role,
            subrole: subrole,
            relativeFrame: relativeFrame,
            display: DisplayFingerprint(
                displayID: displayID,
                localizedName: "Main",
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            ),
            isMinimized: isMinimized,
            wasFullscreen: wasFullscreen
        )
    }
}
