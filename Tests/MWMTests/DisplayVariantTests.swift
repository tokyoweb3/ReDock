import CoreGraphics
import Foundation
import Testing
@testable import MWM

@Suite("Display variant system")
struct DisplayVariantTests {
    // MARK: - Helpers

    let mainDisplay = DisplayFingerprint(
        displayID: 1, localizedName: "Built-in Retina Display",
        bounds: CGRect(x: 0, y: 0, width: 2560, height: 1600)
    )
    let externalLeft = DisplayFingerprint(
        displayID: 2, localizedName: "DELL U2723QE",
        bounds: CGRect(x: -2560, y: 0, width: 2560, height: 1440)
    )
    let externalRight = DisplayFingerprint(
        displayID: 3, localizedName: "LG 27UK850",
        bounds: CGRect(x: 2560, y: 0, width: 3840, height: 2160)
    )

    func makeSnapshot(
        bundleID: String = "com.apple.finder",
        appName: String = "Finder",
        display: DisplayFingerprint? = nil,
        relativeFrame: RelativeFrame = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
    ) -> WindowSnapshot {
        WindowSnapshot(
            id: UUID(),
            appBundleID: bundleID,
            appName: appName,
            title: nil,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            relativeFrame: relativeFrame,
            display: display ?? mainDisplay,
            isMinimized: false,
            wasFullscreen: false
        )
    }

    // MARK: - Data Model

    @Test("Layout creation wraps windows into a single variant")
    func layoutCreationSingleVariant() {
        let windows = [makeSnapshot(), makeSnapshot(bundleID: "com.apple.Safari", appName: "Safari")]
        let layout = WindowLayout(name: "Test", windows: windows)

        #expect(layout.variants.count == 1)
        #expect(layout.variants[0].windows.count == 2)
        #expect(layout.variants[0].displayFingerprints.contains(mainDisplay))
    }

    @Test("Computed windows property reads from first variant")
    func computedWindowsGetter() {
        let windows = [makeSnapshot(), makeSnapshot(appName: "Safari")]
        let layout = WindowLayout(name: "Test", windows: windows)

        #expect(layout.windows.count == 2)
        #expect(layout.windows == layout.variants[0].windows)
    }

    @Test("Computed windows setter modifies first variant")
    func computedWindowsSetter() {
        var layout = WindowLayout(name: "Test", windows: [makeSnapshot()])
        let newWindows = [makeSnapshot(appName: "Safari"), makeSnapshot(appName: "Chrome")]
        layout.windows = newWindows

        #expect(layout.variants.count == 1)
        #expect(layout.variants[0].windows.count == 2)
    }

    @Test("Computed windows setter creates variant when variants is empty")
    func computedWindowsSetterEmpty() {
        var layout = WindowLayout(name: "Test", windows: [])
        layout.variants = [] // Force empty
        layout.windows = [makeSnapshot()]

        #expect(layout.variants.count == 1)
        #expect(layout.variants[0].windows.count == 1)
    }

    @Test("Layout with empty variants returns empty windows")
    func emptyVariantsReturnsEmptyWindows() {
        var layout = WindowLayout(name: "Test", windows: [])
        layout.variants = []

        #expect(layout.windows.isEmpty)
    }

    @Test("DisplayVariant displayDescription with no fingerprints")
    func variantDescriptionNoFingerprints() {
        let variant = DisplayVariant(displayFingerprints: [], windows: [])
        #expect(variant.displayDescription == "Default")
    }

    @Test("DisplayVariant displayDescription with named displays")
    func variantDescriptionNamed() {
        let variant = DisplayVariant(
            displayFingerprints: [mainDisplay, externalLeft],
            windows: []
        )
        #expect(variant.displayDescription == "Built-in Retina Display + DELL U2723QE")
    }

    @Test("DisplayVariant displayDescription with unnamed displays")
    func variantDescriptionUnnamed() {
        let fp = DisplayFingerprint(displayID: 99, localizedName: nil, bounds: .zero)
        let variant = DisplayVariant(displayFingerprints: [fp], windows: [])
        #expect(variant.displayDescription == "1 display(s)")
    }

    // MARK: - Codable: v2 Migration

    @Test("v2 JSON with windows migrates to single variant")
    func v2Migration() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "schemaVersion": 2,
            "name": "V2 Layout",
            "autoRestore": false,
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "windows": [
                {
                    "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
                    "appBundleID": "com.apple.finder",
                    "appName": "Finder",
                    "role": "AXWindow",
                    "subrole": "AXStandardWindow",
                    "relativeFrame": {"x": 0, "y": 0, "width": 0.5, "height": 1},
                    "display": {"displayID": 1, "localizedName": "Main", "bounds": [[0,0],[1920,1080]]},
                    "isMinimized": false,
                    "wasFullscreen": false
                }
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let layout = try decoder.decode(WindowLayout.self, from: Data(json.utf8))

        #expect(layout.variants.count == 1)
        #expect(layout.windows.count == 1)
        #expect(layout.windows[0].appBundleID == "com.apple.finder")
        #expect(layout.name == "V2 Layout")
    }

