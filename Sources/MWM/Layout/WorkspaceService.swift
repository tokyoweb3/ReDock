import AppKit
import os

/// Applies workspace presets to the current set of visible windows.
/// Uses template-style positioning: assigns slots to the N most recently used windows.
final class WorkspaceService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "Workspace")

    private let windowQuerying: WindowQuerying
    private let screenRegistry: ScreenRegistry
    private let focusModeService: FocusModeService
    private let diagnosticsService: DiagnosticsService

    init(
        windowQuerying: WindowQuerying,
        screenRegistry: ScreenRegistry,
        focusModeService: FocusModeService,
        diagnosticsService: DiagnosticsService
    ) {
        self.windowQuerying = windowQuerying
        self.screenRegistry = screenRegistry
        self.focusModeService = focusModeService
        self.diagnosticsService = diagnosticsService
    }

    /// Apply a workspace preset to the current windows.
    @discardableResult
    func apply(_ preset: WorkspacePreset) -> RestoreResult {
        let liveWindows = windowQuerying.allVisibleWindows()
            .filter { !$0.isMinimized && !$0.isFullscreen }

        let slots = preset.slots
        let targets = Array(liveWindows.prefix(slots.count))

        guard let primaryScreen = screenRegistry.sortedScreens.first else {
            Self.logger.warning("No screens available for workspace preset")
            return RestoreResult(layoutName: preset.displayName, restored: 0, skipped: 0, failed: 1, details: [
                WindowRestoreDetail(appName: "System", status: .failed(reason: "No display available"))
            ])
        }

        let visibleFrame = screenRegistry.visibleFrame(for: primaryScreen)

        var details: [WindowRestoreDetail] = []
        var restored = 0
        var skipped = 0
        var failed = 0

        for (index, slot) in slots.enumerated() {
            guard index < targets.count else {
                skipped += 1
                details.append(WindowRestoreDetail(
                    appName: "Slot: \(slot.label)",
                    status: .skipped(reason: "Not enough open windows")
                ))
                continue
            }

            let target = targets[index]
            let absoluteFrame = slot.frame.toAbsoluteFrame(in: visibleFrame)
            target.element.setFrame(absoluteFrame)

            // Post-verification
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

        // Handle Zen mode
        if preset.enablesZenMode && !focusModeService.isActive {
            focusModeService.toggle()
        } else if !preset.enablesZenMode && focusModeService.isActive {
            focusModeService.toggle()
        }

        let result = RestoreResult(
            layoutName: "Workspace: \(preset.displayName)",
            restored: restored,
            skipped: skipped,
            failed: failed,
            details: details
        )

        diagnosticsService.record(result: result, triggerSource: "workspace-\(preset.rawValue)")
        Self.logger.info("Applied workspace '\(preset.rawValue)': \(result.summary)")

        return result
    }
}
