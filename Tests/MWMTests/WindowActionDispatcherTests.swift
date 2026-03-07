import CoreGraphics
import Testing
@testable import MWM

/// Fake WindowManaging for testing dispatcher routing.
final class FakeWindowManager: WindowManaging {
    private(set) var executedActions: [WindowAction] = []

    func execute(_ action: WindowAction) {
        executedActions.append(action)
    }
}

/// Fake PermissionsChecking for testing permission gating.
final class FakePermissions: PermissionsChecking {
    var isGranted: Bool = true
    var didOpenSettings = false

    func openSystemSettings() {
        didOpenSettings = true
    }
}

@Suite("WindowActionDispatcher")
struct WindowActionDispatcherTests {
    @Test("Dispatches action to window manager when permission is granted")
    func dispatchWithPermission() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let dispatcher = WindowActionDispatcher(permissions: permissions, windowManager: wm)

        dispatcher.dispatch(.leftHalf)
        dispatcher.dispatch(.maximize)

        #expect(wm.executedActions == [.leftHalf, .maximize])
    }

    @Test("Blocks action and opens settings when permission is not granted")
    func dispatchWithoutPermission() {
        let permissions = FakePermissions()
        permissions.isGranted = false
        let wm = FakeWindowManager()
        let dispatcher = WindowActionDispatcher(permissions: permissions, windowManager: wm)

        dispatcher.dispatch(.center)

        #expect(wm.executedActions.isEmpty)
        #expect(permissions.didOpenSettings)
    }

    @Test("All window actions have a display name")
    func allActionsHaveDisplayName() {
        for action in WindowAction.allCases {
            #expect(!action.displayName.isEmpty, "Missing displayName for \(action.rawValue)")
        }
    }

    @Test("Multiple actions dispatch in order")
    func dispatchOrder() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let dispatcher = WindowActionDispatcher(permissions: permissions, windowManager: wm)

        let actions: [WindowAction] = [.topLeft, .bottomRight, .center, .nextScreen]
        for action in actions {
            dispatcher.dispatch(action)
        }

        #expect(wm.executedActions == actions)
    }
}
