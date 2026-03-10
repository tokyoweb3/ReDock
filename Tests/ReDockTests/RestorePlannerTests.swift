import CoreGraphics
import Foundation
import Testing
@testable import ReDock

@Suite("RestorePlanner")
struct RestorePlannerTests {
    func makeSnapshot(bundleID: String, appName: String, minimized: Bool = false, fullscreen: Bool = false) -> WindowSnapshot {
        WindowSnapshot(
            id: UUID(),
            appBundleID: bundleID,
            appName: appName,
            title: nil,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1),
            display: DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            isMinimized: minimized,
            wasFullscreen: fullscreen
        )
    }

    @Test("Identifies missing apps to launch")
    func identifiesMissingApps() {
        let layout = WindowLayout(name: "Test", windows: [
            makeSnapshot(bundleID: "com.apple.finder", appName: "Finder"),
            makeSnapshot(bundleID: "com.apple.safari", appName: "Safari"),
            makeSnapshot(bundleID: "com.apple.notes", appName: "Notes"),
        ])

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let running: Set<String> = ["com.apple.finder"]
        let plan = planner.plan(layout: layout, runningBundleIDs: running)

        #expect(plan.appsToLaunch.count == 2)
        #expect(plan.appsAlreadyRunning == ["com.apple.finder"])
        #expect(plan.needsLaunch)
    }

    @Test("All apps running means no launch needed")
    func allRunning() {
        let layout = WindowLayout(name: "Test", windows: [
            makeSnapshot(bundleID: "com.apple.finder", appName: "Finder"),
        ])

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let running: Set<String> = ["com.apple.finder"]
        let plan = planner.plan(layout: layout, runningBundleIDs: running)

        #expect(plan.appsToLaunch.isEmpty)
        #expect(!plan.needsLaunch)
    }

    @Test("Identifies fullscreen and minimized windows to skip")
    func identifiesSkippableWindows() {
        let layout = WindowLayout(name: "Test", windows: [
            makeSnapshot(bundleID: "com.apple.finder", appName: "Finder"),
            makeSnapshot(bundleID: "com.apple.safari", appName: "Safari", minimized: true),
            makeSnapshot(bundleID: "com.apple.notes", appName: "Notes", fullscreen: true),
        ])

        let planner = RestorePlanner(appLaunchService: AppLaunchService())
        let plan = planner.plan(layout: layout, runningBundleIDs: [])

        #expect(plan.windowsToSkip.count == 2)
        #expect(plan.windowsToSkip.contains { $0.reason == "Was fullscreen" })
        #expect(plan.windowsToSkip.contains { $0.reason == "Was minimized" })
    }
}
