import CoreGraphics
import Foundation
import Testing
@testable import ReDock

/// Integration tests for the full export → import → restore flow.
@Suite("Import/Export integration")
struct ImportExportIntegrationTests {
    let tempDir: URL
    let exportDir: URL

    init() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReDockTests-\(UUID().uuidString)", isDirectory: true)
        tempDir = base.appendingPathComponent("store", isDirectory: true)
        exportDir = base.appendingPathComponent("export", isDirectory: true)
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent())
    }

    // MARK: - Full Round-Trip

    @Test("Export layouts, import to fresh store, verify content")
    func exportImportRoundTrip() throws {
        defer { cleanup() }

        // Create source store with layouts
        let sourceStore = LayoutStore(directory: tempDir)
        let sourceService = ImportExportService(store: sourceStore)

        let layout1 = WindowLayout(name: "Office", windows: [
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.finder", appName: "Finder"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.Safari", appName: "Safari"),
        ])
        let layout2 = WindowLayout(name: "Home", mode: .template, windows: [
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)),
        ])

        try sourceStore.save(layout1)
        try sourceStore.save(layout2)

        // Export
        let exportURL = exportDir.appendingPathComponent("layouts.json")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        try sourceService.exportToFile([layout1, layout2], url: exportURL)

        // Import to a fresh store
        let destDir = tempDir.deletingLastPathComponent().appendingPathComponent("dest", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destDir) }
        let destStore = LayoutStore(directory: destDir)
        let destService = ImportExportService(store: destStore)

        let validation = try destService.importFromFile(url: exportURL)

        #expect(validation.validLayouts.count == 2)
        #expect(validation.warnings.isEmpty)

        // Verify imported layouts
        let imported = destStore.loadAll()
        #expect(imported.count == 2)

        let names = Set(imported.map(\.name))
        #expect(names.contains("Office"))
        #expect(names.contains("Home"))

        // IDs should be different (re-assigned on import)
        let importedIDs = Set(imported.map(\.id))
        let sourceIDs: Set<UUID> = [layout1.id, layout2.id]
        #expect(importedIDs.isDisjoint(with: sourceIDs))

        // Template mode preserved
        let homeLayout = imported.first { $0.name == "Home" }
        #expect(homeLayout?.mode == .template)

        // Auto-restore cleared on import
        for layout in imported {
            #expect(layout.autoRestore == false)
        }
    }

    @Test("Import file with invalid JSON reports errors in validation")
    func importInvalidJSON() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)
        let service = ImportExportService(store: store)

        let invalidURL = exportDir.appendingPathComponent("bad.json")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        try "{ not valid json }".write(to: invalidURL, atomically: true, encoding: .utf8)

        let validation = try service.importFromFile(url: invalidURL)
        #expect(validation.validLayouts.isEmpty)
        #expect(!validation.errors.isEmpty)
    }

    @Test("Export and import preserves window snapshots")
    func snapshotPreservation() throws {
        defer { cleanup() }

        let store = LayoutStore(directory: tempDir)
        let service = ImportExportService(store: store)

        let snapshot = MockWindowQuerying.makeSnapshot(
            bundleID: "com.test.app",
            appName: "TestApp",
            title: "My Document",
            relativeFrame: RelativeFrame(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        )
        let layout = WindowLayout(name: "Precise", windows: [snapshot])
        try store.save(layout)

        let exportURL = exportDir.appendingPathComponent("precise.json")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        try service.exportToFile([layout], url: exportURL)

        // Import to fresh store
        let destDir = tempDir.deletingLastPathComponent().appendingPathComponent("dest2", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destDir) }
        let destStore = LayoutStore(directory: destDir)
        let destService = ImportExportService(store: destStore)
        let validation = try destService.importFromFile(url: exportURL)

        let imported = validation.validLayouts.first!
        let importedSnapshot = imported.windows.first!

        #expect(importedSnapshot.appBundleID == "com.test.app")
        #expect(importedSnapshot.appName == "TestApp")
        #expect(importedSnapshot.title == "My Document")
        #expect(abs(importedSnapshot.relativeFrame.x - 0.1) < 0.001)
        #expect(abs(importedSnapshot.relativeFrame.y - 0.2) < 0.001)
        #expect(abs(importedSnapshot.relativeFrame.width - 0.3) < 0.001)
        #expect(abs(importedSnapshot.relativeFrame.height - 0.4) < 0.001)
    }
}
