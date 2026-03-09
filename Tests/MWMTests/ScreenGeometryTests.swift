import CoreGraphics
import Testing
@testable import MWM

@Suite("ScreenGeometry coordinate conversion")
struct ScreenGeometryTests {
    // Note: These tests validate the math of coordinate conversion.
    // They use a known main screen height to verify the Y-flip formula.
    // In production, ScreenGeometry reads NSScreen.main dynamically.

    @Test("AppKit to CG Y-flip is symmetric")
    func appKitToCGRoundTrip() {
        // Given a rect in AppKit coords
        let appKitRect = CGRect(x: 100, y: 200, width: 800, height: 600)

        // When we convert to CG and back
        let cgRect = ScreenGeometry.appKitToCG(appKitRect)
        let backToAppKit = ScreenGeometry.cgToAppKit(cgRect)

        // Then we get the original rect back
        #expect(abs(backToAppKit.origin.x - appKitRect.origin.x) < 0.01)
        #expect(abs(backToAppKit.origin.y - appKitRect.origin.y) < 0.01)
        #expect(abs(backToAppKit.width - appKitRect.width) < 0.01)
        #expect(abs(backToAppKit.height - appKitRect.height) < 0.01)
    }

    @Test("CG to AppKit Y-flip is symmetric")
    func cgToAppKitRoundTrip() {
        let cgRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let appKitRect = ScreenGeometry.cgToAppKit(cgRect)
        let backToCG = ScreenGeometry.appKitToCG(appKitRect)

        #expect(abs(backToCG.origin.x - cgRect.origin.x) < 0.01)
        #expect(abs(backToCG.origin.y - cgRect.origin.y) < 0.01)
        #expect(abs(backToCG.width - cgRect.width) < 0.01)
        #expect(abs(backToCG.height - cgRect.height) < 0.01)
    }

    @Test("X coordinate is unchanged by conversion")
    func xCoordinatePreserved() {
        let rect = CGRect(x: 300, y: 400, width: 500, height: 300)
        let converted = ScreenGeometry.appKitToCG(rect)
        #expect(converted.origin.x == rect.origin.x)
        #expect(converted.width == rect.width)
        #expect(converted.height == rect.height)
    }

    @Test("Global mouse points convert into CG-space consistently")
    func mousePointConversion() {
        let point = CGPoint(x: 2400, y: 300)
        let converted = ScreenGeometry.globalMousePointToCG(point, mainScreenHeight: 1440)
        #expect(converted.x == 2400)
        #expect(converted.y == 1140)
    }
}
