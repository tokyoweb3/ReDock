import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @State private var savedLayouts: [WindowLayout] = []

    private var services: AppServices { AppDelegate.services }

    var body: some View {
        // Window halves
        menuItem(L10n.string("menu.leftHalf"), shortcut: .leftHalf) { services.dispatcher.dispatch(.leftHalf) }
        menuItem(L10n.string("menu.rightHalf"), shortcut: .rightHalf) { services.dispatcher.dispatch(.rightHalf) }
        menuItem(L10n.string("menu.topHalf"), shortcut: .topHalf) { services.dispatcher.dispatch(.topHalf) }
        menuItem(L10n.string("menu.bottomHalf"), shortcut: .bottomHalf) { services.dispatcher.dispatch(.bottomHalf) }

        Divider()

        // Quarters
        menuItem(L10n.string("menu.topLeft"), shortcut: .topLeft) { services.dispatcher.dispatch(.topLeft) }
        menuItem(L10n.string("menu.topRight"), shortcut: .topRight) { services.dispatcher.dispatch(.topRight) }
        menuItem(L10n.string("menu.bottomLeft"), shortcut: .bottomLeft) { services.dispatcher.dispatch(.bottomLeft) }
        menuItem(L10n.string("menu.bottomRight"), shortcut: .bottomRight) { services.dispatcher.dispatch(.bottomRight) }

        Divider()

        // Sizing
        menuItem(L10n.string("menu.center"), shortcut: .center) { services.dispatcher.dispatch(.center) }
        menuItem(L10n.string("menu.maximize"), shortcut: .maximize) { services.dispatcher.dispatch(.maximize) }
        menuItem(L10n.string("menu.fullScreen"), shortcut: .toggleFullScreen) { services.dispatcher.dispatch(.toggleFullScreen) }
        menuItem(L10n.string("menu.makeLarger"), shortcut: .increase) { services.dispatcher.dispatch(.increase) }
        menuItem(L10n.string("menu.makeSmaller"), shortcut: .decrease) { services.dispatcher.dispatch(.decrease) }

        Divider()

        // Display
        menuItem(L10n.string("menu.nextDisplay"), shortcut: .nextScreen) { services.dispatcher.dispatch(.nextScreen) }
        menuItem(L10n.string("menu.previousDisplay"), shortcut: .previousScreen) { services.dispatcher.dispatch(.previousScreen) }

        Divider()

        // Focus Mode
        menuItem(
            services.focusModeService.isActive
                ? L10n.string("menu.exitFocusMode")
                : L10n.string("menu.focusMode"),
            shortcut: .toggleFocusMode
        ) {
            services.focusModeService.toggle()
        }

        Divider()

        // Layout save/restore
        Button(L10n.string("menu.saveLayout")) {
            promptSaveLayout()
        }

        if !savedLayouts.isEmpty {
            Menu(L10n.string("menu.restoreLayout")) {
                ForEach(savedLayouts) { layout in
                    Button(layout.name) {
                        Task {
                            let result = await services.layoutService.restoreLayoutAsync(layout)
                            services.diagnosticsService.record(result: result, triggerSource: "manual")
                        }
                    }
                }
            }
        }

        Divider()

        Button(L10n.string("menu.exportLayouts")) {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "MWM-layouts.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try services.importExportService.exportToFile(savedLayouts, url: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }

        Button(L10n.string("menu.importLayouts")) {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                let validation = try services.importExportService.importFromFile(url: url)
                refreshLayouts()
                let alert = NSAlert()
                alert.messageText = L10n.string("alert.importComplete.title")
                alert.informativeText = L10n.string("alert.importComplete.message", validation.validLayouts.count)
                alert.runModal()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }

        Divider()

        Button(L10n.string("menu.settings")) {
            SettingsWindowController.shared.show()
        }

        Button(L10n.string("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear { refreshLayouts() }
    }

    // MARK: - Helpers

    private func menuItem(_ label: String, shortcut name: KeyboardShortcuts.Name, action: @escaping () -> Void) -> some View {
        let shortcutText = KeyboardShortcuts.getShortcut(for: name)?.description ?? ""
        let title = shortcutText.isEmpty ? label : "\(label)\t\(shortcutText)"
        return Button(title, action: action)
    }

    private func promptSaveLayout() {
        let alert = NSAlert()
        alert.messageText = L10n.string("menuBar.saveCurrentLayout")
        alert.informativeText = L10n.string("menuBar.enterLayoutName")
        alert.addButton(withTitle: L10n.string("saveLayout.save"))
        alert.addButton(withTitle: L10n.string("alert.cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = L10n.string("saveLayout.namePlaceholder")
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.isEmpty ? "Untitled" : textField.stringValue
            do {
                try _ = services.layoutService.saveCurrentLayout(name: name)
                refreshLayouts()
            } catch {
                let errorAlert = NSAlert(error: error)
                errorAlert.runModal()
            }
        }
    }

    private func refreshLayouts() {
        savedLayouts = services.layoutService.loadAll()
    }
}
