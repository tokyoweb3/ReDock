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

    // MARK: - Save

    func saveCurrentLayout(name: String) throws -> WindowLayout {
        let windows = windowQuerying.allVisibleWindows()
        var snapshots: [WindowSnapshot] = []

        for window in windows {
            guard let screen = screenRegistry.screen(containing: window.frame) else { continue }
            let visibleFrame = screenRegistry.visibleFrame(for: screen)
            let fingerprint = DisplayFingerprint.from(screen)
            let relativeFrame = RelativeFrame.from(absoluteFrame: window.frame, visibleFrame: visibleFrame)

            snapshots.append(WindowSnapshot(
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
            ))
        }

        let layout = WindowLayout(name: name, windows: snapshots)
        try store.save(layout)
        Self.logger.info("Saved layout '\(name)' with \(snapshots.count) windows")
        return layout
    }

    // MARK: - Restore

    func restoreLayout(_ layout: WindowLayout) -> RestoreResult {
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
        // Try matching by fingerprint first
        if let screen = screenRegistry.screen(matching: snapshot.display) {
            return screen
        }
        // Fallback to first screen
        return screenRegistry.sortedScreens.first
    }
}
