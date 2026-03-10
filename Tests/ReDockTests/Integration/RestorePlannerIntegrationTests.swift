import CoreGraphics
import Foundation
import Testing
@testable import ReDock

/// Integration tests for RestorePlanner → LayoutService flow.
@Suite("Restore planner integration")
struct RestorePlannerIntegrationTests {
    let tempDir: URL

    init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReDockTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("Planner identifies apps to launch and running apps")
    func plannerIdentifiesApps() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = LayoutStore(directory: tempDir)
        let layout = WindowLayout(name: "Multi-App", windows: [
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.finder", appName: "Finder"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.Safari", appName: "Safari"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.Terminal", appName: "Terminal"),
        ])
        try store.save(layout)

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let plan = planner.plan(
            layout: layout,
            runningBundleIDs: ["com.apple.finder"] // Only Finder is running
        )

        #expect(plan.appsAlreadyRunning == ["com.apple.finder"])
        #expect(Set(plan.appsToLaunch) == ["com.apple.Safari", "com.apple.Terminal"])
        #expect(plan.needsLaunch == true)
    }

    @Test("Planner skips fullscreen and minimized windows")
    func plannerSkipsSpecialWindows() {
        let layout = WindowLayout(name: "Mixed", windows: [
            MockWindowQuerying.makeSnapshot(bundleID: "com.app.normal", appName: "Normal"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.app.fs", appName: "FullScreen", wasFullscreen: true),
            MockWindowQuerying.makeSnapshot(bundleID: "com.app.min", appName: "Minimized", isMinimized: true),
        ])

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let plan = planner.plan(layout: layout, runningBundleIDs: ["com.app.normal", "com.app.fs", "com.app.min"])

        #expect(plan.windowsToSkip.count == 2)
        let skipReasons = plan.windowsToSkip.map(\.reason)
        #expect(skipReasons.contains("Was fullscreen"))
        #expect(skipReasons.contains("Was minimized"))
    }

    @Test("All apps running means no launch needed")
    func allAppsRunning() {
        let layout = WindowLayout(name: "All Running", windows: [
            MockWindowQuerying.makeSnapshot(bundleID: "com.a", appName: "A"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.b", appName: "B"),
        ])

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let plan = planner.plan(layout: layout, runningBundleIDs: ["com.a", "com.b"])

        #expect(plan.needsLaunch == false)
        #expect(plan.appsToLaunch.isEmpty)
        #expect(plan.appsAlreadyRunning.count == 2)
    }
}
