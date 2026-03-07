import os

/// Unified entry point for all window actions.
/// Both hotkeys and menu items route through here.
final class WindowActionDispatcher {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "Dispatcher")

    private let permissions: PermissionsChecking
    private let windowManager: WindowManaging

    init(permissions: PermissionsChecking, windowManager: WindowManaging) {
        self.permissions = permissions
        self.windowManager = windowManager
    }

    func dispatch(_ action: WindowAction) {
        guard permissions.isGranted else {
            Self.logger.warning("Action \(action.rawValue) blocked: accessibility permission not granted")
            permissions.openSystemSettings()
            return
        }

        Self.logger.debug("Dispatching action: \(action.rawValue)")
        windowManager.execute(action)
    }
}
