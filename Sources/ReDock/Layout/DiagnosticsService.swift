import Foundation
import os

/// A timestamped record of a restore attempt.
struct RestoreRecord: Codable, Identifiable {
    var id: UUID
    var layoutName: String
    var timestamp: Date
    var restored: Int
    var skipped: Int
    var failed: Int
    var details: [RestoreDetailRecord]
    var triggerSource: String

    var summary: String {
        "\(layoutName): \(restored) restored, \(skipped) skipped, \(failed) failed"
    }
}

/// Codable detail of a single window restore attempt.
struct RestoreDetailRecord: Codable {
    var appName: String
    var status: String
    var reason: String?
}

/// Stores and retrieves restore diagnostics for user review.
final class DiagnosticsService {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "Diagnostics")

    private let maxRecords: Int
    private var records: [RestoreRecord] = []
    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageDirectory: URL? = nil, maxRecords: Int = 50) {
        self.maxRecords = maxRecords

        let dir: URL
        if let storageDirectory {
            dir = storageDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("ReDock", isDirectory: true)
        }
        self.storageURL = dir.appendingPathComponent("diagnostics.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        loadFromDisk()
    }

    // MARK: - Recording

    /// Record a restore result from LayoutService.
    func record(result: RestoreResult, triggerSource: String = "manual") {
        let detailRecords = result.details.map { detail in
            RestoreDetailRecord(
                appName: detail.appName,
                status: statusString(detail.status),
                reason: reasonString(detail.status)
            )
        }

        let record = RestoreRecord(
            id: UUID(),
            layoutName: result.layoutName,
            timestamp: Date(),
            restored: result.restored,
            skipped: result.skipped,
            failed: result.failed,
            details: detailRecords,
            triggerSource: triggerSource
        )

        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        saveToDisk()
        Self.logger.info("Recorded restore: \(record.summary)")
    }

    // MARK: - Querying

    /// All stored records, newest first.
    var recentRecords: [RestoreRecord] {
        records
    }

    /// Records for a specific layout name.
    func records(forLayout name: String) -> [RestoreRecord] {
        records.filter { $0.layoutName == name }
    }

    /// Clear all diagnostics.
    func clearAll() {
        records = []
        saveToDisk()
    }

    // MARK: - Private

    private func statusString(_ status: WindowRestoreDetail.Status) -> String {
        switch status {
        case .restored: return "restored"
        case .skipped: return "skipped"
        case .failed: return "failed"
        }
    }

    private func reasonString(_ status: WindowRestoreDetail.Status) -> String? {
        switch status {
        case .restored: return nil
        case .skipped(let reason): return reason
        case .failed(let reason): return reason
        }
    }

    private func saveToDisk() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(records)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save diagnostics: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            records = try decoder.decode([RestoreRecord].self, from: data)
        } catch {
            Self.logger.error("Failed to load diagnostics: \(error)")
        }
    }
}
