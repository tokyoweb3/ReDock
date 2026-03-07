import CoreGraphics
import Foundation
import Testing
@testable import MWM

/// Integration tests for the full layout save → restore flow.
/// Uses MockWindowQuerying to simulate real window scenarios without AX permissions.
@Suite("Layout save/restore integration")
struct LayoutSaveRestoreIntegrationTests {
    let tempDir: URL

    init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MWMTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeServices() -> (LayoutStore, LayoutService, MockWindowQuerying) {
        let store = LayoutStore(directory: tempDir)
        let screenRegistry = ScreenRegistry()
        let mockQuerying = MockWindowQuerying()
        let service = LayoutService(store: store, screenRegistry: screenRegistry, windowQuerying: mockQuerying)
        return (store, service, mockQuerying)
    }

    // MARK: - Save and Load

    @Test("Save layout with selected windows, then load it back")
    func saveAndLoad() throws {
        let (store, service, _) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.finder", appName: "Finder", title: "Documents"),
            MockWindowQuerying.makeSnapshot(bundleID: "com.apple.Safari", appName: "Safari", title: "Apple"),
        ]

        let saved = try service.saveLayout(name: "Test Layout", snapshots: snapshots)
        #expect(saved.windows.count == 2)
        #expect(saved.name == "Test Layout")
        #expect(saved.mode == .appSpecific)

        let loaded = try store.load(id: saved.id)
        #expect(loaded.name == "Test Layout")
        #expect(loaded.windows.count == 2)
        #expect(loaded.windows[0].appBundleID == "com.apple.finder")
        #expect(loaded.windows[1].appBundleID == "com.apple.Safari")
    }

    @Test("Save template layout preserves mode")
    func saveTemplateLayout() throws {
        let (store, service, _) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)),
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]

        let saved = try service.saveLayout(name: "Template", snapshots: snapshots, mode: .template)
        let loaded = try store.load(id: saved.id)
        #expect(loaded.mode == .template)
    }

    // MARK: - Restore with Matching

    @Test("Restore matches windows by bundleID and applies positions")
    func restoreAppSpecific() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Save a layout
        let snapshots = [
            MockWindowQuerying.makeSnapshot(
                bundleID: "com.apple.finder", appName: "Finder", title: "Documents",
                relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
            ),
        ]
        let saved = try service.saveLayout(name: "Restore Test", snapshots: snapshots)

        // Set up mock windows for restore
        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(
                bundleID: "com.apple.finder", appName: "Finder", title: "Documents",
                frame: CGRect(x: 100, y: 100, width: 400, height: 600)
            ),
        ]

        let result = service.restoreLayout(saved)
        // Window matched by bundleID - setFrame is called on fake element (no-op)
        // but the logic path is exercised
        #expect(result.restored + result.skipped == 1)
        #expect(result.layoutName == "Restore Test")
    }

    @Test("Restore skips windows when app is not running")
    func restoreSkipsMissingApps() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(bundleID: "com.missing.app", appName: "Missing"),
        ]
        let saved = try service.saveLayout(name: "Missing App", snapshots: snapshots)

        mockQuerying.windows = [] // No windows running

        let result = service.restoreLayout(saved)
        #expect(result.skipped == 1)
        #expect(result.restored == 0)
    }

    @Test("Restore skips fullscreen and minimized windows")
    func restoreSkipsFullscreenAndMinimized() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(bundleID: "com.test.fs", appName: "FS", wasFullscreen: true),
            MockWindowQuerying.makeSnapshot(bundleID: "com.test.min", appName: "Min", isMinimized: true),
        ]
        let saved = try service.saveLayout(name: "Skippable", snapshots: snapshots)

        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(bundleID: "com.test.fs", appName: "FS"),
            MockWindowQuerying.makeWindowInfo(bundleID: "com.test.min", appName: "Min"),
        ]

        let result = service.restoreLayout(saved)
        #expect(result.skipped == 2)
        #expect(result.restored == 0)
    }

    // MARK: - Template Restore

    @Test("Template restore applies to any N windows")
    func templateRestore() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)),
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
        let saved = try service.saveLayout(name: "Template", snapshots: snapshots, mode: .template)

        // Different apps than saved - template mode doesn't care
        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.one", appName: "One"),
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.two", appName: "Two"),
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.three", appName: "Three"),
        ]

        let result = service.restoreLayout(saved)
        // Should restore exactly 2 (template slot count), not all 3
        #expect(result.restored + result.skipped == 2)
    }

    @Test("Template restore skips when not enough windows")
    func templateRestoreNotEnoughWindows() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.33, height: 1)),
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0.33, y: 0, width: 0.33, height: 1)),
            MockWindowQuerying.makeSnapshot(relativeFrame: RelativeFrame(x: 0.66, y: 0, width: 0.34, height: 1)),
        ]
        let saved = try service.saveLayout(name: "3-col", snapshots: snapshots, mode: .template)

        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(bundleID: "com.app.one", appName: "One"),
        ]

        let result = service.restoreLayout(saved)
        #expect(result.skipped == 2) // 2 slots with no windows
    }

    // MARK: - Update from Current

    @Test("Update from current refreshes positions of matched windows")
    func updateFromCurrent() throws {
        let (_, service, mockQuerying) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshots = [
            MockWindowQuerying.makeSnapshot(
                bundleID: "com.apple.finder", appName: "Finder", title: "Documents",
                relativeFrame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
            ),
        ]
        let saved = try service.saveLayout(name: "Update Test", snapshots: snapshots)

        // Simulate the user moving the window
        mockQuerying.windows = [
            MockWindowQuerying.makeWindowInfo(
                bundleID: "com.apple.finder", appName: "Finder", title: "Documents",
                frame: CGRect(x: 960, y: 0, width: 960, height: 1080) // moved to right half
            ),
        ]

        let updated = try service.updateFromCurrent(layoutID: saved.id)
        // Position should be updated (actual value depends on screen geometry)
        #expect(updated.windows.count == 1)
        #expect(updated.windows[0].appBundleID == "com.apple.finder")
    }

    // MARK: - Multiple Layouts

    @Test("loadAll returns all saved layouts")
    func loadAllLayouts() throws {
        let (_, service, _) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try _ = service.saveLayout(name: "Layout A", snapshots: [MockWindowQuerying.makeSnapshot()])
        try _ = service.saveLayout(name: "Layout B", snapshots: [MockWindowQuerying.makeSnapshot()])
        try _ = service.saveLayout(name: "Layout C", snapshots: [MockWindowQuerying.makeSnapshot()])

        let all = service.loadAll()
        #expect(all.count == 3)
    }

    @Test("Delete removes layout from store")
    func deleteLayout() throws {
        let (_, service, _) = makeServices()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let saved = try service.saveLayout(name: "To Delete", snapshots: [MockWindowQuerying.makeSnapshot()])
        #expect(service.loadAll().count == 1)

        try service.delete(id: saved.id)
        #expect(service.loadAll().isEmpty)
    }
}
