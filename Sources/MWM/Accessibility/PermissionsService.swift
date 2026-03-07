import AppKit
import ApplicationServices
import os

/// Protocol for permission checking, enabling test fakes.
protocol PermissionsChecking {
    var isGranted: Bool { get }
    func openSystemSettings()
}

/// Manages Accessibility permission lifecycle.
/// Polls for permission when not granted and notifies when it becomes available.
final class PermissionsService: PermissionsChecking {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "Permissions")

    var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Check permission, optionally showing the system prompt.
    func check(promptIfNeeded: Bool = true) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue(): promptIfNeeded
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to the Accessibility pane.
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Poll until permission is granted, then call the completion handler.
    func pollUntilGranted(interval: TimeInterval = 2.0, onGranted: @escaping () -> Void) {
        if isGranted {
            onGranted()
            return
        }

        Self.logger.info("Accessibility permission not granted, polling every \(interval)s")

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if self.isGranted {
                timer.invalidate()
                Self.logger.info("Accessibility permission granted")
                onGranted()
            }
        }
    }
}
