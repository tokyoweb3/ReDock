import Foundation
import os

/// Persists WindowLayout as individual JSON files.
/// Storage: ~/Library/Application Support/MWM/layouts/
final class LayoutStore {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "LayoutStore")

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = appSupport.appendingPathComponent("MWM/layouts", isDirectory: true)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - CRUD

    func save(_ layout: WindowLayout) throws {
        try ensureDirectory()
        var updated = layout
        updated.updatedAt = Date()
        let data = try encoder.encode(updated)
        let fileURL = url(for: updated.id)
        try data.write(to: fileURL, options: .atomic)
        Self.logger.info("Saved layout '\(updated.name)' to \(fileURL.lastPathComponent)")
    }

    func load(id: UUID) throws -> WindowLayout {
        let fileURL = url(for: id)
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WindowLayout.self, from: data)
    }

    func loadAll() -> [WindowLayout] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    return try decoder.decode(WindowLayout.self, from: data)
                } catch {
                    Self.logger.error("Failed to load layout from \(fileURL.lastPathComponent): \(error)")
                    return nil
                }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(id: UUID) throws {
        let fileURL = url(for: id)
        try FileManager.default.removeItem(at: fileURL)
        Self.logger.info("Deleted layout \(id)")
    }

    // MARK: - Private

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
