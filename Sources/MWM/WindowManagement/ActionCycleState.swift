import Foundation

final class ActionCycleState {
    private let timeoutProvider: () -> TimeInterval

    private(set) var lastBaseAction: WindowAction?
    private(set) var lastResolvedIndex = 0
    private(set) var lastTimestamp: Date?

    init(timeout: TimeInterval = 1.0) {
        self.timeoutProvider = { timeout }
    }

    init(timeoutProvider: @escaping () -> TimeInterval) {
        self.timeoutProvider = timeoutProvider
    }

    func resolve(_ action: WindowAction, now: Date) -> WindowAction {
        let sequence = ActionCycle.sequence(for: action)

        guard sequence.count > 1 else {
            reset()
            return action
        }

        let isSameAction = lastBaseAction == action
        let timeout = timeoutProvider()
        let isWithinTimeout = lastTimestamp.map { now.timeIntervalSince($0) <= timeout } ?? false

        if isSameAction && isWithinTimeout {
            lastResolvedIndex = (lastResolvedIndex + 1) % sequence.count
        } else {
            lastBaseAction = action
            lastResolvedIndex = 0
        }

        lastTimestamp = now
        return sequence[lastResolvedIndex]
    }

    private func reset() {
        lastBaseAction = nil
        lastResolvedIndex = 0
        lastTimestamp = nil
    }
}
