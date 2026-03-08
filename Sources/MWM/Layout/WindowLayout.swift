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
    var displayProfileID: UUID?
    var displayFingerprints: [DisplayFingerprint]
    var windows: [WindowSnapshot]
    /// Whether this variant triggers auto-restore when its display config is detected.
    var autoRestore: Bool
    /// Whether to launch missing apps when restoring this variant.
    var launchMissingApps: Bool

    init(
        id: UUID = UUID(),
        displayProfileID: UUID? = nil,
        displayFingerprints: [DisplayFingerprint],
        windows: [WindowSnapshot],
        autoRestore: Bool = false,
        launchMissingApps: Bool = false
    ) {
        self.id = id
        self.displayProfileID = displayProfileID
        self.displayFingerprints = displayFingerprints
        self.windows = windows
        self.autoRestore = autoRestore
        self.launchMissingApps = launchMissingApps
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
    static let currentSchemaVersion = 4

    var id: UUID
    var schemaVersion: Int
    var name: String
    var trigger: ContextTrigger?
    var mode: LayoutMode
    var isFavorite: Bool
    /// Linked display profile ID for display-aware restore.
    var displayProfileID: UUID?
    var createdAt: Date
    var updatedAt: Date
    /// Display-specific window arrangements.
    var variants: [DisplayVariant]

    /// True if any variant has auto-restore enabled.
    var autoRestore: Bool {
        variants.contains { $0.autoRestore }
    }

    /// True if any variant has launch-missing-apps enabled.
    var launchMissingApps: Bool {
        variants.contains { $0.launchMissingApps }
    }

    /// Convenience accessor for the first variant's windows.
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
        self.mode = mode
        self.isFavorite = isFavorite
        self.displayProfileID = displayProfileID
        self.createdAt = Date()
        self.updatedAt = Date()
        let fingerprints = Array(Set(windows.map(\.display)))
        self.variants = [DisplayVariant(
            displayFingerprints: fingerprints,
            windows: windows,
            autoRestore: autoRestore,
            launchMissingApps: launchMissingApps
        )]
    }
}
