import Foundation

/// A saved window layout containing snapshots and optional auto-restore trigger.
struct WindowLayout: Codable, Identifiable {
    static let currentSchemaVersion = 1

    var id: UUID
    var schemaVersion: Int
    var name: String
    var trigger: ContextTrigger?
    var autoRestore: Bool
    var createdAt: Date
    var updatedAt: Date
    var windows: [WindowSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        trigger: ContextTrigger? = nil,
        autoRestore: Bool = false,
        windows: [WindowSnapshot]
    ) {
        self.id = id
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.trigger = trigger
        self.autoRestore = autoRestore
        self.createdAt = Date()
        self.updatedAt = Date()
        self.windows = windows
    }
}
