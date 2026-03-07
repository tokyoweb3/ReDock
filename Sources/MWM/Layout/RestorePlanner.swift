import Foundation
import os

/// Plan for restoring a layout, including which apps need launching.
struct RestorePlan {
    var layout: WindowLayout
    var appsToLaunch: [String]
    var appsAlreadyRunning: [String]
    var windowsToSkip: [SkipReason]

    var needsLaunch: Bool { !appsToLaunch.isEmpty }

    struct SkipReason {
        var appName: String
        var reason: String
    }
}

/// Plans the restore operation before execution: identifies apps to launch,
/// windows to skip, and creates an actionable restore plan.
final class RestorePlanner {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "RestorePlanner")

    private let appLaunchService: AppLaunchService

    init(appLaunchService: AppLaunchService) {
        self.appLaunchService = appLaunchService
    }

    /// Create a restore plan for a layout given the current running apps.
    func plan(layout: WindowLayout, runningBundleIDs: Set<String>) -> RestorePlan {
        var appsToLaunch: [String] = []
        var appsAlreadyRunning: [String] = []
        var windowsToSkip: [RestorePlan.SkipReason] = []

        let requiredByApp = Dictionary(grouping: layout.windows, by: \.appBundleID)

        for (bundleID, windows) in requiredByApp.sorted(by: { $0.key < $1.key }) {
            let appName = windows.first?.appName ?? bundleID

            if runningBundleIDs.contains(bundleID) {
                appsAlreadyRunning.append(bundleID)
            } else {
                appsToLaunch.append(bundleID)
            }

            for window in windows {
                if window.wasFullscreen {
                    windowsToSkip.append(.init(appName: appName, reason: "Was fullscreen"))
                } else if window.isMinimized {
                    windowsToSkip.append(.init(appName: appName, reason: "Was minimized"))
                }
            }
        }

        let plan = RestorePlan(
            layout: layout,
            appsToLaunch: appsToLaunch,
            appsAlreadyRunning: appsAlreadyRunning,
            windowsToSkip: windowsToSkip
        )

        Self.logger.info("Plan for '\(layout.name)': \(appsToLaunch.count) to launch, \(appsAlreadyRunning.count) running, \(windowsToSkip.count) to skip")
        return plan
    }
}
