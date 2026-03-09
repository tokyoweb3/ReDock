import Foundation

/// Shared service container.
/// Created once at app launch and shared across menus, hotkeys, and settings.
final class AppServices {
    let permissions: PermissionsService
    let appSettings: AppSettings
    let screenRegistry: ScreenRegistry
    let windowManager: WindowManager
    let windowQuerying: LiveWindowQuerying
    let dispatcher: WindowActionDispatcher
    let hotkeyManager: HotkeyManager
    let dropZoneOverlayWindow: DropZoneOverlayWindow
    let windowPlacementService: WindowPlacementService
    let windowDragMonitor: WindowDragMonitor
    let layoutStore: LayoutStore
    let layoutService: LayoutService
    let focusModeService: FocusModeService
    let autoRestoreService: AutoRestoreService

    // v2 services
    let contextResolver: ContextResolver
    let appLaunchService: AppLaunchService
    let restorePlanner: RestorePlanner
    let diagnosticsService: DiagnosticsService
    let importExportService: ImportExportService
    let workspaceService: WorkspaceService
    let layoutShortcutManager: LayoutShortcutManager
    let displayProfileStore: DisplayProfileStore

    init() {
        permissions = PermissionsService()
        appSettings = AppSettings()
        screenRegistry = ScreenRegistry()
        windowManager = WindowManager(screenRegistry: screenRegistry)
        windowQuerying = LiveWindowQuerying()
        dispatcher = WindowActionDispatcher(
            permissions: permissions,
            windowManager: windowManager,
            cycleState: ActionCycleState(timeoutProvider: { [appSettings] in
                appSettings.actionCycleTimeout
            })
        )
        hotkeyManager = HotkeyManager(dispatcher: dispatcher)
        dropZoneOverlayWindow = DropZoneOverlayWindow()
        windowPlacementService = WindowPlacementService()
        layoutStore = LayoutStore()
        appLaunchService = AppLaunchService()
        layoutService = LayoutService(store: layoutStore, screenRegistry: screenRegistry, windowQuerying: windowQuerying, appLaunchService: appLaunchService)
        windowDragMonitor = WindowDragMonitor(
            windowQuerying: windowQuerying,
            screenRegistry: screenRegistry,
            overlayWindow: dropZoneOverlayWindow,
            placementService: windowPlacementService,
            activationBandHeightProvider: { [appSettings] in
                appSettings.dropZoneActivationBandHeight
            }
        )
        focusModeService = FocusModeService(screenRegistry: screenRegistry)

        // v2
        contextResolver = ContextResolver(screenRegistry: screenRegistry)
        restorePlanner = RestorePlanner(appLaunchService: appLaunchService)
        diagnosticsService = DiagnosticsService()
        importExportService = ImportExportService(store: layoutStore)

        layoutShortcutManager = LayoutShortcutManager()
        displayProfileStore = DisplayProfileStore()

        workspaceService = WorkspaceService(
            windowQuerying: windowQuerying,
            screenRegistry: screenRegistry,
            focusModeService: focusModeService,
            diagnosticsService: diagnosticsService
        )

        autoRestoreService = AutoRestoreService(
            layoutService: layoutService,
            contextResolver: contextResolver,
            diagnosticsService: diagnosticsService,
            displayProfileStore: displayProfileStore
        )
    }
}
