import CoreGraphics
import Testing
@testable import ReDock

@Suite("WindowDragMonitor")
struct WindowDragMonitorTests {
    @Test("Activation band check uses normalized pointer coordinates")
    func activationBandUsesNormalizedPoint() {
        let visible = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        let point = CGPoint(x: 2500, y: 40)

        #expect(WindowDragMonitor.isWithinActivationBand(point: point, visibleFrame: visible, bandHeight: 96))
    }

    @Test("Meaningful drag requires the window frame to move")
    func meaningfulDragRequiresWindowMotion() {
        let frame = CGRect(x: 100, y: 120, width: 800, height: 600)

        #expect(WindowDragMonitor.isMeaningfulWindowDrag(initialFrame: frame, currentFrame: frame) == false)
        #expect(
            WindowDragMonitor.isMeaningfulWindowDrag(
                initialFrame: frame,
                currentFrame: CGRect(x: 124, y: 120, width: 800, height: 600)
            )
        )
    }

    @Test("Overlay is rehosted when the drag moves to another screen")
    func overlayIsRehostedOnScreenChange() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let external = CGRect(x: 1440, y: 0, width: 2560, height: 1440)

        #expect(WindowDragMonitor.shouldRehostOverlay(currentScreenFrame: nil, nextScreenFrame: primary))
        #expect(WindowDragMonitor.shouldRehostOverlay(currentScreenFrame: primary, nextScreenFrame: external))
        #expect(WindowDragMonitor.shouldRehostOverlay(currentScreenFrame: primary, nextScreenFrame: primary) == false)
    }

    @Test("Activated drop zones stay available while the pointer moves onto a snap target")
    func activatedZonesRemainInteractive() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let zones = DropZoneResolver.basicZones(in: visible)
        let pointInsideZone = CGPoint(x: zones[0].frame.midX, y: zones[0].frame.midY)

        #expect(
            WindowDragMonitor.shouldKeepDropZonesVisible(
                point: pointInsideZone,
                visibleFrame: visible,
                bandHeight: 96,
                zones: zones
            )
        )
    }
}
