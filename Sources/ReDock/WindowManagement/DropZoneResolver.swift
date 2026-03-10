import CoreGraphics
import Foundation

enum DropZoneResolver {
    private static let horizontalSpacing: CGFloat = 16
    private static let basicZoneSize = CGSize(width: 160, height: 92)
    private static let topInset: CGFloat = 32

    static func basicZones(in screen: CGRect) -> [DropZone] {
        let actions: [WindowAction] = [.leftHalf, .rightHalf, .topHalf, .bottomHalf]
        let totalWidth = CGFloat(actions.count) * basicZoneSize.width + CGFloat(actions.count - 1) * horizontalSpacing
        let originX = screen.midX - totalWidth / 2
        let originY = screen.minY + topInset

        return actions.enumerated().map { index, action in
            let x = originX + CGFloat(index) * (basicZoneSize.width + horizontalSpacing)
            return DropZone(
                id: "basic-\(action.rawValue)",
                frame: CGRect(x: x, y: originY, width: basicZoneSize.width, height: basicZoneSize.height),
                target: .basic(action),
                title: action.displayName
            )
        }
    }

    static func layoutZones(in screen: CGRect, targets: [DropZoneTarget]) -> [DropZone] {
        _ = screen
        _ = targets
        return []
    }

    static func hitTest(point: CGPoint, zones: [DropZone]) -> DropZone? {
        zones.last { $0.frame.contains(point) }
    }
}
