import Foundation

/// A named display configuration profile (e.g. "Home 3-screen", "Cafe MacBook").
/// Auto-detected when a new monitor configuration is seen, and user-renamable.
struct DisplayProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var fingerprints: [DisplayFingerprint]
    var createdAt: Date
    var lastSeenAt: Date?

    init(id: UUID = UUID(), name: String, fingerprints: [DisplayFingerprint]) {
        self.id = id
        self.name = name
        self.fingerprints = fingerprints
        self.createdAt = Date()
        self.lastSeenAt = Date()
    }

    /// Check if this profile matches a set of current fingerprints.
    func matches(_ currentFingerprints: [DisplayFingerprint]) -> Bool {
        guard fingerprints.count == currentFingerprints.count else { return false }
        for required in fingerprints {
            let hasMatch = currentFingerprints.contains { $0.approximatelyMatches(required) }
            if !hasMatch { return false }
        }
        return true
    }

    /// Human-readable display names of the monitors in this profile.
    var displayDescription: String {
        let names = fingerprints.compactMap(\.localizedName).filter { !$0.isEmpty }
        if names.isEmpty {
            return "\(fingerprints.count) display(s)"
        }
        return names.joined(separator: " + ")
    }

    /// Whether this profile contains only valid (non-phantom) display fingerprints.
    var isValid: Bool {
        !fingerprints.isEmpty && fingerprints.allSatisfy(\.isValid)
    }

    /// Check if this profile matches the currently connected displays.
    func isConnected(currentFingerprints: [DisplayFingerprint]) -> Bool {
        matches(currentFingerprints)
    }
}

// MARK: - Display Profile Store

/// Persists display profiles in a JSON file.
final class DisplayProfileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = appSupport.appendingPathComponent("ReDock/display-profiles.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAll() -> [DisplayProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let profiles = try? decoder.decode([DisplayProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    func save(_ profile: DisplayProfile) {
        var profiles = loadAll()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        writeAll(profiles)
    }

    func delete(id: UUID) {
        var profiles = loadAll()
        profiles.removeAll { $0.id == id }
        writeAll(profiles)
    }

    /// Find or create a profile matching the given fingerprints.
    /// Returns the matching profile, or creates a new one with a default name.
    func findOrCreate(fingerprints: [DisplayFingerprint]) -> DisplayProfile {
        // Filter out invalid (phantom) fingerprints before creating profiles
        let validFingerprints = fingerprints.filter(\.isValid)
        guard !validFingerprints.isEmpty else {
            // Return a temporary profile without persisting phantom displays
            return DisplayProfile(name: "Unknown", fingerprints: validFingerprints)
        }

        let existing = loadAll()
        if var match = existing.first(where: { $0.matches(validFingerprints) }) {
            match.lastSeenAt = Date()
            save(match)
            return match
        }

        // Auto-create with default name based on display count and names
        let names = validFingerprints.compactMap(\.localizedName).filter { !$0.isEmpty }
        let defaultName: String
        if names.count == 1 {
            defaultName = names[0]
        } else if !names.isEmpty {
            defaultName = names.joined(separator: " + ")
        } else {
            defaultName = "\(validFingerprints.count) display(s)"
        }

        let profile = DisplayProfile(name: defaultName, fingerprints: validFingerprints)
        save(profile)
        return profile
    }

    /// Remove invalid profiles (phantom displays with empty names).
    func removeInvalidProfiles() {
        let profiles = loadAll()
        let valid = profiles.filter(\.isValid)
        if valid.count != profiles.count {
            writeAll(valid)
        }
    }

    private func writeAll(_ profiles: [DisplayProfile]) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
