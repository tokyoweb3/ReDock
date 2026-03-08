import AppKit
import os

/// Result of attempting to launch apps before restore.
struct AppLaunchResult {
    var launched: [String]
    var activated: [String]
    var alreadyRunning: [String]
    var failed: [String]

    var summary: String {
        var parts: [String] = []
        if !launched.isEmpty { parts.append("\(launched.count) launched") }
        if !activated.isEmpty { parts.append("\(activated.count) activated") }
        if !alreadyRunning.isEmpty { parts.append("\(alreadyRunning.count) already running") }
        if !failed.isEmpty { parts.append("\(failed.count) failed") }
        return parts.joined(separator: ", ")
    }

    var needsWait: Bool { !launched.isEmpty || !activated.isEmpty }
}

/// Launches required apps before layout restoration.
final class AppLaunchService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "AppLaunch")

    private let launchTimeout: TimeInterval

    init(launchTimeout: TimeInterval = 5.0) {
        self.launchTimeout = launchTimeout
    }

    /// Identify which apps from a layout are not currently running.
    func missingApps(for layout: WindowLayout) -> [String] {
        let requiredBundleIDs = Set(layout.windows.map(\.appBundleID))
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications
                .compactMap(\.bundleIdentifier)
        )
        return requiredBundleIDs.subtracting(runningBundleIDs).sorted()
    }

    /// Launch or activate apps needed for a layout, ensuring each app has enough windows.
    func launchMissingApps(for layout: WindowLayout, windows: [WindowSnapshot]? = nil) async -> AppLaunchResult {
        let effectiveWindows = windows ?? layout.windows

        // Count required windows per app
        var neededByApp: [String: Int] = [:]
        for snap in effectiveWindows {
            neededByApp[snap.appBundleID, default: 0] += 1
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let runningByBundleID = Dictionary(
            runningApps.compactMap { app in app.bundleIdentifier.map { ($0, app) } },
            uniquingKeysWith: { first, _ in first }
        )

        var launched: [String] = []
        var activated: [String] = []
        var alreadyRunning: [String] = []
        var failed: [String] = []

        for bundleID in neededByApp.keys.sorted() {
            let needed = neededByApp[bundleID, default: 1]

            if let runningApp = runningByBundleID[bundleID] {
                let pid = runningApp.processIdentifier
                let currentCount = AccessibilityElement(pid: pid).windows.count

                if currentCount >= needed {
                    alreadyRunning.append(bundleID)
                    continue
                }

                // Running but needs windows
                Self.logger.info("Windows \(currentCount, privacy: .public)/\(needed, privacy: .public), activating: \(bundleID, privacy: .public)")
                do {
                    try await openApp(bundleID: bundleID)
                    activated.append(bundleID)
                    // Create additional windows if still not enough
                    await createWindowsIfNeeded(pid: pid, needed: needed)
                } catch {
                    failed.append(bundleID)
                    Self.logger.warning("Failed to activate \(bundleID, privacy: .public): \(error, privacy: .public)")
                }
            } else {
                // Not running — launch
                Self.logger.info("Launching: \(bundleID, privacy: .public)")
                do {
                    try await openApp(bundleID: bundleID)
                    launched.append(bundleID)
                    // Create additional windows if needed
                    if needed > 1, let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                        await createWindowsIfNeeded(pid: app.processIdentifier, needed: needed)
                    }
                } catch {
                    failed.append(bundleID)
                    Self.logger.warning("Failed to launch \(bundleID, privacy: .public): \(error, privacy: .public)")
                }
            }
        }

        let result = AppLaunchResult(launched: launched, activated: activated, alreadyRunning: alreadyRunning, failed: failed)
        Self.logger.info("App launch: \(result.summary, privacy: .public)")
        return result
    }

    // MARK: - Private

    /// Open an app and wait for at least one window to appear.
    private func openApp(bundleID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw AppLaunchError.appNotFound(bundleID)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        let app = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        await waitForWindowCount(pid: app.processIdentifier, minimum: 1)
    }

    /// Create additional windows until the app has `needed` count, using "New Window" menu item.
    private func createWindowsIfNeeded(pid: pid_t, needed: Int) async {
        let appElement = AccessibilityElement(pid: pid)
        var current = appElement.windows.count

        while current < needed {
            guard pressNewWindowMenuItem(pid: pid) else {
                Self.logger.info("No 'New Window' menu item found, stopping at \(current, privacy: .public)/\(needed, privacy: .public)")
                break
            }

            let reached = await waitForWindowCount(pid: pid, minimum: current + 1)
            let updated = AccessibilityElement(pid: pid).windows.count
            if !reached || updated <= current {
                Self.logger.info("New window did not appear, stopping at \(updated, privacy: .public)/\(needed, privacy: .public)")
                break
            }
            current = updated
        }
    }

    /// Wait until an app has at least `minimum` windows.
    @discardableResult
    private func waitForWindowCount(pid: pid_t, minimum: Int) async -> Bool {
        let deadline = Date().addingTimeInterval(launchTimeout)
        while Date() < deadline {
            if AccessibilityElement(pid: pid).windows.count >= minimum {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return false
    }

    /// Find and press "New Window" in the app's menu bar.
    /// Handles submenu parents (e.g. Terminal: Shell → New Window → [profiles]).
    private func pressNewWindowMenuItem(pid: pid_t) -> Bool {
        let app = AccessibilityElement(pid: pid)
        guard let menuBar: AXUIElement = app.attribute(kAXMenuBarAttribute),
              let menus: [AXUIElement] = AccessibilityElement(menuBar).attribute(kAXChildrenAttribute) else {
            return false
        }

        let newWindowPatterns = [
            "new window", "新規ウインドウ", "新規ウィンドウ",
            "neues fenster", "nouvelle fenêtre", "nueva ventana",
            "새 윈도우", "新建窗口", "新增視窗"
        ]

        for menu in menus {
            guard let items = submenuItems(of: menu) else { continue }

            for item in items {
                guard let title: String = AccessibilityElement(item).attribute(kAXTitleAttribute) else { continue }
                let lower = title.lowercased()
                guard newWindowPatterns.contains(where: { lower.contains($0) }) else { continue }

                // If item is a submenu parent (e.g. Terminal profiles), press first child
                if let children = submenuItems(of: item), let first = children.first {
                    AXUIElementPerformAction(first, kAXPressAction as CFString)
                } else {
                    AXUIElementPerformAction(item, kAXPressAction as CFString)
                }
                return true
            }
        }
        return false
    }

    /// Get menu items from a menu/menu-bar-item's submenu.
    private func submenuItems(of menuItem: AXUIElement) -> [AXUIElement]? {
        guard let children: [AXUIElement] = AccessibilityElement(menuItem).attribute(kAXChildrenAttribute),
              let submenu = children.first else { return nil }
        return AccessibilityElement(submenu).attribute(kAXChildrenAttribute)
    }
}

enum AppLaunchError: LocalizedError {
    case appNotFound(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let bundleID):
            return "Application not found: \(bundleID)"
        }
    }
}
