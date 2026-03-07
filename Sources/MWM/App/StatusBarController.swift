import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

/// Builds the menu bar status item with native NSMenu.
/// Provides proper right-aligned shortcut display via NSMenuItem.keyEquivalent.
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "MWM")
        statusItem.menu = buildMenu()
        self.statusItem = statusItem
    }

    func rebuildMenu() {
        statusItem?.menu = buildMenu()
    }

    // MARK: - Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Halves
        menu.addItem(actionItem(L10n.string("menu.leftHalf"), shortcut: .leftHalf, action: .leftHalf))
        menu.addItem(actionItem(L10n.string("menu.rightHalf"), shortcut: .rightHalf, action: .rightHalf))
        menu.addItem(actionItem(L10n.string("menu.topHalf"), shortcut: .topHalf, action: .topHalf))
        menu.addItem(actionItem(L10n.string("menu.bottomHalf"), shortcut: .bottomHalf, action: .bottomHalf))
        menu.addItem(.separator())

        // Quarters
        menu.addItem(actionItem(L10n.string("menu.topLeft"), shortcut: .topLeft, action: .topLeft))
        menu.addItem(actionItem(L10n.string("menu.topRight"), shortcut: .topRight, action: .topRight))
        menu.addItem(actionItem(L10n.string("menu.bottomLeft"), shortcut: .bottomLeft, action: .bottomLeft))
        menu.addItem(actionItem(L10n.string("menu.bottomRight"), shortcut: .bottomRight, action: .bottomRight))
        menu.addItem(.separator())

        // Sizing
        menu.addItem(actionItem(L10n.string("menu.center"), shortcut: .center, action: .center))
        menu.addItem(actionItem(L10n.string("menu.maximize"), shortcut: .maximize, action: .maximize))
        menu.addItem(actionItem(L10n.string("menu.fullScreen"), shortcut: .toggleFullScreen, action: .toggleFullScreen))
        menu.addItem(actionItem(L10n.string("menu.makeLarger"), shortcut: .increase, action: .increase))
        menu.addItem(actionItem(L10n.string("menu.makeSmaller"), shortcut: .decrease, action: .decrease))
        menu.addItem(.separator())

        // Display
        menu.addItem(actionItem(L10n.string("menu.nextDisplay"), shortcut: .nextScreen, action: .nextScreen))
        menu.addItem(actionItem(L10n.string("menu.previousDisplay"), shortcut: .previousScreen, action: .previousScreen))
        menu.addItem(.separator())

        // Focus Mode
        let focusTitle = services.focusModeService.isActive
            ? L10n.string("menu.exitFocusMode")
            : L10n.string("menu.focusMode")
        let focusItem = NSMenuItem(title: focusTitle, action: #selector(MenuTarget.toggleFocus), keyEquivalent: "")
        focusItem.target = MenuTarget.shared
        applyShortcutDisplay(focusItem, name: .toggleFocusMode)
        menu.addItem(focusItem)
        menu.addItem(.separator())

        // Workspaces (slot-based)
        let workspacesMenu = NSMenu()
        let allLayouts = services.layoutService.loadAll()
        let slotIndices = [5, 6, 7, 8, 9]
        for (shortcutName, slotIndex) in zip(workspaceSlotNames, slotIndices) {
            let layoutID = WorkspaceSlotManager.layoutID(for: slotIndex)
            let layout = layoutID.flatMap { id in allLayouts.first { $0.id == id } }
            let title = layout?.name ?? L10n.string("shortcuts.slotEmpty", slotIndex)
            let item = NSMenuItem(
                title: title,
                action: layout != nil ? #selector(MenuTarget.restoreWorkspaceSlot(_:)) : nil,
                keyEquivalent: ""
            )
            item.target = MenuTarget.shared
            item.representedObject = slotIndex as NSNumber
            applyShortcutDisplay(item, name: shortcutName)
            workspacesMenu.addItem(item)
        }
        let workspacesItem = NSMenuItem(title: L10n.string("menu.workspaces"), action: nil, keyEquivalent: "")
        workspacesItem.submenu = workspacesMenu
        menu.addItem(workspacesItem)
        menu.addItem(.separator())

        // Layout
        let saveItem = NSMenuItem(title: L10n.string("menu.saveLayout"), action: #selector(MenuTarget.saveLayout), keyEquivalent: "")
        saveItem.target = MenuTarget.shared
        menu.addItem(saveItem)

        let layouts = services.layoutService.loadAll()

        // Favorite layouts shown directly with shortcuts
        let favorites = layouts.filter(\.isFavorite)
        for layout in favorites {
            let item = NSMenuItem(title: layout.name, action: #selector(MenuTarget.restoreLayout(_:)), keyEquivalent: "")
            item.target = MenuTarget.shared
            item.representedObject = layout.id.uuidString as NSString
            applyShortcutDisplay(item, name: LayoutShortcutManager.shortcutName(for: layout.id))
            menu.addItem(item)
        }

        if !layouts.isEmpty {
            let restoreMenu = NSMenu()
            for layout in layouts {
                let item = NSMenuItem(title: layout.name, action: #selector(MenuTarget.restoreLayout(_:)), keyEquivalent: "")
                item.target = MenuTarget.shared
                item.representedObject = layout.id.uuidString as NSString
                restoreMenu.addItem(item)
            }
            let restoreItem = NSMenuItem(title: L10n.string("menu.restoreLayout"), action: nil, keyEquivalent: "")
            restoreItem.submenu = restoreMenu
            menu.addItem(restoreItem)

            let restoreWithLaunchMenu = NSMenu()
            for layout in layouts {
                let item = NSMenuItem(title: layout.name, action: #selector(MenuTarget.restoreWithLaunch(_:)), keyEquivalent: "")
                item.target = MenuTarget.shared
                item.representedObject = layout.id.uuidString as NSString
                restoreWithLaunchMenu.addItem(item)
            }
            let restoreWithLaunchItem = NSMenuItem(title: L10n.string("menu.restoreWithLaunch"), action: nil, keyEquivalent: "")
            restoreWithLaunchItem.submenu = restoreWithLaunchMenu
            menu.addItem(restoreWithLaunchItem)
        }

        menu.addItem(.separator())

        // Import/Export
        let exportItem = NSMenuItem(title: L10n.string("menu.exportLayouts"), action: #selector(MenuTarget.exportLayouts), keyEquivalent: "")
        exportItem.target = MenuTarget.shared
        menu.addItem(exportItem)

        let importItem = NSMenuItem(title: L10n.string("menu.importLayouts"), action: #selector(MenuTarget.importLayouts), keyEquivalent: "")
        importItem.target = MenuTarget.shared
        menu.addItem(importItem)

        // Diagnostics
        let recentRecords = services.diagnosticsService.recentRecords
        if !recentRecords.isEmpty {
            let diagMenu = NSMenu()
            for record in recentRecords.prefix(10) {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                let title = "\(formatter.string(from: record.timestamp)) — \(record.summary)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                diagMenu.addItem(item)
            }
            let diagItem = NSMenuItem(title: L10n.string("menu.recentRestores"), action: nil, keyEquivalent: "")
            diagItem.submenu = diagMenu
            menu.addItem(diagItem)
        }

        menu.addItem(.separator())

        // Settings & Quit
        let settingsItem = NSMenuItem(title: L10n.string("menu.settings"), action: #selector(MenuTarget.openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = MenuTarget.shared
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: L10n.string("menu.quit"), action: #selector(MenuTarget.quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = MenuTarget.shared
        menu.addItem(quitItem)

        return menu
    }

    private func actionItem(_ title: String, shortcut name: KeyboardShortcuts.Name, action: WindowAction) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuTarget.dispatchAction(_:)), keyEquivalent: "")
        item.target = MenuTarget.shared
        item.representedObject = action.rawValue as NSString
        applyShortcutDisplay(item, name: name)
        return item
    }

    private func applyShortcutDisplay(_ item: NSMenuItem, name: KeyboardShortcuts.Name) {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return }

        var modifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.control) { modifiers.insert(.control) }
        if shortcut.modifiers.contains(.option) { modifiers.insert(.option) }
        if shortcut.modifiers.contains(.command) { modifiers.insert(.command) }
        if shortcut.modifiers.contains(.shift) { modifiers.insert(.shift) }
        item.keyEquivalentModifierMask = modifiers

        // Convert carbon key code to key equivalent string
        item.keyEquivalent = keyEquivalentFromCarbon(shortcut.carbonKeyCode)
    }

    private func keyEquivalentFromCarbon(_ keyCode: Int) -> String {
        // Arrow keys and special keys use Unicode characters
        switch keyCode {
        case 123: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case 124: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case 126: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case 125: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case 36: return "\r" // Return
        case 53: return String(UnicodeScalar(27)) // Escape
        case 51: return String(UnicodeScalar(NSDeleteCharacter)!)
        default: break
        }

        // Regular keys: use TIS to translate carbon key code
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            0, // No modifiers for the base character
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard length > 0 else { return "" }
        return String(utf16CodeUnits: chars, count: length).lowercased()
    }
}

// MARK: - Menu Target

/// Objective-C target for NSMenuItem actions.
@objc final class MenuTarget: NSObject {
    static let shared = MenuTarget()

    private var services: AppServices { AppDelegate.services }

    @objc func dispatchAction(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let action = WindowAction(rawValue: rawValue) else { return }
        services.dispatcher.dispatch(action)
    }

    @objc func toggleFocus() {
        services.focusModeService.toggle()
    }

    @objc func applyWorkspace(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = WorkspacePreset(rawValue: rawValue) else { return }
        services.workspaceService.apply(preset)
    }

    @objc func restoreWorkspaceSlot(_ sender: NSMenuItem) {
        guard let slotIndex = sender.representedObject as? Int,
              let layoutID = WorkspaceSlotManager.layoutID(for: slotIndex),
              let layout = services.layoutService.loadAll().first(where: { $0.id == layoutID }) else { return }
        let result = services.layoutService.restoreLayout(layout)
        services.diagnosticsService.record(result: result, triggerSource: "workspace-slot-\(slotIndex)")
    }

    private var saveLayoutController: SaveLayoutWindowController?

    @objc func saveLayout() {
        guard services.permissions.isGranted else {
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.accessibilityRequired.title")
            alert.informativeText = L10n.string("alert.accessibilityRequired.message")
            alert.addButton(withTitle: L10n.string("alert.openSystemSettings"))
            alert.addButton(withTitle: L10n.string("alert.cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                services.permissions.openSystemSettings()
            }
            return
        }

        let capture = services.layoutService.captureWithObstructionInfo()
        if capture.snapshots.isEmpty {
            let warnAlert = NSAlert()
            warnAlert.messageText = L10n.string("alert.noWindowsFound.title")
            warnAlert.informativeText = L10n.string("alert.noWindowsFound.message")
            warnAlert.addButton(withTitle: L10n.string("alert.openSystemSettings"))
            warnAlert.addButton(withTitle: L10n.string("alert.ok"))
            if warnAlert.runModal() == .alertFirstButtonReturn {
                services.permissions.openSystemSettings()
            }
            return
        }

        let controller = SaveLayoutWindowController()
        controller.show(snapshots: capture.snapshots, obstructedIDs: capture.obstructedIDs) { [weak self] name, selected, mode in
            guard let self else { return }
            do {
                try _ = self.services.layoutService.saveLayout(name: name, snapshots: selected, mode: mode)
            } catch {
                let errorAlert = NSAlert(error: error)
                errorAlert.runModal()
            }
        }
        saveLayoutController = controller
    }

    @objc func restoreLayout(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString),
              let layout = services.layoutService.loadAll().first(where: { $0.id == uuid }) else { return }
        let result = services.layoutService.restoreLayout(layout)
        services.diagnosticsService.record(result: result, triggerSource: "manual")
    }

    @objc func restoreWithLaunch(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString),
              let layout = services.layoutService.loadAll().first(where: { $0.id == uuid }) else { return }

        Task {
            let launchResult = await services.appLaunchService.launchMissingApps(for: layout)
            if !launchResult.launched.isEmpty {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                let result = services.layoutService.restoreLayout(layout)
                services.diagnosticsService.record(result: result, triggerSource: "manual-with-launch")
            }
        }
    }

    @objc func exportLayouts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MWM-layouts.json"
        panel.title = L10n.string("dialog.exportLayouts")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let layouts = services.layoutService.loadAll()
            try services.importExportService.exportToFile(layouts, url: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc func importLayouts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = L10n.string("dialog.importLayouts")
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let validation = try services.importExportService.importFromFile(url: url)
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.importComplete.title")
            var message = L10n.string("alert.importComplete.message", validation.validLayouts.count)
            if !validation.warnings.isEmpty {
                message += L10n.string("alert.importComplete.warnings", validation.warnings.joined(separator: "\n"))
            }
            alert.informativeText = message
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
