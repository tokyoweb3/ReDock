import Foundation

/// Shared service container.
/// Created once at app launch and shared across menus, hotkeys, and settings.
final class AppServices {
    let permissions: PermissionsService
    let screenRegistry: ScreenRegistry
    let windowManager: WindowManager
    let windowQuerying: LiveWindowQuerying
    let dispatcher: WindowActionDispatcher
    let hotkeyManager: HotkeyManager
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

    init() {
        permissions = PermissionsService()
        screenRegistry = ScreenRegistry()
        windowManager = WindowManager(screenRegistry: screenRegistry)
        windowQuerying = LiveWindowQuerying()
        dispatcher = WindowActionDispatcher(permissions: permissions, windowManager: windowManager)
        hotkeyManager = HotkeyManager(dispatcher: dispatcher)
        layoutStore = LayoutStore()
        layoutService = LayoutService(store: layoutStore, screenRegistry: screenRegistry, windowQuerying: windowQuerying)
        focusModeService = FocusModeService(screenRegistry: screenRegistry)

        // v2
        contextResolver = ContextResolver(screenRegistry: screenRegistry)
        appLaunchService = AppLaunchService()
        restorePlanner = RestorePlanner(appLaunchService: appLaunchService)
        diagnosticsService = DiagnosticsService()
        importExportService = ImportExportService(store: layoutStore)

        autoRestoreService = AutoRestoreService(
            layoutService: layoutService,
            contextResolver: contextResolver,
            appLaunchService: appLaunchService,
            diagnosticsService: diagnosticsService
        )
    }
}
