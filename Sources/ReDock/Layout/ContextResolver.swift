import AppKit
import CoreWLAN
import os

/// Resolved environment context for trigger evaluation.
struct EnvironmentContext: Equatable {
    var displayFingerprints: Set<DisplayFingerprint>
    var wifiSSID: String?
}

/// Resolves the current environment context from multiple sources.
final class ContextResolver {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "ContextResolver")

    private let screenRegistry: ScreenRegistry

    init(screenRegistry: ScreenRegistry) {
        self.screenRegistry = screenRegistry
    }

    /// Capture the current environment context.
    func resolve() -> EnvironmentContext {
        let fingerprints = Set(screenRegistry.fingerprints())
        let ssid = currentWiFiSSID()

        Self.logger.debug("Context: \(fingerprints.count) display(s), Wi-Fi=\(ssid ?? "none")")

        return EnvironmentContext(
            displayFingerprints: fingerprints,
            wifiSSID: ssid
        )
    }

    /// Get the current Wi-Fi SSID using CoreWLAN.
    /// Returns nil if Wi-Fi is off or unavailable.
    private func currentWiFiSSID() -> String? {
        guard let interface = CWWiFiClient.shared().interface() else { return nil }
        return interface.ssid()
    }
}
