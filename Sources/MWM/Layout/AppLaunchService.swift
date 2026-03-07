import AppKit
import os

/// Result of attempting to launch apps before restore.
struct AppLaunchResult {
    var launched: [String]
    var alreadyRunning: [String]
    var failed: [String]

    var summary: String {
        var parts: [String] = []
        if !launched.isEmpty { parts.append("\(launched.count) launched") }
        if !alreadyRunning.isEmpty { parts.append("\(alreadyRunning.count) already running") }
        if !failed.isEmpty { parts.append("\(failed.count) failed") }
        return parts.joined(separator: ", ")
    }
}

/// Launches required apps before layout restoration.
final class AppLaunchService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "AppLaunch")

    /// Default timeout waiting for a single app to launch.
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

        return requiredBundleIDs
            .subtracting(runningBundleIDs)
            .sorted()
    }

    /// Launch all missing apps needed for a layout.
    func launchMissingApps(for layout: WindowLayout) async -> AppLaunchResult {
        let requiredBundleIDs = Set(layout.windows.map(\.appBundleID))
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications
                .compactMap(\.bundleIdentifier)
        )

        var launched: [String] = []
        var alreadyRunning: [String] = []
        var failed: [String] = []

        for bundleID in requiredBundleIDs.sorted() {
            if runningBundleIDs.contains(bundleID) {
                alreadyRunning.append(bundleID)
                continue
            }

            do {
                try await launchApp(bundleID: bundleID)
                launched.append(bundleID)
                Self.logger.info("Launched \(bundleID)")
            } catch {
                failed.append(bundleID)
                Self.logger.warning("Failed to launch \(bundleID): \(error)")
            }
        }

        let result = AppLaunchResult(
            launched: launched,
            alreadyRunning: alreadyRunning,
            failed: failed
        )
        Self.logger.info("App launch: \(result.summary)")
        return result
    }

    // MARK: - Private

    private func launchApp(bundleID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw AppLaunchError.appNotFound(bundleID)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = true

        let app = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)

        // Wait for the app to become responsive
        try await waitForApp(pid: app.processIdentifier)
    }

    private func waitForApp(pid: pid_t) async throws {
        let deadline = Date().addingTimeInterval(launchTimeout)

        while Date() < deadline {
            let appElement = AccessibilityElement(pid: pid)
            if !appElement.windows.isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        // Timeout is not fatal — the app may still be usable without windows yet
        Self.logger.debug("App (pid \(pid)) launched but no windows within timeout")
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
