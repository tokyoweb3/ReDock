import CoreGraphics
import Testing
@testable import ReDock

@Suite("RelativeFrame conversion")
struct RelativeFrameTests {
    let screen = CGRect(x: 0, y: 25, width: 1920, height: 1055)

    @Test("Left half produces correct relative frame")
    func leftHalf() {
        let absolute = CGRect(x: 0, y: 25, width: 960, height: 1055)
        let relative = RelativeFrame.from(absoluteFrame: absolute, visibleFrame: screen)
        #expect(abs(relative.x) < 0.001)
        #expect(abs(relative.y) < 0.001)
        #expect(abs(relative.width - 0.5) < 0.001)
        #expect(abs(relative.height - 1.0) < 0.001)
    }

    @Test("Round-trip conversion preserves frame")
    func roundTrip() {
        let original = CGRect(x: 200, y: 100, width: 800, height: 600)
        let relative = RelativeFrame.from(absoluteFrame: original, visibleFrame: screen)
        let restored = relative.toAbsoluteFrame(in: screen)
        #expect(abs(restored.origin.x - original.origin.x) < 1)
        #expect(abs(restored.origin.y - original.origin.y) < 1)
        #expect(abs(restored.width - original.width) < 1)
        #expect(abs(restored.height - original.height) < 1)
    }

    @Test("Restoration scales to different screen size")
    func scaleToNewScreen() {
        let relative = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1.0)
        let newScreen = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let restored = relative.toAbsoluteFrame(in: newScreen)
        #expect(abs(restored.width - 1280) < 1)
        #expect(abs(restored.height - 1440) < 1)
    }

    @Test("Zero-size screen produces default relative frame")
    func zeroScreen() {
        let absolute = CGRect(x: 100, y: 100, width: 400, height: 300)
        let relative = RelativeFrame.from(absoluteFrame: absolute, visibleFrame: .zero)
        #expect(relative.width == 1)
        #expect(relative.height == 1)
    }
}
