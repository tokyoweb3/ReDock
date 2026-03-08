import CoreGraphics
import Foundation
import Testing
@testable import MWM

@Suite("ImportExportService")
struct ImportExportTests {
    func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func makeLayout(name: String = "Test") -> WindowLayout {
        WindowLayout(
            name: name,
            windows: [
                WindowSnapshot(
                    id: UUID(),
                    appBundleID: "com.apple.finder",
                    appName: "Finder",
                    title: "Desktop",
                    role: "AXWindow",
                    subrole: "AXStandardWindow",
                    relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1),
                    display: DisplayFingerprint(displayID: 1, localizedName: "Main", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
                    isMinimized: false,
                    wasFullscreen: false
                )
            ]
        )
    }

    @Test("Export and import round-trip preserves layout data")
    func roundTrip() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)
        let original = makeLayout(name: "Export Test")

        let data = try service.exportLayouts([original])
        let validation = try service.importLayouts(data: data)

        #expect(validation.isUsable)
        #expect(validation.validLayouts.count == 1)
        #expect(validation.validLayouts.first?.name == "Export Test")
        #expect(validation.warnings.isEmpty)
        #expect(validation.errors.isEmpty)

        let stored = store.loadAll()
        #expect(stored.count == 1)
        #expect(stored.first?.name == "Export Test")
        // Imported layout should have a new UUID
        #expect(stored.first?.id != original.id)
    }

    @Test("Validate rejects invalid JSON")
    func invalidJSON() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)

        let validation = service.validate(data: Data("not json".utf8))
        #expect(!validation.isUsable)
        #expect(!validation.errors.isEmpty)
    }

    @Test("Validate warns on empty-name layout")
    func emptyName() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)

        var layout = makeLayout(name: "")
        layout.name = ""
        let data = try service.exportLayouts([layout])
        let validation = service.validate(data: data)

        #expect(validation.isUsable)
        #expect(validation.warnings.contains { $0.contains("no name") })
        #expect(validation.validLayouts.first?.name == "Imported")
    }

    @Test("Validate warns on empty-windows layout")
    func emptyWindows() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)

        let layout = WindowLayout(name: "Empty", windows: [])
        let data = try service.exportLayouts([layout])
        let validation = service.validate(data: data)

        #expect(!validation.isUsable)
        #expect(validation.warnings.contains { $0.contains("no windows") })
    }

    @Test("Import clears autoRestore flag")
    func importClearsAutoRestore() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)

        var layout = makeLayout(name: "Auto")
        layout.variants[0].autoRestore = true
        layout.trigger = .displayConfiguration(fingerprints: [])

        let data = try service.exportLayouts([layout])
        let validation = try service.importLayouts(data: data)

        #expect(validation.isUsable)
        let stored = store.loadAll()
        #expect(stored.first?.autoRestore == false)
    }

    @Test("Export to file and import from file")
    func fileRoundTrip() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)
        let layout = makeLayout(name: "File Test")

        let fileURL = dir.appendingPathComponent("export.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try service.exportToFile([layout], url: fileURL)

        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let validation = try service.importFromFile(url: fileURL)
        #expect(validation.isUsable)
        #expect(validation.validLayouts.count == 1)
    }

    @Test("LayoutBundle schema version is preserved")
    func schemaVersion() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let service = ImportExportService(store: store)
        let layout = makeLayout(name: "Version Check")

        let data = try service.exportLayouts([layout])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(LayoutBundle.self, from: data)

        #expect(bundle.version == LayoutBundle.currentVersion)
        #expect(bundle.layouts.count == 1)
    }
}
