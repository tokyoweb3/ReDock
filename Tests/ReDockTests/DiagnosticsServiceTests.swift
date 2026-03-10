import Foundation
import Testing
@testable import ReDock

@Suite("DiagnosticsService")
struct DiagnosticsServiceTests {
    func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func makeResult(name: String = "TestLayout", restored: Int = 2, skipped: Int = 1, failed: Int = 0) -> RestoreResult {
        RestoreResult(
            layoutName: name,
            restored: restored,
            skipped: skipped,
            failed: failed,
            details: [
                WindowRestoreDetail(appName: "Finder", status: .restored),
                WindowRestoreDetail(appName: "Safari", status: .restored),
                WindowRestoreDetail(appName: "Notes", status: .skipped(reason: "App not running")),
            ]
        )
    }

    @Test("Records are stored and retrievable")
    func recordAndRetrieve() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult())

        #expect(service.recentRecords.count == 1)
        #expect(service.recentRecords.first?.layoutName == "TestLayout")
        #expect(service.recentRecords.first?.restored == 2)
        #expect(service.recentRecords.first?.skipped == 1)
        #expect(service.recentRecords.first?.triggerSource == "manual")
    }

    @Test("Records persist to disk and reload")
    func persistence() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service1 = DiagnosticsService(storageDirectory: dir)
        service1.record(result: makeResult(name: "Persisted"))

        let service2 = DiagnosticsService(storageDirectory: dir)
        #expect(service2.recentRecords.count == 1)
        #expect(service2.recentRecords.first?.layoutName == "Persisted")
    }

    @Test("Records are newest-first")
    func ordering() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult(name: "First"))
        service.record(result: makeResult(name: "Second"))

        #expect(service.recentRecords.count == 2)
        #expect(service.recentRecords.first?.layoutName == "Second")
    }

    @Test("Records capped at maxRecords")
    func maxRecords() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir, maxRecords: 3)
        for i in 1...5 {
            service.record(result: makeResult(name: "Layout \(i)"))
        }

        #expect(service.recentRecords.count == 3)
        #expect(service.recentRecords.first?.layoutName == "Layout 5")
    }

    @Test("Filter records by layout name")
    func filterByName() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult(name: "Alpha"))
        service.record(result: makeResult(name: "Beta"))
        service.record(result: makeResult(name: "Alpha"))

        let alphaRecords = service.records(forLayout: "Alpha")
        #expect(alphaRecords.count == 2)
    }

    @Test("Clear all removes all records")
    func clearAll() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult())
        service.record(result: makeResult())
        service.clearAll()

        #expect(service.recentRecords.isEmpty)

        // Verify persistence is also cleared
        let service2 = DiagnosticsService(storageDirectory: dir)
        #expect(service2.recentRecords.isEmpty)
    }

    @Test("Trigger source is recorded")
    func triggerSource() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult(), triggerSource: "auto-display")

        #expect(service.recentRecords.first?.triggerSource == "auto-display")
    }

    @Test("Detail records capture status and reasons")
    func detailRecords() {
        let dir = tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = DiagnosticsService(storageDirectory: dir)
        service.record(result: makeResult())

        let details = service.recentRecords.first?.details ?? []
        #expect(details.count == 3)
        #expect(details[0].status == "restored")
        #expect(details[2].status == "skipped")
        #expect(details[2].reason == "App not running")
    }
}
