import Foundation

/// How a layout matches windows during restore.
enum LayoutMode: String, Codable, CaseIterable {
    /// Match by app bundle ID (traditional snapshot).
    case appSpecific

    /// Apply to the N most recently used windows regardless of app (Moom-style "any window").
    case template
}

/// A display-specific variant containing window arrangements for a particular
/// display configuration (e.g. 3-monitor desk, single MacBook screen).
struct DisplayVariant: Codable, Identifiable, Equatable {
    var id: UUID
    var displayFingerprints: [DisplayFingerprint]
    var windows: [WindowSnapshot]

    init(id: UUID = UUID(), displayFingerprints: [DisplayFingerprint], windows: [WindowSnapshot]) {
        self.id = id
        self.displayFingerprints = displayFingerprints
        self.windows = windows
    }

    /// Human-readable description of the display configuration.
    var displayDescription: String {
        if displayFingerprints.isEmpty {
            return "Default"
        }
        let names = displayFingerprints.compactMap(\.localizedName)
        if names.isEmpty {
            return "\(displayFingerprints.count) display(s)"
        }
        return names.joined(separator: " + ")
    }
}

/// A saved window layout containing one or more display variants.
struct WindowLayout: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 3

    var id: UUID
    var schemaVersion: Int
    var name: String
    var trigger: ContextTrigger?
    var autoRestore: Bool
    var mode: LayoutMode
    var isFavorite: Bool
    /// Linked display profile ID for display-aware restore.
    var displayProfileID: UUID?
    /// Launch apps that aren't running when restoring this layout.
    var launchMissingApps: Bool
    var createdAt: Date
    var updatedAt: Date
    /// Display-specific window arrangements.
    var variants: [DisplayVariant]

    /// Convenience accessor for the first variant's windows (backward compat).
    var windows: [WindowSnapshot] {
        get { variants.first?.windows ?? [] }
        set {
            if variants.isEmpty {
                variants.append(DisplayVariant(displayFingerprints: [], windows: newValue))
            } else {
                variants[0].windows = newValue
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        trigger: ContextTrigger? = nil,
        autoRestore: Bool = false,
        mode: LayoutMode = .appSpecific,
        isFavorite: Bool = false,
        displayProfileID: UUID? = nil,
        launchMissingApps: Bool = false,
        windows: [WindowSnapshot]
    ) {
        self.id = id
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.trigger = trigger
        self.autoRestore = autoRestore
        self.mode = mode
        self.isFavorite = isFavorite
        self.displayProfileID = displayProfileID
        self.launchMissingApps = launchMissingApps
        self.createdAt = Date()
        self.updatedAt = Date()
        let fingerprints = Array(Set(windows.map(\.display)))
        self.variants = [DisplayVariant(displayFingerprints: fingerprints, windows: windows)]
    }

    // Support decoding older layouts (v2) and newer (v3+)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        name = try container.decode(String.self, forKey: .name)
        trigger = try container.decodeIfPresent(ContextTrigger.self, forKey: .trigger)
        autoRestore = try container.decode(Bool.self, forKey: .autoRestore)
        mode = try container.decodeIfPresent(LayoutMode.self, forKey: .mode) ?? .appSpecific
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        displayProfileID = try container.decodeIfPresent(UUID.self, forKey: .displayProfileID)
        launchMissingApps = try container.decodeIfPresent(Bool.self, forKey: .launchMissingApps) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // v3+: decode variants directly
        if let variants = try container.decodeIfPresent([DisplayVariant].self, forKey: .variants) {
            self.variants = variants
        } else {
            // v2 migration: wrap windows array into a single default variant
            let windows = try container.decode([WindowSnapshot].self, forKey: .windows)
            let fingerprints = Array(Set(windows.map(\.display)))
            self.variants = [DisplayVariant(displayFingerprints: fingerprints, windows: windows)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(trigger, forKey: .trigger)
        try container.encode(autoRestore, forKey: .autoRestore)
        try container.encode(mode, forKey: .mode)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(displayProfileID, forKey: .displayProfileID)
        try container.encode(launchMissingApps, forKey: .launchMissingApps)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(variants, forKey: .variants)
    }

    enum CodingKeys: String, CodingKey {
        case id, schemaVersion, name, trigger, autoRestore, mode, isFavorite
        case displayProfileID, launchMissingApps, createdAt, updatedAt
        case windows, variants
    }
}
