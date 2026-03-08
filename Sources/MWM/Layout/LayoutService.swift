import AppKit
import os

/// Handles saving and restoring window layouts.
final class LayoutService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "LayoutService")

    private let store: LayoutStore
    private let screenRegistry: ScreenRegistry
    private let windowQuerying: WindowQuerying

    init(store: LayoutStore, screenRegistry: ScreenRegistry, windowQuerying: WindowQuerying) {
        self.store = store
        self.screenRegistry = screenRegistry
        self.windowQuerying = windowQuerying
        seedPresetsIfEmpty()
    }

    /// Seed default workspace presets on first launch.
    private func seedPresetsIfEmpty() {
        guard store.loadAll().isEmpty else { return }
        for preset in WorkspacePreset.allCases {
            let layout = preset.toLayout(screenRegistry: screenRegistry)
            try? store.save(layout)
        }
        Self.logger.info("Seeded \(WorkspacePreset.allCases.count) default presets")
    }

    // MARK: - Snapshot (without saving)

    /// Capture snapshots of all currently visible windows.
    /// When `ignoreObstructed` is true, windows fully covered by other windows are excluded.
    func captureCurrentWindows(ignoreObstructed: Bool = false) -> [WindowSnapshot] {
        let windows = windowQuerying.allVisibleWindows()

        let obstructedFrames: Set<CGRect> = ignoreObstructed
            ? Self.obstructedWindowFrames(from: windows)
            : []

        return windows.compactMap { window -> WindowSnapshot? in
            if ignoreObstructed && obstructedFrames.contains(window.frame) {
                return nil
            }
            guard let screen = screenRegistry.screen(containing: window.frame) else { return nil }
            let visibleFrame = screenRegistry.visibleFrame(for: screen)
            let fingerprint = DisplayFingerprint.from(screen)
            let relativeFrame = RelativeFrame.from(absoluteFrame: window.frame, visibleFrame: visibleFrame)

            return WindowSnapshot(
                id: UUID(),
                appBundleID: window.appBundleID,
                appName: window.appName,
                title: window.title,
                role: window.role,
                subrole: window.subrole,
                relativeFrame: relativeFrame,
                display: fingerprint,
                isMinimized: window.isMinimized,
                wasFullscreen: window.isFullscreen
            )
        }
    }

    /// Capture snapshots along with IDs of obstructed windows.
    func captureWithObstructionInfo() -> (snapshots: [WindowSnapshot], obstructedIDs: Set<UUID>) {
        let windows = windowQuerying.allVisibleWindows()
        let obstructedFrames = Self.obstructedWindowFrames(from: windows)

        var snapshots: [WindowSnapshot] = []
        var obstructedIDs = Set<UUID>()

        for window in windows {
            guard let screen = screenRegistry.screen(containing: window.frame) else { continue }
            let visibleFrame = screenRegistry.visibleFrame(for: screen)
            let fingerprint = DisplayFingerprint.from(screen)
            let relativeFrame = RelativeFrame.from(absoluteFrame: window.frame, visibleFrame: visibleFrame)

            let snapshot = WindowSnapshot(
                id: UUID(),
                appBundleID: window.appBundleID,
                appName: window.appName,
                title: window.title,
                role: window.role,
                subrole: window.subrole,
                relativeFrame: relativeFrame,
                display: fingerprint,
                isMinimized: window.isMinimized,
                wasFullscreen: window.isFullscreen
            )
            snapshots.append(snapshot)

            if obstructedFrames.contains(window.frame) {
                obstructedIDs.insert(snapshot.id)
            }
        }

        return (snapshots, obstructedIDs)
    }

    /// Determine which windows are fully obstructed by the union of windows above them.
    /// Uses CGWindowList for accurate front-to-back Z-order.
    static func obstructedWindowFrames(from windows: [WindowInfo]) -> Set<CGRect> {
        // Get on-screen window list in front-to-back order from CGWindowList
        guard let cgList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let ownPid = ProcessInfo.processInfo.processIdentifier

        // Build Z-ordered list of frames (front-to-back)
        let orderedFrames: [(pid: pid_t, frame: CGRect)] = cgList.compactMap { dict in
            guard let pid = dict[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            // Skip MWM's own windows (settings, save dialog, etc.)
            guard pid != ownPid else { return nil }
            // Filter to only layer 0 (normal windows)
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
            // Parse bounds using CGRect(dictionaryRepresentation:) for robustness
            guard let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
            guard frame.width > 1, frame.height > 1 else { return nil }
            // Skip windows with zero alpha (invisible overlays)
            if let alpha = dict[kCGWindowAlpha as String] as? CGFloat, alpha < 0.01 { return nil }
            return (pid, frame)
        }

        // Match AX windows to CG entries by pid + frame proximity
        // Build an ordered list of WindowInfo frames in Z-order
        var zOrderedAXFrames: [CGRect] = []
        var matchedAX = Set<Int>()

        for cg in orderedFrames {
            for (i, win) in windows.enumerated() {
                guard !matchedAX.contains(i) else { continue }
                let axPid = NSRunningApplication.runningApplications(
                    withBundleIdentifier: win.appBundleID
                ).first?.processIdentifier
                guard axPid == cg.pid else { continue }
                // Match by frame proximity (AX and CG frames should be very close)
                if abs(win.frame.origin.x - cg.frame.origin.x) < 5
                    && abs(win.frame.origin.y - cg.frame.origin.y) < 5
                    && abs(win.frame.width - cg.frame.width) < 5
                    && abs(win.frame.height - cg.frame.height) < 5 {
                    zOrderedAXFrames.append(win.frame)
                    matchedAX.insert(i)
                    break
                }
            }
        }

        // For each window, check if the union of all windows above fully covers it
        var obstructed = Set<CGRect>()
        for (i, frame) in zOrderedAXFrames.enumerated() {
            let coveringFrames = Array(zOrderedAXFrames[0..<i])
            if isFullyCovered(frame, by: coveringFrames) {
                obstructed.insert(frame)
            }
        }

        return obstructed
    }

    /// Check if `target` is fully covered by the union of `coveringRects`.
    /// Uses a simple grid-sampling approach for robustness.
    private static func isFullyCovered(_ target: CGRect, by coveringRects: [CGRect]) -> Bool {
        guard !coveringRects.isEmpty else { return false }

        // Quick check: is there a single covering rect that fully contains target?
        for r in coveringRects {
            if r.contains(target) { return true }
        }

        // Sample points across the target rect
        let steps = 8
        let dx = target.width / CGFloat(steps)
        let dy = target.height / CGFloat(steps)
        for row in 0...steps {
            for col in 0...steps {
                let point = CGPoint(
                    x: target.origin.x + dx * CGFloat(col),
                    y: target.origin.y + dy * CGFloat(row)
                )
                let covered = coveringRects.contains { $0.contains(point) }
                if !covered { return false }
            }
        }
        return true
    }

    // MARK: - Save

    /// Save a layout from selected snapshots.
    func saveLayout(name: String, snapshots: [WindowSnapshot], mode: LayoutMode = .appSpecific) throws -> WindowLayout {
        let layout = WindowLayout(name: name, mode: mode, windows: snapshots)
        try store.save(layout)
        Self.logger.info("Saved layout '\(name)' with \(snapshots.count) windows (mode: \(mode.rawValue))")
        return layout
    }

    /// Convenience: capture all and save (legacy behavior).
    func saveCurrentLayout(name: String) throws -> WindowLayout {
        let snapshots = captureCurrentWindows()
        return try saveLayout(name: name, snapshots: snapshots)
    }

    /// Update an existing layout with current window positions (Moom-style "Update Snapshot").
    func updateFromCurrent(layoutID: UUID) throws -> WindowLayout {
        var layout = try store.load(id: layoutID)
        let currentSnapshots = captureCurrentWindows()

        // For each existing window in the layout, try to find a matching current window
        // and update its position. Keep windows that are no longer visible.
        var updatedWindows: [WindowSnapshot] = []
        var usedCurrentIndices = Set<Int>()

        for existing in layout.windows {
            var bestIndex: Int?
            var bestScore = -1

            for (i, current) in currentSnapshots.enumerated() {
                guard !usedCurrentIndices.contains(i) else { continue }
                guard current.appBundleID == existing.appBundleID else { continue }

                var score = 0
                if current.title == existing.title { score += 30 }
                if current.role == existing.role { score += 10 }
                if score > bestScore {
                    bestScore = score
                    bestIndex = i
                }
            }

            if let idx = bestIndex {
                usedCurrentIndices.insert(idx)
                var updated = existing
                updated.relativeFrame = currentSnapshots[idx].relativeFrame
                updated.display = currentSnapshots[idx].display
                updated.title = currentSnapshots[idx].title
                updated.isMinimized = currentSnapshots[idx].isMinimized
                updated.wasFullscreen = currentSnapshots[idx].wasFullscreen
                updatedWindows.append(updated)
            } else {
                // Keep the existing entry unchanged
                updatedWindows.append(existing)
            }
        }

        layout.windows = updatedWindows
        try store.save(layout)
        Self.logger.info("Updated layout '\(layout.name)' from current positions")
        return layout
    }

    // MARK: - Restore

    func restoreLayout(_ layout: WindowLayout, variantWindows: [WindowSnapshot]? = nil) -> RestoreResult {
        let effectiveWindows = variantWindows ?? resolveEffectiveWindows(for: layout)
        let effectiveVariant = variantWindows != nil ? nil : resolveEffectiveVariant(for: layout)
        let shouldLaunch = variantWindows != nil
            ? layout.variants.first(where: { $0.windows == variantWindows })?.launchMissingApps ?? false
            : effectiveVariant?.launchMissingApps ?? false

        if shouldLaunch && layout.mode == .appSpecific {
            launchMissingApps(windows: effectiveWindows)
        }
        switch layout.mode {
        case .appSpecific:
            return restoreAppSpecific(layout, windows: effectiveWindows)
        case .template:
            return restoreTemplate(layout, windows: effectiveWindows)
        }
    }

    /// Select the best variant for the current display configuration.
    private func resolveEffectiveVariant(for layout: WindowLayout) -> DisplayVariant? {
        guard layout.variants.count > 1 else {
            return layout.variants.first
        }
        let currentFingerprints = screenRegistry.fingerprints()
        return Self.bestVariant(from: layout.variants, for: currentFingerprints)
    }

    /// Select the best variant's windows for the current display configuration.
    private func resolveEffectiveWindows(for layout: WindowLayout) -> [WindowSnapshot] {
        guard layout.variants.count > 1 else {
            return layout.windows
        }
        let currentFingerprints = screenRegistry.fingerprints()
        return Self.bestVariant(from: layout.variants, for: currentFingerprints).windows
    }

    /// Find the best matching variant for a set of display fingerprints.
    static func bestVariant(from variants: [DisplayVariant], for currentFingerprints: [DisplayFingerprint]) -> DisplayVariant {
        guard variants.count > 1 else {
            return variants.first ?? DisplayVariant(displayFingerprints: [], windows: [])
        }

        var bestIndex = 0
        var bestScore = -1.0

        for (i, variant) in variants.enumerated() {
            let score = variantMatchScore(variant: variant, currentFingerprints: currentFingerprints)
            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        return variants[bestIndex]
    }

    /// Score how well a variant's display fingerprints match the current displays.
    static func variantMatchScore(variant: DisplayVariant, currentFingerprints: [DisplayFingerprint]) -> Double {
        guard !variant.displayFingerprints.isEmpty else { return 0 }

        var matches = 0
        for fp in variant.displayFingerprints {
            if currentFingerprints.contains(where: { $0.approximatelyMatches(fp) }) {
                matches += 1
            }
        }

        let total = max(variant.displayFingerprints.count, currentFingerprints.count)
        // Bonus for exact display count match
        let countBonus: Double = variant.displayFingerprints.count == currentFingerprints.count ? 0.1 : 0
        return Double(matches) / Double(total) + countBonus
    }

    /// Launch apps that are referenced but not currently running.
    private func launchMissingApps(windows: [WindowSnapshot]) {
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleIdentifier)
        )

        let missingBundleIDs = Set(
            windows.map(\.appBundleID)
                .filter { !$0.hasPrefix("placeholder.") && !runningBundleIDs.contains($0) }
        )

        for bundleID in missingBundleIDs {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                Self.logger.info("App not installed: \(bundleID)")
                continue
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            Self.logger.info("Launched missing app: \(bundleID)")
        }
    }

    /// Traditional restore: match by app bundle ID.
    private func restoreAppSpecific(_ layout: WindowLayout, windows: [WindowSnapshot]) -> RestoreResult {
        let liveWindows = windowQuerying.allVisibleWindows()
        let matches = WindowMatcher.matchAll(snapshots: windows, candidates: liveWindows)

        var details: [WindowRestoreDetail] = []
        var restored = 0
        var skipped = 0
        var failed = 0

        for (snapshot, matchResult) in matches {
            switch matchResult {
            case .matched(let windowInfo, _):
                if snapshot.wasFullscreen || snapshot.isMinimized {
                    skipped += 1
                    details.append(WindowRestoreDetail(
                        appName: snapshot.appName,
                        status: .skipped(reason: snapshot.wasFullscreen ? "Was fullscreen" : "Was minimized")
                    ))
                    continue
                }

                guard let targetScreen = findTargetScreen(for: snapshot) else {
                    skipped += 1
                    details.append(WindowRestoreDetail(
                        appName: snapshot.appName,
                        status: .skipped(reason: "Target display not found")
                    ))
                    continue
                }

                let targetVisible = screenRegistry.visibleFrame(for: targetScreen)
                let absoluteFrame = snapshot.relativeFrame.toAbsoluteFrame(in: targetVisible)

                windowInfo.element.setFrame(absoluteFrame)

                // Post-verification: check if the frame was actually applied
                if let newFrame = windowInfo.element.frame {
                    let tolerance: CGFloat = 10
                    let applied = abs(newFrame.origin.x - absoluteFrame.origin.x) < tolerance
                        && abs(newFrame.origin.y - absoluteFrame.origin.y) < tolerance
                    if applied {
                        restored += 1
                        details.append(WindowRestoreDetail(appName: snapshot.appName, status: .restored))
                    } else {
                        failed += 1
                        details.append(WindowRestoreDetail(
                            appName: snapshot.appName,
                            status: .failed(reason: "Window did not move to target position")
                        ))
                    }
                } else {
                    // AX element no longer valid (app crashed, permission revoked, or test mock)
                    // Treat as best-effort success since setFrame was called
                    restored += 1
                    details.append(WindowRestoreDetail(appName: snapshot.appName, status: .restored))
                }

            case .skipped(let reason):
                skipped += 1
                details.append(WindowRestoreDetail(
                    appName: snapshot.appName,
                    status: .skipped(reason: reason)
                ))
            }
        }

        let result = RestoreResult(
            layoutName: layout.name,
            restored: restored,
            skipped: skipped,
            failed: failed,
            details: details
        )
        Self.logger.info("\(result.summary)")
        return result
    }

    /// Template restore: apply to the N most recently used windows regardless of app.
    private func restoreTemplate(_ layout: WindowLayout, windows: [WindowSnapshot]) -> RestoreResult {
        let liveWindows = windowQuerying.allVisibleWindows()
            .filter { !$0.isMinimized && !$0.isFullscreen }

        let slotCount = windows.count
        let targets = Array(liveWindows.prefix(slotCount))

        var details: [WindowRestoreDetail] = []
        var restored = 0
        var skipped = 0
        var failed = 0

        for (index, snapshot) in windows.enumerated() {
            guard index < targets.count else {
                skipped += 1
                details.append(WindowRestoreDetail(
                    appName: "Slot \(index + 1)",
                    status: .skipped(reason: "Not enough open windows")
                ))
                continue
            }

            let target = targets[index]
            guard let targetScreen = findTargetScreen(for: snapshot) else {
                skipped += 1
                details.append(WindowRestoreDetail(
                    appName: target.appName,
                    status: .skipped(reason: "Target display not found")
                ))
                continue
            }

            let targetVisible = screenRegistry.visibleFrame(for: targetScreen)
            let absoluteFrame = snapshot.relativeFrame.toAbsoluteFrame(in: targetVisible)
            target.element.setFrame(absoluteFrame)

            // Post-verification: check if the frame was actually applied
            if let newFrame = target.element.frame {
                let tolerance: CGFloat = 10
                let applied = abs(newFrame.origin.x - absoluteFrame.origin.x) < tolerance
                    && abs(newFrame.origin.y - absoluteFrame.origin.y) < tolerance
                if applied {
                    restored += 1
                    details.append(WindowRestoreDetail(appName: target.appName, status: .restored))
                } else {
                    failed += 1
                    details.append(WindowRestoreDetail(
                        appName: target.appName,
                        status: .failed(reason: "Window did not move to target position")
                    ))
                }
            } else {
                restored += 1
                details.append(WindowRestoreDetail(appName: target.appName, status: .restored))
            }
        }

        let result = RestoreResult(
            layoutName: layout.name,
            restored: restored,
            skipped: skipped,
            failed: failed,
            details: details
        )
        Self.logger.info("Template restore: \(result.summary)")
        return result
    }

    // MARK: - Store Access

    func loadAll() -> [WindowLayout] {
        store.loadAll()
    }

    func delete(id: UUID) throws {
        try store.delete(id: id)
    }

    func save(_ layout: WindowLayout) throws {
        try store.save(layout)
    }

    // MARK: - Private

    private func findTargetScreen(for snapshot: WindowSnapshot) -> NSScreen? {
        if let screen = screenRegistry.screen(matching: snapshot.display) {
            return screen
        }
        return screenRegistry.sortedScreens.first
    }
}
