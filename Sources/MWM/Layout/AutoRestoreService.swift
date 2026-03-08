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

    /// Find all (layout, variant) pairs with autoRestore enabled that match a given display profile.
    static func findVariantConflicts(
        for layout: WindowLayout,
        variantIndex: Int,
        allLayouts: [WindowLayout]
    ) -> [(layoutName: String, variantDescription: String)] {
        guard variantIndex < layout.variants.count else { return [] }
        let variant = layout.variants[variantIndex]
        guard variant.autoRestore, let profileID = variant.displayProfileID else { return [] }

        var conflicts: [(String, String)] = []
        for other in allLayouts {
            for otherVariant in other.variants {
                // Skip self
                if otherVariant.id == variant.id { continue }
                guard otherVariant.autoRestore,
                      otherVariant.displayProfileID == profileID else { continue }
                conflicts.append((other.name, otherVariant.displayDescription))
            }
        }
        return conflicts
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

        if match.variant.launchMissingApps {
            Task {
                let launchResult = await appLaunchService.launchMissingApps(
                    for: match.layout,
                    windows: match.variant.windows
                )
                Self.logger.info("App launch: \(launchResult.summary)")

                if !launchResult.launched.isEmpty {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }

                await MainActor.run {
                    let result = layoutService.restoreLayout(match.layout, variantWindows: match.variant.windows)
                    diagnosticsService.record(result: result, triggerSource: "auto-\(match.variant.displayDescription)")
                    isRestoring = false
                }
            }
        } else {
            let result = layoutService.restoreLayout(match.layout, variantWindows: match.variant.windows)
            diagnosticsService.record(result: result, triggerSource: "auto-\(match.variant.displayDescription)")
            isRestoring = false
        }
    }
}
