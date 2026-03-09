import CoreGraphics
import Testing
@testable import MWM

@Suite("Drop zone integration")
struct DropZoneIntegrationTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let mockWindow = MockWindowQuerying.makeWindowInfo(frame: CGRect(x: 100, y: 100, width: 600, height: 500))

    @Test("Basic target applies left half to dragged window")
    func basicTargetPlacement() {
        let frame = WindowPlacementService.targetFrame(
            for: .basic(.leftHalf),
            window: mockWindow,
            visibleFrame: screen
        )
        #expect(frame.width == 720)
        #expect(frame.height == 900)
    }
}
