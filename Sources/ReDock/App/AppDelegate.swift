import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let services = AppServices()
    private static let logger = Logger(subsystem: "com.ReDock.app", category: "App")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let services = Self.services
        seedDefaultPresetsIfNeeded(services)
        setupStatusBar()

        let trusted = services.permissions.check(promptIfNeeded: true)
        Self.logger.info("AX trusted: \(trusted)")

        if trusted {
            onPermissionGranted(services)
        } else {
            services.permissions.pollUntilGranted { [weak self] in
                Self.logger.info("Accessibility permission granted via polling")
                self?.onPermissionGranted(services)
            }
        }
    }

    /// Seed default preset layouts once (tracked by a marker file).
    private func seedDefaultPresetsIfNeeded(_ services: AppServices) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let marker = appSupport.appendingPathComponent("ReDock/.presets-seeded")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }

        for preset in WorkspacePreset.allCases {
            let layout = preset.toLayout(screenRegistry: services.screenRegistry)
            try? services.layoutService.save(layout)
        }

        // Write marker so we only seed once
        try? FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: marker.path, contents: nil)

        Self.logger.info("Seeded \(WorkspacePreset.allCases.count) default preset layouts")
    }

    private func onPermissionGranted(_ services: AppServices) {
        let layouts = services.layoutService.loadAll()

        // Seed workspace slot assignments (presets to slots 5-9)
        WorkspaceSlotManager.seedDefaultAssignments(layouts: layouts)

        services.hotkeyManager.registerAll()
        services.layoutShortcutManager.registerAll(layouts: layouts)
        services.autoRestoreService.startObserving()
        services.windowDragMonitor.start()

        // Auto-detect current display profile
        let fingerprints = services.screenRegistry.fingerprints()
        _ = services.displayProfileStore.findOrCreate(fingerprints: fingerprints)

        Self.logger.info("Ready: hotkeys registered, drag monitor active, auto-restore active")
    }

    static let statusBar = StatusBarController(services: AppDelegate.services)

    func setupStatusBar() {
        Self.statusBar.setup()
    }
}
