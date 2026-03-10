import CoreGraphics
import Foundation
import Testing
@testable import ReDock

@Suite("Stage Manager detection and filtering")
struct StageManagerTests {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("Strip window detection identifies narrow left-edge windows")
    func stripWindowDetection() {
        // A typical Stage Manager strip thumbnail: small, at left edge
        let isStrip = StageManagerDetector.isStageManagerStrip(
            subrole: "AXStandardWindow",
            frame: CGRect(x: 0, y: 200, width: 150, height: 200),
            screenBounds: screenBounds
        )
        // Only detected when Stage Manager is actually enabled
        // In test environment, Stage Manager is likely off
        if StageManagerDetector.isEnabled {
            #expect(isStrip == true)
        } else {
            #expect(isStrip == false)
        }
    }

    @Test("Normal windows are not strip windows")
    func normalWindowNotStrip() {
        let isStrip = StageManagerDetector.isStageManagerStrip(
            subrole: "AXStandardWindow",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            screenBounds: screenBounds
        )
        #expect(isStrip == false)
    }

    @Test("Filter preserves normal windows when Stage Manager is off")
    func filterPreservesNormalWindows() {
        let windows = [
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.one", appName: "One"),
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.two", appName: "Two"),
        ]

        if !StageManagerDetector.isEnabled {
            let filtered = StageManagerDetector.filterWindows(windows, screenBounds: screenBounds)
            #expect(filtered.count == 2)
        }
    }

    @Test("Excluded subroles list contains AXUnknown")
    func excludedSubrolesContainsUnknown() {
        #expect(StageManagerDetector.excludedSubroles.contains("AXUnknown"))
    }

    @Test("Windows with AXUnknown subrole are filtered when Stage Manager is active")
    func unknownSubroleFiltered() {
        let windows = [
            MockWindowQuerying.makeWindowInfo(
                bundleID: "com.app.test", appName: "Test",
                subrole: "AXUnknown",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            ),
            MockWindowQuerying.makeWindowInfo(
                bundleID: "com.app.normal", appName: "Normal",
                subrole: "AXStandardWindow"
            ),
        ]

        if StageManagerDetector.isEnabled {
            let filtered = StageManagerDetector.filterWindows(windows, screenBounds: screenBounds)
            #expect(filtered.count == 1)
            #expect(filtered.first?.appName == "Normal")
        } else {
            // When disabled, all windows pass through
            let filtered = StageManagerDetector.filterWindows(windows, screenBounds: screenBounds)
            #expect(filtered.count == 2)
        }
    }

    @Test("isEnabled reads from com.apple.WindowManager defaults")
    func isEnabledReadsDefaults() {
        // This test verifies the code path runs without crashing.
        // Actual value depends on system state.
        let _ = StageManagerDetector.isEnabled
        let _ = StageManagerDetector.isEnabledOnBuiltIn
    }
}
