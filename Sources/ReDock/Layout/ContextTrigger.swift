import Foundation

/// Trigger condition for automatic layout restoration.
enum ContextTrigger: Codable, Hashable {
    /// Trigger when a specific set of displays is connected.
    case displayConfiguration(fingerprints: [DisplayFingerprint])

    /// Trigger when connected to a specific Wi-Fi network.
    case wifiSSID(ssid: String)

    /// Trigger when ALL sub-conditions are met.
    case compound(conditions: [ContextTrigger])
}

// MARK: - Trigger Evaluation

extension ContextTrigger {
    /// Evaluate whether this trigger matches the current environment.
    func matches(_ context: EnvironmentContext) -> Bool {
        switch self {
        case .displayConfiguration(let requiredFingerprints):
            guard requiredFingerprints.count == context.displayFingerprints.count else { return false }
            for required in requiredFingerprints {
                let hasMatch = context.displayFingerprints.contains { current in
                    current.approximatelyMatches(required)
                }
                if !hasMatch { return false }
            }
            return true

        case .wifiSSID(let ssid):
            return context.wifiSSID == ssid

        case .compound(let conditions):
            return conditions.allSatisfy { $0.matches(context) }
        }
    }

    /// Human-readable description for UI display.
    var displayDescription: String {
        switch self {
        case .displayConfiguration(let fingerprints):
            let names = fingerprints.compactMap(\.localizedName)
            if names.isEmpty {
                return "\(fingerprints.count) display(s)"
            }
            return names.joined(separator: " + ")

        case .wifiSSID(let ssid):
            return "Wi-Fi: \(ssid)"

        case .compound(let conditions):
            return conditions.map(\.displayDescription).joined(separator: " AND ")
        }
    }
}
