import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let services = AppServices()
    private static let logger = Logger(subsystem: "com.mwm.app", category: "App")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let services = Self.services

        let trusted = services.permissions.check(promptIfNeeded: true)
        Self.logger.info("AX trusted: \(trusted)")

        if trusted {
            onPermissionGranted(services)
        } else {
            services.permissions.pollUntilGranted { [weak self] in
                Self.logger.info("Accessibility permission granted via polling")
                self?.onPermissionGranted(services)
            }
        }
    }

    private func onPermissionGranted(_ services: AppServices) {
        services.hotkeyManager.registerAll()
        services.autoRestoreService.startObserving()
        Self.logger.info("Ready: hotkeys registered, auto-restore active")
    }
}
