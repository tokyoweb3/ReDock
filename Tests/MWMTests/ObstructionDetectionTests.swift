import CoreGraphics
import Testing
@testable import MWM

@Suite("Obstruction detection")
struct ObstructionDetectionTests {

    // MARK: - isFullyCovered

    @Test("Single covering rect fully contains target")
    func singleCoverFull() {
        let target = CGRect(x: 100, y: 100, width: 200, height: 200)
        let covering = [CGRect(x: 50, y: 50, width: 400, height: 400)]
        let result = LayoutService.obstructedWindowFrames(
            from: windowInfos(frames: covering + [target])
        )
        // target is the second (behind), covering is first (in front)
        #expect(result.contains(target))
    }

    @Test("Partially covered window is NOT obstructed")
    func partiallyCoveredNotObstructed() {
        let front = CGRect(x: 0, y: 0, width: 150, height: 150)
        let back = CGRect(x: 100, y: 100, width: 200, height: 200)
        let result = LayoutService.obstructedWindowFrames(
            from: windowInfos(frames: [front, back])
        )
        #expect(!result.contains(back))
    }

    @Test("Two windows covering target together")
    func twoCoversCombined() {
        let target = CGRect(x: 100, y: 100, width: 200, height: 200)
        let left = CGRect(x: 50, y: 50, width: 200, height: 300)
        let right = CGRect(x: 150, y: 50, width: 200, height: 300)
        // left covers x: 50-250, right covers x: 150-350
        // Together they cover x: 50-350, which fully covers target x: 100-300
        let result = LayoutService.obstructedWindowFrames(
            from: windowInfos(frames: [left, right, target])
        )
        #expect(result.contains(target))
    }

    @Test("No windows means no obstructed")
    func emptyWindows() {
        let result = LayoutService.obstructedWindowFrames(from: [])
        #expect(result.isEmpty)
    }

    @Test("Front window is never obstructed")
    func frontWindowNeverObstructed() {
        let front = CGRect(x: 0, y: 0, width: 300, height: 300)
        let back = CGRect(x: 0, y: 0, width: 300, height: 300)
        let result = LayoutService.obstructedWindowFrames(
            from: windowInfos(frames: [front, back])
        )
        #expect(!result.contains(front))
        #expect(result.contains(back))
    }

    @Test("Non-overlapping windows are not obstructed")
    func nonOverlapping() {
        let left = CGRect(x: 0, y: 0, width: 100, height: 100)
        let right = CGRect(x: 200, y: 0, width: 100, height: 100)
        let result = LayoutService.obstructedWindowFrames(
            from: windowInfos(frames: [left, right])
        )
        #expect(result.isEmpty)
    }

    // MARK: - Helpers

    /// Create WindowInfo array from frames, ordered front-to-back.
    /// Uses a dummy bundle ID with index so CGWindowList matching falls back gracefully.
    /// Since CGWindowListCopyWindowInfo is not available in tests, we test the
    /// isFullyCovered logic directly through obstructedWindowFrames.
    private func windowInfos(frames: [CGRect]) -> [WindowInfo] {
        frames.enumerated().map { (i, frame) in
            WindowInfo(
                appBundleID: "com.test.app\(i)",
                appName: "TestApp\(i)",
                title: "Window \(i)",
                role: "AXWindow",
                subrole: "AXStandardWindow",
                frame: frame,
                isMinimized: false,
                isFullscreen: false,
                isResizable: true,
                element: AccessibilityElement(pid: 0)
            )
        }
    }
}
