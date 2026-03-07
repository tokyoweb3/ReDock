import ServiceManagement
import os

/// Manages "Launch at Login" via SMAppService (macOS 13+).
enum LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Launch at Login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at Login disabled")
            }
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") Launch at Login: \(error.localizedDescription)")
        }
    }
}
