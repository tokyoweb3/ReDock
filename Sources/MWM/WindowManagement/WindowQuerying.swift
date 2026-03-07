import AppKit

/// Information about a running window, decoupled from AXUIElement.
struct WindowInfo {
    var appBundleID: String
    var appName: String
    var title: String?
    var role: String?
    var subrole: String?
    var frame: CGRect
    var isMinimized: Bool
    var isFullscreen: Bool
    var isResizable: Bool
    var element: AccessibilityElement
}

/// Protocol for querying running windows, enabling test fakes.
protocol WindowQuerying {
    func allVisibleWindows() -> [WindowInfo]
    func focusedWindow() -> WindowInfo?
}

/// Production implementation that queries real AXUIElement windows.
final class LiveWindowQuerying: WindowQuerying {
    func allVisibleWindows() -> [WindowInfo] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        var results: [WindowInfo] = []
        for app in apps {
            let appElement = AccessibilityElement(pid: app.processIdentifier)
            for window in appElement.windows {
                guard let frame = window.frame else { continue }
                results.append(WindowInfo(
                    appBundleID: app.bundleIdentifier ?? "",
                    appName: app.localizedName ?? "",
                    title: window.title,
                    role: window.role,
                    subrole: window.subrole,
                    frame: frame,
                    isMinimized: window.isMinimized,
                    isFullscreen: window.isFullscreen,
                    isResizable: window.isResizable,
                    element: window
                ))
            }
        }
        return results
    }

    func focusedWindow() -> WindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let appElement = AccessibilityElement.focusedApplication(),
              let window = appElement.focusedWindow,
              let frame = window.frame else {
            return nil
        }

        return WindowInfo(
            appBundleID: app.bundleIdentifier ?? "",
            appName: app.localizedName ?? "",
            title: window.title,
            role: window.role,
            subrole: window.subrole,
            frame: frame,
            isMinimized: window.isMinimized,
            isFullscreen: window.isFullscreen,
            isResizable: window.isResizable,
            element: window
        )
    }
}
