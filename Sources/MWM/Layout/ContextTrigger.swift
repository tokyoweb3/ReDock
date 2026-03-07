import Foundation

/// Trigger condition for automatic layout restoration.
enum ContextTrigger: Codable, Hashable {
    /// Trigger when a specific set of displays is connected.
    case displayConfiguration(fingerprints: [DisplayFingerprint])
}
