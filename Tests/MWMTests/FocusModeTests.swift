import CoreGraphics
import Testing
@testable import MWM

@Suite("FocusSession state")
struct FocusModeTests {
    @Test("FocusSession stores hidden app bundle IDs")
    func sessionState() {
        let session = FocusSession(
            focusedAppBundleID: "com.apple.Safari",
            focusedWindowTitle: "GitHub",
            originalFrame: CGRect(x: 100, y: 100, width: 800, height: 600),
            hiddenAppBundleIDs: ["com.apple.finder", "com.apple.Terminal"]
        )

        #expect(session.focusedAppBundleID == "com.apple.Safari")
        #expect(session.hiddenAppBundleIDs.count == 2)
        #expect(session.originalFrame != nil)
    }

    @Test("FocusModeService starts inactive")
    func initialState() {
        let service = FocusModeService(screenRegistry: ScreenRegistry())
        #expect(!service.isActive)
        #expect(service.session == nil)
    }
}
