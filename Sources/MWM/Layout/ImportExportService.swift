import Foundation
import os

/// Exportable bundle containing one or more layouts with schema metadata.
struct LayoutBundle: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var layouts: [WindowLayout]

    init(layouts: [WindowLayout]) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.layouts = layouts
    }
}

/// Validation result for an imported layout bundle.
struct ImportValidation {
    var validLayouts: [WindowLayout]
    var warnings: [String]
    var errors: [String]

    var isUsable: Bool { !validLayouts.isEmpty }
}

/// Handles exporting layouts to JSON files and importing them back.
final class ImportExportService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "ImportExport")

    private let store: LayoutStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(store: LayoutStore) {
        self.store = store

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Export

    /// Export specified layouts to JSON data.
    func exportLayouts(_ layouts: [WindowLayout]) throws -> Data {
        let bundle = LayoutBundle(layouts: layouts)
        let data = try encoder.encode(bundle)
        Self.logger.info("Exported \(layouts.count) layout(s)")
        return data
    }

    /// Export all stored layouts to JSON data.
    func exportAll() throws -> Data {
        let layouts = store.loadAll()
        return try exportLayouts(layouts)
    }

    /// Export layouts to a file URL.
    func exportToFile(_ layouts: [WindowLayout], url: URL) throws {
        let data = try exportLayouts(layouts)
        try data.write(to: url, options: .atomic)
        Self.logger.info("Exported to \(url.lastPathComponent)")
    }

    // MARK: - Import

    /// Validate imported JSON data without saving.
    func validate(data: Data) -> ImportValidation {
        var warnings: [String] = []
        var errors: [String] = []

        let bundle: LayoutBundle
        do {
            bundle = try decoder.decode(LayoutBundle.self, from: data)
        } catch {
            return ImportValidation(
                validLayouts: [],
                warnings: [],
                errors: ["Invalid JSON format: \(error.localizedDescription)"]
            )
        }

        if bundle.version > LayoutBundle.currentVersion {
            warnings.append("File version \(bundle.version) is newer than supported version \(LayoutBundle.currentVersion). Some data may be lost.")
        }

        var validLayouts: [WindowLayout] = []
        for (index, layout) in bundle.layouts.enumerated() {
            if layout.name.isEmpty {
                warnings.append("Layout \(index + 1) has no name, using 'Imported'")
                var fixed = layout
                fixed.name = "Imported"
                validLayouts.append(fixed)
            } else if layout.variants.allSatisfy({ $0.windows.isEmpty }) {
                warnings.append("Layout '\(layout.name)' has no windows, skipping")
            } else if layout.schemaVersion > WindowLayout.currentSchemaVersion {
                warnings.append("Layout '\(layout.name)' has newer schema version \(layout.schemaVersion)")
                validLayouts.append(layout)
            } else {
                validLayouts.append(layout)
            }
        }

        if validLayouts.isEmpty && errors.isEmpty {
            errors.append("No valid layouts found in the file")
        }

        return ImportValidation(validLayouts: validLayouts, warnings: warnings, errors: errors)
    }

    /// Import layouts from JSON data, assigning new UUIDs to avoid conflicts.
    func importLayouts(data: Data) throws -> ImportValidation {
        let validation = validate(data: data)
        guard validation.isUsable else { return validation }

        let existingNames = Set(store.loadAll().map(\.name))

        for layout in validation.validLayouts {
            var imported = layout
            imported.id = UUID()
            imported.createdAt = Date()
            imported.updatedAt = Date()
            // Clear auto-restore triggers on import to avoid conflicts
            for i in imported.variants.indices {
                imported.variants[i].autoRestore = false
                imported.variants[i].launchMissingApps = false
            }

            // Deduplicate name if it already exists
            if existingNames.contains(imported.name) {
                var suffix = 2
                var candidate = "\(imported.name) (\(suffix))"
                while existingNames.contains(candidate) {
                    suffix += 1
                    candidate = "\(imported.name) (\(suffix))"
                }
                imported.name = candidate
            }

            try store.save(imported)
        }

        Self.logger.info("Imported \(validation.validLayouts.count) layout(s)")
        return validation
    }

    /// Import from a file URL.
    func importFromFile(url: URL) throws -> ImportValidation {
        let data = try Data(contentsOf: url)
        return try importLayouts(data: data)
    }
}
