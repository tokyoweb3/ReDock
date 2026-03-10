import CoreGraphics
import Foundation
import Testing
@testable import ReDock

@Suite("LayoutStore persistence")
struct LayoutStoreTests {
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

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let original = makeLayout(name: "Round Trip Test")
        try store.save(original)

        let loaded = try store.load(id: original.id)
        #expect(loaded.name == "Round Trip Test")
        #expect(loaded.windows.count == 1)
        #expect(loaded.schemaVersion == WindowLayout.currentSchemaVersion)
    }

    @Test("loadAll returns all saved layouts")
    func loadAll() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        try store.save(makeLayout(name: "A"))
        try store.save(makeLayout(name: "B"))

        let all = store.loadAll()
        #expect(all.count == 2)
    }

    @Test("Delete removes layout file")
    func delete() throws {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = LayoutStore(directory: dir)
        let layout = makeLayout()
        try store.save(layout)
        try store.delete(id: layout.id)

        let all = store.loadAll()
        #expect(all.isEmpty)
    }

    @Test("loadAll returns empty array for missing directory")
    func loadMissingDir() {
        let store = LayoutStore(directory: URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)"))
        let result = store.loadAll()
        #expect(result.isEmpty)
    }
}
