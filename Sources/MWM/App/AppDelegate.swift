import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let services = AppServices()
    private static let logger = Logger(subsystem: "com.mwm.app", category: "App")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let services = Self.services

        if services.permissions.check(promptIfNeeded: true) {
            onPermissionGranted(services)
        } else {
            services.permissions.pollUntilGranted { [weak self] in
                self?.onPermissionGranted(services)
            }
        }
    }

    private func onPermissionGranted(_ services: AppServices) {
        services.hotkeyManager.registerAll()
        services.autoRestoreService.startObserving()
        Self.logger.info("MWM ready: hotkeys registered, auto-restore monitoring active")
    }
}
