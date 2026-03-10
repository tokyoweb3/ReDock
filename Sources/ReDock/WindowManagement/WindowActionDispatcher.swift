import Foundation
import os

/// Unified entry point for all window actions.
/// Both hotkeys and menu items route through here.
final class WindowActionDispatcher {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "Dispatcher")

    private let permissions: PermissionsChecking
    private let windowManager: WindowManaging
    private let cycleState: ActionCycleState
    private let now: () -> Date

    init(
        permissions: PermissionsChecking,
        windowManager: WindowManaging,
        cycleState: ActionCycleState = ActionCycleState(),
        now: @escaping () -> Date = Date.init
    ) {
        self.permissions = permissions
        self.windowManager = windowManager
        self.cycleState = cycleState
        self.now = now
    }

    @discardableResult
    func dispatch(_ action: WindowAction) -> WindowAction? {
        guard permissions.isGranted else {
            Self.logger.warning("Action \(action.rawValue) blocked: accessibility permission not granted")
            permissions.openSystemSettings()
            return nil
        }

        let resolvedAction = cycleState.resolve(action, now: now())
        Self.logger.debug("Dispatching action: \(resolvedAction.rawValue)")
        windowManager.execute(resolvedAction)
        return resolvedAction
    }
}
