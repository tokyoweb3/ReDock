import CoreGraphics
import Foundation
import Testing
@testable import MWM

@Suite("Layout mode and template")
struct LayoutModeTests {
    func makeSnapshot(bundleID: String = "com.apple.finder", appName: String = "Finder", x: CGFloat = 0, width: CGFloat = 0.5) -> WindowSnapshot {
        WindowSnapshot(
            id: UUID(),
            appBundleID: bundleID,
            appName: appName,
            title: nil,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            relativeFrame: RelativeFrame(x: x, y: 0, width: width, height: 1),
            display: DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            isMinimized: false,
            wasFullscreen: false
        )
    }

    @Test("Default mode is appSpecific")
    func defaultMode() {
        let layout = WindowLayout(name: "Test", windows: [])
        #expect(layout.mode == .appSpecific)
    }

    @Test("Template mode is preserved through encoding")
    func templateModeCodable() throws {
        let layout = WindowLayout(name: "Template", mode: .template, windows: [makeSnapshot()])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(layout)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WindowLayout.self, from: data)

        #expect(decoded.mode == .template)
    }

    @Test("V1 layout without mode field decodes as appSpecific")
    func v1Compatibility() throws {
        // Simulate a v1 JSON without the "mode" field
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "schemaVersion": 1,
            "name": "V1 Layout",
            "autoRestore": false,
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "windows": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let layout = try decoder.decode(WindowLayout.self, from: Data(json.utf8))

        #expect(layout.mode == .appSpecific)
        #expect(layout.name == "V1 Layout")
    }

    @Test("Schema version is 3")
    func schemaVersion() {
        #expect(WindowLayout.currentSchemaVersion == 3)
    }

    @Test("Layout store round-trip with template mode")
    func storeRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let layout = WindowLayout(name: "Template Test", mode: .template, windows: [
            makeSnapshot(x: 0, width: 0.5),
            makeSnapshot(x: 0.5, width: 0.5),
        ])

        try store.save(layout)
        let loaded = try store.load(id: layout.id)

        #expect(loaded.mode == .template)
        #expect(loaded.windows.count == 2)
    }
}
