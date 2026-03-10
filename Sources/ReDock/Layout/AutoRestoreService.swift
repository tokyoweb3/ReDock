import AppKit
import os

/// Monitors environment changes and triggers automatic layout restoration.
final class AutoRestoreService {
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "AutoRestore")

    private let layoutService: LayoutService
    private let contextResolver: ContextResolver
    private let diagnosticsService: DiagnosticsService
    private let displayProfileStore: DisplayProfileStore?
    private var debounceTimer: Timer?
    private var isObserving = false
    private var isRestoring = false

    init(
        layoutService: LayoutService,
        contextResolver: ContextResolver,
        diagnosticsService: DiagnosticsService,
        displayProfileStore: DisplayProfileStore? = nil
    ) {
        self.layoutService = layoutService
        self.contextResolver = contextResolver
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
        guard !isRestoring else {
            Self.logger.debug("Skipping trigger evaluation: restore already in progress")
            return
        }

        let currentFingerprints = contextResolver.resolve().displayFingerprints
        let layouts = layoutService.loadAll()

        // Find the best matching layout+variant pair with autoRestore enabled
        var bestMatch: (layout: WindowLayout, variant: DisplayVariant, score: Double)?

        for layout in layouts {
            for variant in layout.variants {
                guard variant.autoRestore, !variant.displayFingerprints.isEmpty else { continue }
                let score = LayoutService.variantMatchScore(
                    variant: variant,
                    currentFingerprints: Array(currentFingerprints)
                )
                if score > 0, score > (bestMatch?.score ?? -1) {
                    bestMatch = (layout, variant, score)
                }
            }
        }

        guard let match = bestMatch else {
            Self.logger.debug("No matching auto-restore variant for current display config")
            return
        }

        Self.logger.info("Auto-restoring layout '\(match.layout.name)' variant '\(match.variant.displayDescription)'")
        isRestoring = true

        Task {
            let result = await layoutService.restoreLayoutAsync(match.layout, variantWindows: match.variant.windows, launchApps: match.variant.launchMissingApps)
            diagnosticsService.record(result: result, triggerSource: "auto-\(match.variant.displayDescription)")
            isRestoring = false
        }
    }
}
