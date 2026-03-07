import AppKit
import os

/// Monitors environment changes and triggers automatic layout restoration.
final class AutoRestoreService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "AutoRestore")

    private let layoutService: LayoutService
    private let contextResolver: ContextResolver
    private let appLaunchService: AppLaunchService
    private let diagnosticsService: DiagnosticsService
    private var debounceTimer: Timer?
    private var isObserving = false

    /// Whether to auto-launch missing apps during restore.
    var autoLaunchApps: Bool = false

    init(
        layoutService: LayoutService,
        contextResolver: ContextResolver,
        appLaunchService: AppLaunchService,
        diagnosticsService: DiagnosticsService
    ) {
        self.layoutService = layoutService
        self.contextResolver = contextResolver
        self.appLaunchService = appLaunchService
        self.diagnosticsService = diagnosticsService
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

        Self.logger.info("Started observing environment changes")
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
        let context = contextResolver.resolve()
        let layouts = layoutService.loadAll()

        for layout in layouts {
            guard layout.autoRestore else { continue }
            guard let trigger = layout.trigger else { continue }

            if trigger.matches(context) {
                Self.logger.info("Auto-restoring layout '\(layout.name)' (trigger: \(trigger.displayDescription))")

                if autoLaunchApps {
                    Task {
                        let launchResult = await appLaunchService.launchMissingApps(for: layout)
                        Self.logger.info("App launch: \(launchResult.summary)")

                        // Brief delay for launched apps to create windows
                        if !launchResult.launched.isEmpty {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                        }

                        await MainActor.run {
                            let result = layoutService.restoreLayout(layout)
                            diagnosticsService.record(result: result, triggerSource: "auto-\(trigger.displayDescription)")
                        }
                    }
                } else {
                    let result = layoutService.restoreLayout(layout)
                    diagnosticsService.record(result: result, triggerSource: "auto-\(trigger.displayDescription)")
                }
                return
            }
        }

        Self.logger.debug("No matching auto-restore layout for current context")
    }
}
