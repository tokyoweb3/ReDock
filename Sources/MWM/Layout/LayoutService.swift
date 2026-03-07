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
    }

    // MARK: - Snapshot (without saving)

    /// Capture snapshots of all currently visible windows.
    func captureCurrentWindows() -> [WindowSnapshot] {
        let windows = windowQuerying.allVisibleWindows()
        return windows.compactMap { window -> WindowSnapshot? in
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

    func restoreLayout(_ layout: WindowLayout) -> RestoreResult {
        switch layout.mode {
        case .appSpecific:
            return restoreAppSpecific(layout)
        case .template:
            return restoreTemplate(layout)
        }
    }

    /// Traditional restore: match by app bundle ID.
    private func restoreAppSpecific(_ layout: WindowLayout) -> RestoreResult {
        let liveWindows = windowQuerying.allVisibleWindows()
        let matches = WindowMatcher.matchAll(snapshots: layout.windows, candidates: liveWindows)

        var details: [WindowRestoreDetail] = []
        var restored = 0
        var skipped = 0
        let failed = 0

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
                restored += 1
                details.append(WindowRestoreDetail(appName: snapshot.appName, status: .restored))

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
    private func restoreTemplate(_ layout: WindowLayout) -> RestoreResult {
        let liveWindows = windowQuerying.allVisibleWindows()
            .filter { !$0.isMinimized && !$0.isFullscreen }

        let slotCount = layout.windows.count
        let targets = Array(liveWindows.prefix(slotCount))

        var details: [WindowRestoreDetail] = []
        var restored = 0
        var skipped = 0
        let failed = 0

        for (index, snapshot) in layout.windows.enumerated() {
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
            restored += 1
            details.append(WindowRestoreDetail(appName: target.appName, status: .restored))
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
