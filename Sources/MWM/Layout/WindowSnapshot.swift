import Foundation

/// A snapshot of a single window's state for layout save/restore.
struct WindowSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var appBundleID: String
    var appName: String
    var title: String?
    var role: String?
    var subrole: String?
    var relativeFrame: RelativeFrame
    var display: DisplayFingerprint
    var isMinimized: Bool
    var wasFullscreen: Bool
}
