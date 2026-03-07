import AppKit
import os

/// Monitors display configuration changes and triggers automatic layout restoration.
final class AutoRestoreService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "AutoRestore")

    private let layoutService: LayoutService
    private let screenRegistry: ScreenRegistry
    private var debounceTimer: Timer?
    private var isObserving = false

    init(layoutService: LayoutService, screenRegistry: ScreenRegistry) {
        self.layoutService = layoutService
        self.screenRegistry = screenRegistry
    }

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        Self.logger.info("Started observing display configuration changes")
    }

    func stopObserving() {
        isObserving = false
        debounceTimer?.invalidate()
        debounceTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private

    @objc private func screenConfigurationChanged(_ notification: Notification) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.evaluateTriggers()
        }
    }

    private func evaluateTriggers() {
        let currentFingerprints = Set(screenRegistry.fingerprints())
        let layouts = layoutService.loadAll()

        for layout in layouts {
            guard layout.autoRestore else { continue }
            guard let trigger = layout.trigger else { continue }

            if matches(trigger: trigger, currentFingerprints: currentFingerprints) {
                Self.logger.info("Auto-restoring layout '\(layout.name)' due to display match")
                let result = layoutService.restoreLayout(layout)
                Self.logger.info("Auto-restore result: \(result.summary)")
                return
            }
        }

        Self.logger.debug("No matching auto-restore layout for current display configuration")
    }

    private func matches(trigger: ContextTrigger, currentFingerprints: Set<DisplayFingerprint>) -> Bool {
        switch trigger {
        case .displayConfiguration(let requiredFingerprints):
            guard requiredFingerprints.count == currentFingerprints.count else { return false }
            for required in requiredFingerprints {
                let hasMatch = currentFingerprints.contains { current in
                    current.approximatelyMatches(required)
                }
                if !hasMatch { return false }
            }
            return true
        }
    }
}
