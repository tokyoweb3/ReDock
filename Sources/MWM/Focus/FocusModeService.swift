import AppKit
import os

/// Manages Focus Mode: hides all apps except the focused one,
/// centers the focused window, and restores on toggle-off.
final class FocusModeService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "FocusMode")

    private let screenRegistry: ScreenRegistry
    private(set) var session: FocusSession?

    var isActive: Bool { session != nil }

    init(screenRegistry: ScreenRegistry) {
        self.screenRegistry = screenRegistry
    }

    /// Toggle Focus Mode on/off.
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    // MARK: - Private

    private func activate() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let focusedWindow = AccessibilityElement.focusedWindow(),
              let originalFrame = focusedWindow.frame else {
            Self.logger.warning("Cannot activate Focus Mode: no focused window")
            return
        }

        let bundleID = frontApp.bundleIdentifier ?? ""

        // Find apps that are currently visible (not already hidden)
        let appsToHide = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
            && $0.bundleIdentifier != bundleID
            && !$0.isHidden
        }

        let hiddenBundleIDs = appsToHide.compactMap { app -> String? in
            app.hide()
            return app.bundleIdentifier
        }

        // Center the focused window at 75% of screen size
        if let screen = screenRegistry.screen(containing: originalFrame) {
            let visibleFrame = screenRegistry.visibleFrame(for: screen)
            let targetWidth = floor(visibleFrame.width * 0.75)
            let targetHeight = floor(visibleFrame.height * 0.75)
            let centeredFrame = CGRect(
                x: visibleFrame.origin.x + floor((visibleFrame.width - targetWidth) / 2),
                y: visibleFrame.origin.y + floor((visibleFrame.height - targetHeight) / 2),
                width: targetWidth,
                height: targetHeight
            )
            focusedWindow.setFrame(centeredFrame)
        }

        session = FocusSession(
            focusedAppBundleID: bundleID,
            focusedWindowTitle: focusedWindow.title,
            originalFrame: originalFrame,
            hiddenAppBundleIDs: hiddenBundleIDs
        )

        Self.logger.info("Focus Mode activated for '\(frontApp.localizedName ?? bundleID)', hid \(hiddenBundleIDs.count) apps")
    }

    private func deactivate() {
        guard let session else { return }

        // Restore original window frame
        if let originalFrame = session.originalFrame,
           let focusedWindow = AccessibilityElement.focusedWindow() {
            focusedWindow.setFrame(originalFrame)
        }

        // Unhide only the apps that MWM hid
        let runningApps = NSWorkspace.shared.runningApplications
        for bundleID in session.hiddenAppBundleIDs {
            if let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
                app.unhide()
            }
        }

        Self.logger.info("Focus Mode deactivated, unhid \(session.hiddenAppBundleIDs.count) apps")
        self.session = nil
    }
}
