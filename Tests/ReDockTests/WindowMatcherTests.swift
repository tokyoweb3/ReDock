import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import ReDock

@Suite("WindowMatcher scoring")
struct WindowMatcherTests {
    func makeSnapshot(
        bundleID: String = "com.test.app",
        appName: String = "TestApp",
        title: String? = "Document",
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow"
    ) -> WindowSnapshot {
        WindowSnapshot(
            id: UUID(),
            appBundleID: bundleID,
            appName: appName,
            title: title,
            role: role,
            subrole: subrole,
            relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1),
            display: DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            isMinimized: false,
            wasFullscreen: false
        )
    }

    func makeFakeElement() -> AccessibilityElement {
        AccessibilityElement(AXUIElementCreateSystemWide())
    }

    func makeWindowInfo(
        bundleID: String = "com.test.app",
        appName: String = "TestApp",
        title: String? = "Document",
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow",
        frame: CGRect = CGRect(x: 0, y: 0, width: 960, height: 1080)
    ) -> WindowInfo {
        WindowInfo(
            appBundleID: bundleID,
            appName: appName,
            title: title,
            role: role,
            subrole: subrole,
            frame: frame,
            isMinimized: false,
            isFullscreen: false,
            isResizable: true,
            element: makeFakeElement()
        )
    }

    @Test("No candidates returns skipped")
    func noCandidates() {
        let snapshot = makeSnapshot()
        let result = WindowMatcher.match(snapshot: snapshot, candidates: [])
        if case .skipped = result {
            // expected
        } else {
            Issue.record("Expected skipped result")
        }
    }

    @Test("Different bundleID returns skipped")
    func differentBundleID() {
        let snapshot = makeSnapshot(bundleID: "com.test.app")
        let candidate = makeWindowInfo(bundleID: "com.other.app")
        let result = WindowMatcher.match(snapshot: snapshot, candidates: [candidate])
        if case .skipped = result {
            // expected
        } else {
            Issue.record("Expected skipped result")
        }
    }

    @Test("Exact title match scores higher than partial")
    func titleScoring() {
        let snapshot = makeSnapshot(title: "Document.swift")
        let exact = makeWindowInfo(title: "Document.swift")
        let partial = makeWindowInfo(title: "Document.swift - Editor")

        let exactScore = WindowMatcher.score(snapshot: snapshot, window: exact)
        let partialScore = WindowMatcher.score(snapshot: snapshot, window: partial)

        #expect(exactScore > partialScore)
    }

    @Test("Role/subrole match adds score")
    func roleScoring() {
        let snapshot = makeSnapshot(role: "AXWindow", subrole: "AXStandardWindow")
        let matching = makeWindowInfo(role: "AXWindow", subrole: "AXStandardWindow")
        let noRole = makeWindowInfo(role: nil, subrole: nil)

        let matchScore = WindowMatcher.score(snapshot: snapshot, window: matching)
        let noRoleScore = WindowMatcher.score(snapshot: snapshot, window: noRole)

        #expect(matchScore > noRoleScore)
    }

    @Test("matchAll assigns each window only once")
    func matchAllNoDuplicates() {
        let snap1 = makeSnapshot(title: "Window 1")
        let snap2 = makeSnapshot(title: "Window 2")
        let win1 = makeWindowInfo(title: "Window 1")
        let win2 = makeWindowInfo(title: "Window 2")

        let results = WindowMatcher.matchAll(snapshots: [snap1, snap2], candidates: [win1, win2])

        var matchedTitles: [String] = []
        for (_, result) in results {
            if case .matched(let info, _) = result {
                matchedTitles.append(info.title ?? "")
            }
        }
        #expect(matchedTitles.count == 2)
        #expect(Set(matchedTitles).count == 2)
    }
}