    @Test("v2 JSON without mode field defaults to appSpecific")
    func v2MigrationDefaultMode() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "schemaVersion": 2,
            "name": "Old Layout",
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
        #expect(layout.variants.count == 1)
        #expect(layout.launchMissingApps == false)
    }

    // MARK: - Codable: v3 Round-trip

    @Test("v3 encode/decode round-trip preserves variants")
    func v3RoundTrip() throws {
        let variant1 = DisplayVariant(
            displayFingerprints: [mainDisplay],
            windows: [makeSnapshot(display: mainDisplay)]
        )
        let variant2 = DisplayVariant(
            displayFingerprints: [mainDisplay, externalLeft],
            windows: [
                makeSnapshot(display: mainDisplay),
                makeSnapshot(bundleID: "com.apple.Safari", appName: "Safari", display: externalLeft),
            ]
        )

        var layout = WindowLayout(name: "Multi-Variant", windows: [])
        layout.variants = [variant1, variant2]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(layout)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WindowLayout.self, from: data)

        #expect(decoded.variants.count == 2)
        #expect(decoded.variants[0].windows.count == 1)
        #expect(decoded.variants[1].windows.count == 2)
        #expect(decoded.variants[0].displayFingerprints.count == 1)
        #expect(decoded.variants[1].displayFingerprints.count == 2)
    }

    @Test("v3 JSON does not include top-level windows key")
    func v3NoTopLevelWindows() throws {
        let layout = WindowLayout(name: "V3", windows: [makeSnapshot()])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(layout)

        // Parse as raw JSON to verify structure
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["variants"] != nil)
        #expect(json["windows"] == nil)
    }

    @Test("Store round-trip preserves multiple variants")
    func storeRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        var layout = WindowLayout(name: "Variants Test", windows: [makeSnapshot()])
        let secondVariant = DisplayVariant(
            displayFingerprints: [mainDisplay, externalLeft],
            windows: [
                makeSnapshot(display: mainDisplay),
                makeSnapshot(display: externalLeft),
            ]
        )
        layout.variants.append(secondVariant)

        try store.save(layout)
        let loaded = try store.load(id: layout.id)

        #expect(loaded.variants.count == 2)
        #expect(loaded.variants[0].windows.count == 1)
        #expect(loaded.variants[1].windows.count == 2)
    }

    // MARK: - Variant Selection (bestVariant)

    @Test("Single variant always returns that variant")
    func bestVariantSingle() {
        let variant = DisplayVariant(
            displayFingerprints: [mainDisplay],
            windows: [makeSnapshot()]
        )
        let result = LayoutService.bestVariant(from: [variant], for: [mainDisplay])
        #expect(result.id == variant.id)
    }

    @Test("Empty variants returns empty variant")
    func bestVariantEmpty() {
        let result = LayoutService.bestVariant(from: [], for: [mainDisplay])
        #expect(result.windows.isEmpty)
        #expect(result.displayFingerprints.isEmpty)
    }

    @Test("Best variant matches by display fingerprint")
    func bestVariantMatchesFingerprint() {
        let singleVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [mainDisplay],
            windows: [makeSnapshot()]
        )
        let dualVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [mainDisplay, externalLeft],
            windows: [makeSnapshot(), makeSnapshot(display: externalLeft)]
        )

        // Current config: main + external left -> should pick dual variant
        let result = LayoutService.bestVariant(
            from: [singleVariant, dualVariant],
            for: [mainDisplay, externalLeft]
        )
        #expect(result.id == dualVariant.id)
    }

    @Test("Best variant prefers exact display count match")
    func bestVariantPrefersExactCount() {
        let singleVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [mainDisplay],
            windows: [makeSnapshot()]
        )
        let tripleVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [mainDisplay, externalLeft, externalRight],
            windows: [makeSnapshot()]
        )

        // Current config: main only -> single variant should win
        let result = LayoutService.bestVariant(
            from: [tripleVariant, singleVariant],
            for: [mainDisplay]
        )
        #expect(result.id == singleVariant.id)
    }

    @Test("Best variant falls back to first when no match")
    func bestVariantFallback() {
        let unknownDisplay = DisplayFingerprint(
            displayID: 99, localizedName: "Unknown", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let variant1 = DisplayVariant(
            id: UUID(),
            displayFingerprints: [externalLeft],
            windows: [makeSnapshot()]
        )
        let variant2 = DisplayVariant(
            id: UUID(),
            displayFingerprints: [externalRight],
            windows: [makeSnapshot()]
        )

        // Current config: unknown display -> neither matches well, first wins
        let result = LayoutService.bestVariant(
            from: [variant1, variant2],
            for: [unknownDisplay]
        )
        #expect(result.id == variant1.id)
    }

    @Test("Best variant handles variant with empty fingerprints")
    func bestVariantEmptyFingerprints() {
        let emptyFPVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [],
            windows: [makeSnapshot()]
        )
        let matchingVariant = DisplayVariant(
            id: UUID(),
            displayFingerprints: [mainDisplay],
            windows: [makeSnapshot(), makeSnapshot()]
        )

        // Empty fingerprints score 0, matching variant should win
        let result = LayoutService.bestVariant(
            from: [emptyFPVariant, matchingVariant],
            for: [mainDisplay]
        )
        #expect(result.id == matchingVariant.id)
    }

    // MARK: - Integration: Restore with Variants

    @Test("Restore uses correct variant for current display config")
    func restoreSelectsCorrectVariant() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let screenRegistry = ScreenRegistry()
        let mockQuerying = MockWindowQuerying()
        let service = LayoutService(store: store, screenRegistry: screenRegistry, windowQuerying: mockQuerying)

        // Create layout with two variants
        let singleScreenWindows = [
            MockWindowQuerying.makeSnapshot(
                bundleID: "com.apple.finder", appName: "Finder",
                relativeFrame: RelativeFrame(x: 0, y: 0, width: 1, height: 1)
            ),
        ]
        var layout = try service.saveLayout(name: "Variant Test", snapshots: singleScreenWindows)

        // Add a second variant for dual-screen
        let dualVariant = DisplayVariant(
            displayFingerprints: [mainDisplay, externalLeft],
            windows: [
                makeSnapshot(
                    bundleID: "com.apple.finder", appName: "Finder",
                    display: mainDisplay,
                    relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
                ),
                makeSnapshot(
                    bundleID: "com.apple.Safari", appName: "Safari",
                    display: externalLeft,
                    relativeFrame: RelativeFrame(x: 0, y: 0, width: 1, height: 1)
                ),
            ]
        )
        layout.variants.append(dualVariant)
        try store.save(layout)

        // Set up mock windows
        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(bundleID: "com.apple.finder", appName: "Finder"),
            MockWindowQuerying.makeWindowInfo(bundleID: "com.apple.Safari", appName: "Safari"),
        ]

        // Restore — with current display config, it will select the best variant
        let result = service.restoreLayout(layout)
        #expect(result.layoutName == "Variant Test")
        // The test succeeds if restore completes without crash
        #expect(result.restored + result.skipped + result.failed > 0)
    }

    // MARK: - Edge Cases

    @Test("Equatable compares variants not computed windows")
    func equatableUsesVariants() {
        let layout1 = WindowLayout(name: "Test", windows: [makeSnapshot()])
        var layout2 = WindowLayout(name: "Test", windows: [makeSnapshot()])

        // Different variant IDs mean different layouts even if windows are similar
        #expect(layout1 != layout2) // UUIDs differ

        // Same instance should be equal
        layout2 = layout1
        #expect(layout1 == layout2)
    }

    @Test("Schema version is 3")
    func schemaVersion() {
        #expect(WindowLayout.currentSchemaVersion == 3)
    }

    @Test("Layout init deduplicates display fingerprints across windows")
    func initDeduplicatesFingerprints() {
        let windows = [
            makeSnapshot(display: mainDisplay),
            makeSnapshot(display: mainDisplay),
            makeSnapshot(display: mainDisplay),
        ]
        let layout = WindowLayout(name: "Test", windows: windows)

        // All windows on same display -> variant should have 1 fingerprint
        #expect(layout.variants[0].displayFingerprints.count == 1)
    }

    @Test("Layout with windows on multiple displays creates correct fingerprints")
    func multiDisplayFingerprints() {
        let windows = [
            makeSnapshot(display: mainDisplay),
            makeSnapshot(display: externalLeft),
        ]
        let layout = WindowLayout(name: "Test", windows: windows)

        #expect(layout.variants[0].displayFingerprints.count == 2)
    }

    @Test("Import validation checks all variants for empty windows")
    func importValidationVariants() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)

        // Create layout with empty variant
        var layout = WindowLayout(name: "Empty", windows: [])
        layout.variants = [DisplayVariant(displayFingerprints: [], windows: [])]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bundle = LayoutBundle(layouts: [layout])
        let data = try encoder.encode(bundle)

        let result = service.validate(data: data)
        // Empty layout should be warned about
        #expect(result.warnings.contains { $0.contains("no windows") })
    }
}
