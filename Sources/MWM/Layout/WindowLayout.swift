import Foundation

/// How a layout matches windows during restore.
enum LayoutMode: String, Codable, CaseIterable {
    /// Match by app bundle ID (traditional snapshot).
    case appSpecific

    /// Apply to the N most recently used windows regardless of app (Moom-style "any window").
    case template
}

/// A saved window layout containing snapshots and optional auto-restore trigger.
struct WindowLayout: Codable, Identifiable {
    static let currentSchemaVersion = 2

    var id: UUID
    var schemaVersion: Int
    var name: String
    var trigger: ContextTrigger?
    var autoRestore: Bool
    var mode: LayoutMode
    var createdAt: Date
    var updatedAt: Date
    var windows: [WindowSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        trigger: ContextTrigger? = nil,
        autoRestore: Bool = false,
        mode: LayoutMode = .appSpecific,
        windows: [WindowSnapshot]
    ) {
        self.id = id
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.trigger = trigger
        self.autoRestore = autoRestore
        self.mode = mode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.windows = windows
    }

    // Support decoding v1 layouts without mode field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        name = try container.decode(String.self, forKey: .name)
        trigger = try container.decodeIfPresent(ContextTrigger.self, forKey: .trigger)
        autoRestore = try container.decode(Bool.self, forKey: .autoRestore)
        mode = try container.decodeIfPresent(LayoutMode.self, forKey: .mode) ?? .appSpecific
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        windows = try container.decode([WindowSnapshot].self, forKey: .windows)
    }
}
