import AppKit
import os

/// Monitors environment changes and triggers automatic layout restoration.
final class AutoRestoreService {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "AutoRestore")

    private let layoutService: LayoutService
    private let contextResolver: ContextResolver
    private let appLaunchService: AppLaunchService
    private let diagnosticsService: DiagnosticsService
    private let displayProfileStore: DisplayProfileStore?
    private var debounceTimer: Timer?
    private var isObserving = false
    private var isRestoring = false

    /// Whether to auto-launch missing apps during restore.
    var autoLaunchApps: Bool = false

    init(
        layoutService: LayoutService,
        contextResolver: ContextResolver,
        appLaunchService: AppLaunchService,
        diagnosticsService: DiagnosticsService,
        displayProfileStore: DisplayProfileStore? = nil
    ) {
        self.layoutService = layoutService
        self.contextResolver = contextResolver
        self.appLaunchService = appLaunchService
        self.diagnosticsService = diagnosticsService
        self.displayProfileStore = displayProfileStore
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
            self?.autoDetectDisplayProfile()
            self?.evaluateTriggers()
        }
    }

    /// Auto-detect and register the current display configuration as a profile.
    private func autoDetectDisplayProfile() {
        guard let store = displayProfileStore else { return }
        let fingerprints = contextResolver.resolve().displayFingerprints
        _ = store.findOrCreate(fingerprints: Array(fingerprints))
        Self.logger.debug("Display profile auto-detected for \(fingerprints.count) display(s)")
    }

    /// Find all layouts whose trigger matches the current context.
    func findConflicts() -> [WindowLayout] {
        let context = contextResolver.resolve()
        return layoutService.loadAll().filter { layout in
            guard layout.autoRestore, let trigger = layout.trigger else { return false }
            return trigger.matches(context)
        }
    }

    private func evaluateTriggers() {
        // Guard against concurrent restore operations
        guard !isRestoring else {
            Self.logger.debug("Skipping trigger evaluation: restore already in progress")
            return
        }

        let context = contextResolver.resolve()
        let layouts = layoutService.loadAll()

        let matching = layouts.filter { layout in
            guard layout.autoRestore, let trigger = layout.trigger else { return false }
            return trigger.matches(context)
        }

        if matching.count > 1 {
            let names = matching.map(\.name).joined(separator: ", ")
            Self.logger.warning("Multiple auto-restore layouts match: \(names). Using most recently updated.")
        }

        guard let layout = matching.first, let trigger = layout.trigger else {
            Self.logger.debug("No matching auto-restore layout for current context")
            return
        }

        Self.logger.info("Auto-restoring layout '\(layout.name)' (trigger: \(trigger.displayDescription))")
        isRestoring = true

        if autoLaunchApps {
            Task {
                let launchResult = await appLaunchService.launchMissingApps(for: layout)
                Self.logger.info("App launch: \(launchResult.summary)")

                if !launchResult.launched.isEmpty {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }

                await MainActor.run {
                    let result = layoutService.restoreLayout(layout)
                    diagnosticsService.record(result: result, triggerSource: "auto-\(trigger.displayDescription)")
                    isRestoring = false
                }
            }
        } else {
            let result = layoutService.restoreLayout(layout)
            diagnosticsService.record(result: result, triggerSource: "auto-\(trigger.displayDescription)")
            isRestoring = false
        }
    }
}
