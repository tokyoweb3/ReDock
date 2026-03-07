import Foundation

/// Result of attempting to match a WindowSnapshot to a live window.
enum MatchResult {
    case matched(WindowInfo, score: Int)
    case skipped(reason: String)
}

/// Scores and matches saved WindowSnapshots to live windows.
/// Uses best-effort matching: bundleID -> role/subrole -> title -> rect distance.
enum WindowMatcher {
    /// Match a single snapshot against a list of candidate windows.
    static func match(snapshot: WindowSnapshot, candidates: [WindowInfo]) -> MatchResult {
        let sameBundleID = candidates.filter { $0.appBundleID == snapshot.appBundleID }

        guard !sameBundleID.isEmpty else {
            return .skipped(reason: "App '\(snapshot.appName)' (\(snapshot.appBundleID)) is not running")
        }

        let standardWindows = sameBundleID.filter { !$0.isMinimized && !$0.isFullscreen }

        guard !standardWindows.isEmpty else {
            return .skipped(reason: "App '\(snapshot.appName)' has no standard windows")
        }

        let scored = standardWindows.map { window in
            (window, score(snapshot: snapshot, window: window))
        }

        guard let best = scored.max(by: { $0.1 < $1.1 }) else {
            return .skipped(reason: "No matching window found for '\(snapshot.appName)'")
        }

        return .matched(best.0, score: best.1)
    }

    /// Match all snapshots in a layout against live windows.
    /// Each live window can only be matched once.
    static func matchAll(snapshots: [WindowSnapshot], candidates: [WindowInfo]) -> [(WindowSnapshot, MatchResult)] {
        var remainingCandidates = candidates
        var results: [(WindowSnapshot, MatchResult)] = []

        for snapshot in snapshots {
            let result = match(snapshot: snapshot, candidates: remainingCandidates)
            results.append((snapshot, result))

            if case .matched(let matched, _) = result {
                remainingCandidates.removeAll { $0.appBundleID == matched.appBundleID && $0.title == matched.title && $0.frame == matched.frame }
            }
        }

        return results
    }

    // MARK: - Scoring

    /// Score how well a live window matches a saved snapshot.
    /// Higher score = better match.
    static func score(snapshot: WindowSnapshot, window: WindowInfo) -> Int {
        var score = 0

        // Role/subrole match (+20)
        if let snapRole = snapshot.role, snapRole == window.role {
            score += 10
        }
        if let snapSubrole = snapshot.subrole, snapSubrole == window.subrole {
            score += 10
        }

        // Title matching (+30 exact, +15 prefix, +5 contains)
        if let snapTitle = snapshot.title, let windowTitle = window.title {
            if snapTitle == windowTitle {
                score += 30
            } else if windowTitle.hasPrefix(snapTitle) || snapTitle.hasPrefix(windowTitle) {
                score += 15
            } else if windowTitle.contains(snapTitle) || snapTitle.contains(windowTitle) {
                score += 5
            }
        }

        // Frame proximity (+20 max, decreasing with distance)
        let targetFrame = snapshot.relativeFrame
        let screenFrame = ScreenGeometry.screen(containing: window.frame)
            .map { ScreenGeometry.visibleFrameInCG(for: $0) }
            ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let currentRelative = RelativeFrame.from(absoluteFrame: window.frame, visibleFrame: screenFrame)

        let dx = abs(targetFrame.x - currentRelative.x)
        let dy = abs(targetFrame.y - currentRelative.y)
        let dw = abs(targetFrame.width - currentRelative.width)
        let dh = abs(targetFrame.height - currentRelative.height)
        let distance = dx + dy + dw + dh

        let proximityScore = max(0, 20 - Int(distance * 20))
        score += proximityScore

        return score
    }
}
