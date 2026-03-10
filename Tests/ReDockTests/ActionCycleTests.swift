import Testing
@testable import ReDock

@Suite("Action cycle")
struct ActionCycleTests {
    @Test("Left half cycles through half, two-thirds, one-third")
    func leftHalfSequence() {
        let cycle = ActionCycle.sequence(for: .leftHalf)
        #expect(cycle == [.leftHalf, .leftTwoThirds, .leftThird])
    }

    @Test("Unsupported actions do not cycle")
    func unsupportedActions() {
        #expect(ActionCycle.sequence(for: .maximize) == [.maximize])
    }

    @Test("Resolved third actions have user-facing titles")
    func resolvedActionTitles() {
        #expect(HotkeyManager.displayTitle(for: .leftThird) == "Left Third")
    }
}
