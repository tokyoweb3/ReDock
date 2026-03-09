import Foundation

enum ActionCycle {
    static func sequence(for action: WindowAction) -> [WindowAction] {
        switch action {
        case .leftHalf:
            return [.leftHalf, .leftTwoThirds, .leftThird]
        case .rightHalf:
            return [.rightHalf, .rightTwoThirds, .rightThird]
        case .topHalf:
            return [.topHalf, .topTwoThirds, .topThird]
        case .bottomHalf:
            return [.bottomHalf, .bottomTwoThirds, .bottomThird]
        default:
            return [action]
        }
    }
}
