import CoreGraphics
import Testing
@testable import ReDock

@Suite("Status bar icon")
struct StatusBarIconTests {
    @Test("Three pane icon uses dominant left pane and stacked right panes")
    func threePaneLayout() {
        let layout = StatusBarIconLayout.threePane(in: CGRect(x: 0, y: 0, width: 18, height: 18))

        #expect(layout.canvas == CGRect(x: 0, y: 0, width: 18, height: 18))
        #expect(layout.panes.count == 3)

        let leftPane = layout.panes[0]
        let topRightPane = layout.panes[1]
        let bottomRightPane = layout.panes[2]

        #expect(leftPane.minX == topRightPane.minX - 2 - leftPane.width)
        #expect(leftPane.height > topRightPane.height)
        #expect(topRightPane.width == bottomRightPane.width)
        #expect(topRightPane.minX == bottomRightPane.minX)
        #expect(topRightPane.minY > bottomRightPane.minY)
        #expect(layout.showsOuterFrame == false)
        #expect(layout.outerPadding == 2)
        #expect(layout.paneCornerRadius == 1.5)
        #expect(leftPane.minY > layout.outerPadding)
        #expect(leftPane.maxY < layout.canvas.maxY - layout.outerPadding)
        #expect(topRightPane.maxY < layout.canvas.maxY - layout.outerPadding)
        #expect(bottomRightPane.minY > layout.outerPadding)
        #expect(topRightPane.maxX < layout.canvas.maxX - layout.outerPadding)
        #expect(bottomRightPane.maxX < layout.canvas.maxX - layout.outerPadding)
    }
}
