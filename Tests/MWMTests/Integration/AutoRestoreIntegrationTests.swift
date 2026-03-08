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

        var layout = WindowLayout(name: "Single Display", autoRestore: true, windows: [
            MockWindowQuerying.makeSnapshot(),
        ])
        layout.trigger = .displayConfiguration(fingerprints: fingerprints)

        let context = EnvironmentContext(
            displayFingerprints: Set(fingerprints),
            wifiSSID: nil
        )

        #expect(layout.trigger?.matches(context) == true)
    }

    @Test("Layout with Wi-Fi trigger matches current SSID")
    func wifiTriggerMatches() {
        var layout = WindowLayout(name: "Office", autoRestore: true, windows: [])
        layout.trigger = .wifiSSID(ssid: "OfficeWiFi")

        let context = EnvironmentContext(
            displayFingerprints: [],
            wifiSSID: "OfficeWiFi"
        )

        #expect(layout.trigger?.matches(context) == true)
    }

    @Test("Wi-Fi trigger does not match different SSID")
    func wifiTriggerNoMatch() {
        var layout = WindowLayout(name: "Office", autoRestore: true, windows: [])
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

        var layout = WindowLayout(name: "Docked Office", autoRestore: true, windows: [])
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

    // MARK: - Auto-restore Exclusive Control

    @Test("Enabling auto-restore disables conflicting variants in other layouts")
    func exclusiveAutoRestore() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)
        let service = LayoutService(store: store, screenRegistry: ScreenRegistry(), windowQuerying: MockWindowQuerying())
        let profileID = UUID()
        let fingerprints = [
            DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
        ]

        var layout1 = WindowLayout(name: "Layout A", autoRestore: true, windows: [MockWindowQuerying.makeSnapshot()])
        layout1.variants[0].displayProfileID = profileID
        layout1.variants[0].displayFingerprints = fingerprints

        var layout2 = WindowLayout(name: "Layout B", autoRestore: true, windows: [MockWindowQuerying.makeSnapshot()])
        layout2.variants[0].displayProfileID = profileID
        layout2.variants[0].displayFingerprints = fingerprints

        try store.save(layout1)
        try store.save(layout2)

        // Enable auto-restore on layout1's variant — should disable layout2's
        let modified = service.disableConflictingAutoRestore(
            keepVariantID: layout1.variants[0].id,
            displayProfileID: profileID
        )
        #expect(modified == 1)

        let reloaded = store.loadAll()
        let reloadedB = reloaded.first(where: { $0.name == "Layout B" })!
        #expect(reloadedB.variants[0].autoRestore == false)
    }

    @Test("Exclusive auto-restore does not affect different profiles")
    func exclusiveAutoRestoreDifferentProfiles() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)
        let service = LayoutService(store: store, screenRegistry: ScreenRegistry(), windowQuerying: MockWindowQuerying())
        let profileA = UUID()
        let profileB = UUID()

        var layout1 = WindowLayout(name: "Office", autoRestore: true, windows: [MockWindowQuerying.makeSnapshot()])
        layout1.variants[0].displayProfileID = profileA

        var layout2 = WindowLayout(name: "Home", autoRestore: true, windows: [MockWindowQuerying.makeSnapshot()])
        layout2.variants[0].displayProfileID = profileB

        try store.save(layout1)
        try store.save(layout2)

        let modified = service.disableConflictingAutoRestore(
            keepVariantID: layout1.variants[0].id,
            displayProfileID: profileA
        )
        #expect(modified == 0)

        let reloaded = store.loadAll()
        let reloadedHome = reloaded.first(where: { $0.name == "Home" })!
        #expect(reloadedHome.variants[0].autoRestore == true)
    }

    // MARK: - Display trigger (legacy trigger-based matching)

    @Test("Display trigger does not match with different display")
    func displayTriggerNoMatch() {
        let fp1 = DisplayFingerprint(displayID: 1, localizedName: "Built-in", bounds: CGRect(x: 0, y: 0, width: 2560, height: 1600))
        let fp2 = DisplayFingerprint(displayID: 2, localizedName: "External", bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160))

        let trigger = ContextTrigger.displayConfiguration(fingerprints: [fp1])
        let context = EnvironmentContext(displayFingerprints: [fp2], wifiSSID: nil)

        #expect(trigger.matches(context) == false)
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
