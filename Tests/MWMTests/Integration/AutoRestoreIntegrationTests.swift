import CoreGraphics
import Foundation
import Testing
@testable import MWM

/// Integration tests for auto-restore trigger evaluation and conflict detection.
@Suite("Auto-restore integration")
struct AutoRestoreIntegrationTests {
    let tempDir: URL

    init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MWMTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Trigger Matching

    @Test("Layout with display trigger matches current display configuration")
    func displayTriggerMatches() throws {
        defer { cleanup() }

        let fingerprints = [
            DisplayFingerprint(displayID: 1, localizedName: "Built-in", bounds: CGRect(x: 0, y: 0, width: 2560, height: 1600)),
        ]

        var layout = WindowLayout(name: "Single Display", windows: [
            MockWindowQuerying.makeSnapshot(),
        ])
        layout.autoRestore = true
        layout.trigger = .displayConfiguration(fingerprints: fingerprints)

        let context = EnvironmentContext(
            displayFingerprints: Set(fingerprints),
            wifiSSID: nil
        )

        #expect(layout.trigger?.matches(context) == true)
    }

    @Test("Layout with Wi-Fi trigger matches current SSID")
    func wifiTriggerMatches() {
        var layout = WindowLayout(name: "Office", windows: [])
        layout.autoRestore = true
        layout.trigger = .wifiSSID(ssid: "OfficeWiFi")

        let context = EnvironmentContext(
            displayFingerprints: [],
            wifiSSID: "OfficeWiFi"
        )

        #expect(layout.trigger?.matches(context) == true)
    }

    @Test("Wi-Fi trigger does not match different SSID")
    func wifiTriggerNoMatch() {
        var layout = WindowLayout(name: "Office", windows: [])
        layout.autoRestore = true
        layout.trigger = .wifiSSID(ssid: "OfficeWiFi")

        let context = EnvironmentContext(
            displayFingerprints: [],
            wifiSSID: "HomeWiFi"
        )

        #expect(layout.trigger?.matches(context) == false)
    }

    @Test("Compound trigger requires all conditions")
    func compoundTriggerAllRequired() {
        let fingerprints = [
            DisplayFingerprint(displayID: 1, localizedName: "External", bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)),
        ]

        var layout = WindowLayout(name: "Docked Office", windows: [])
        layout.autoRestore = true
        layout.trigger = .compound(conditions: [
            .displayConfiguration(fingerprints: fingerprints),
            .wifiSSID(ssid: "CorpNet"),
        ])

        // Both match
        let fullContext = EnvironmentContext(displayFingerprints: Set(fingerprints), wifiSSID: "CorpNet")
        #expect(layout.trigger?.matches(fullContext) == true)

        // Only display matches
        let displayOnly = EnvironmentContext(displayFingerprints: Set(fingerprints), wifiSSID: "OtherWiFi")
        #expect(layout.trigger?.matches(displayOnly) == false)

        // Only Wi-Fi matches
        let wifiOnly = EnvironmentContext(displayFingerprints: [], wifiSSID: "CorpNet")
        #expect(layout.trigger?.matches(wifiOnly) == false)
    }

    // MARK: - Conflict Detection

    @Test("Two layouts with same trigger are conflicts")
    func conflictDetection() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)
        let fingerprints = [
            DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
        ]

        var layout1 = WindowLayout(name: "Layout A", windows: [MockWindowQuerying.makeSnapshot()])
        layout1.autoRestore = true
        layout1.trigger = .displayConfiguration(fingerprints: fingerprints)

        var layout2 = WindowLayout(name: "Layout B", windows: [MockWindowQuerying.makeSnapshot()])
        layout2.autoRestore = true
        layout2.trigger = .displayConfiguration(fingerprints: fingerprints)

        try store.save(layout1)
        try store.save(layout2)

        let allLayouts = store.loadAll()
        let autoRestoreLayouts = allLayouts.filter { $0.autoRestore && $0.trigger != nil }
        #expect(autoRestoreLayouts.count == 2)

        // Find conflicts for layout1
        let conflicts = allLayouts.filter { other in
            other.id != layout1.id
                && other.autoRestore
                && other.trigger != nil
                && layout1.trigger != nil
                && other.trigger == layout1.trigger
        }
        #expect(conflicts.count == 1)
        #expect(conflicts.first?.name == "Layout B")
    }

    @Test("Layouts with different triggers are not conflicts")
    func noConflictDifferentTriggers() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)

        var layout1 = WindowLayout(name: "Office", windows: [MockWindowQuerying.makeSnapshot()])
        layout1.autoRestore = true
        layout1.trigger = .wifiSSID(ssid: "OfficeWiFi")

        var layout2 = WindowLayout(name: "Home", windows: [MockWindowQuerying.makeSnapshot()])
        layout2.autoRestore = true
        layout2.trigger = .wifiSSID(ssid: "HomeWiFi")

        try store.save(layout1)
        try store.save(layout2)

        let allLayouts = store.loadAll()
        let conflicts = allLayouts.filter { other in
            other.id != layout1.id
                && other.autoRestore
                && other.trigger == layout1.trigger
        }
        #expect(conflicts.isEmpty)
    }

    // MARK: - Diagnostics Integration

    @Test("Restore result is recorded in diagnostics")
    func diagnosticsRecording() throws {
        defer { cleanup() }

        let diagDir = tempDir.appendingPathComponent("diagnostics", isDirectory: true)
        let diagnostics = DiagnosticsService(storageDirectory: diagDir)

        let result = RestoreResult(
            layoutName: "Test Layout",
            restored: 3,
            skipped: 1,
            failed: 0,
            details: [
                WindowRestoreDetail(appName: "Finder", status: .restored),
                WindowRestoreDetail(appName: "Safari", status: .restored),
                WindowRestoreDetail(appName: "Terminal", status: .restored),
                WindowRestoreDetail(appName: "Music", status: .skipped(reason: "Was minimized")),
            ]
        )

        diagnostics.record(result: result, triggerSource: "manual")

        let records = diagnostics.recentRecords
        #expect(records.count == 1)
        #expect(records.first?.layoutName == "Test Layout")
        #expect(records.first?.triggerSource == "manual")
        #expect(records.first?.restored == 3)
        #expect(records.first?.skipped == 1)
    }
}
