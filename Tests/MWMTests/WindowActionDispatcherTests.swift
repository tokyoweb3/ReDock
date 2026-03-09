import CoreGraphics
import Foundation
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
    final class TestClock {
        private(set) var current = Date(timeIntervalSince1970: 0)

        func now() -> Date {
            current
        }

        func advance(by interval: TimeInterval) {
            current = current.addingTimeInterval(interval)
        }
    }

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

    @Test("Repeated left half dispatch cycles through placements")
    func repeatedLeftHalfCycles() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let clock = TestClock()
        let dispatcher = WindowActionDispatcher(
            permissions: permissions,
            windowManager: wm,
            cycleState: ActionCycleState(timeout: 1.0),
            now: clock.now
        )

        let first = dispatcher.dispatch(.leftHalf)
        clock.advance(by: 0.1)
        let second = dispatcher.dispatch(.leftHalf)
        clock.advance(by: 0.1)
        let third = dispatcher.dispatch(.leftHalf)

        #expect(first == .leftHalf)
        #expect(second == .leftTwoThirds)
        #expect(third == .leftThird)
        #expect(wm.executedActions == [.leftHalf, .leftTwoThirds, .leftThird])
    }

    @Test("Different action resets the cycle")
    func cycleResetsOnDifferentAction() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let clock = TestClock()
        let dispatcher = WindowActionDispatcher(
            permissions: permissions,
            windowManager: wm,
            cycleState: ActionCycleState(timeout: 1.0),
            now: clock.now
        )

        dispatcher.dispatch(.leftHalf)
        clock.advance(by: 0.1)
        dispatcher.dispatch(.rightHalf)
        clock.advance(by: 0.1)
        dispatcher.dispatch(.leftHalf)

        #expect(wm.executedActions == [.leftHalf, .rightHalf, .leftHalf])
    }

    @Test("Cycle resets after timeout")
    func cycleResetsAfterTimeout() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let clock = TestClock()
        let dispatcher = WindowActionDispatcher(
            permissions: permissions,
            windowManager: wm,
            cycleState: ActionCycleState(timeout: 1.0),
            now: clock.now
        )

        dispatcher.dispatch(.leftHalf)
        clock.advance(by: 1.1)
        dispatcher.dispatch(.leftHalf)

        #expect(wm.executedActions == [.leftHalf, .leftHalf])
    }

    @Test("Cycle timeout can be shortened")
    func cycleUsesInjectedTimeoutProvider() {
        let permissions = FakePermissions()
        let wm = FakeWindowManager()
        let clock = TestClock()
        var timeout = 0.2

        let dispatcher = WindowActionDispatcher(
            permissions: permissions,
            windowManager: wm,
            cycleState: ActionCycleState(timeoutProvider: { timeout }),
            now: clock.now
        )

        dispatcher.dispatch(.leftHalf)
        clock.advance(by: 0.3)
        dispatcher.dispatch(.leftHalf)

        #expect(wm.executedActions == [.leftHalf, .leftHalf])
    }
}
