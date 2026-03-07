import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @State private var savedLayouts: [WindowLayout] = []

    private var services: AppServices { AppDelegate.services }

    var body: some View {
        // Window halves
        menuItem("Left Half", shortcut: .leftHalf) { services.dispatcher.dispatch(.leftHalf) }
        menuItem("Right Half", shortcut: .rightHalf) { services.dispatcher.dispatch(.rightHalf) }
        menuItem("Top Half", shortcut: .topHalf) { services.dispatcher.dispatch(.topHalf) }
        menuItem("Bottom Half", shortcut: .bottomHalf) { services.dispatcher.dispatch(.bottomHalf) }

        Divider()

        // Quarters
        menuItem("Top Left", shortcut: .topLeft) { services.dispatcher.dispatch(.topLeft) }
        menuItem("Top Right", shortcut: .topRight) { services.dispatcher.dispatch(.topRight) }
        menuItem("Bottom Left", shortcut: .bottomLeft) { services.dispatcher.dispatch(.bottomLeft) }
        menuItem("Bottom Right", shortcut: .bottomRight) { services.dispatcher.dispatch(.bottomRight) }

        Divider()

        // Sizing
        menuItem("Center", shortcut: .center) { services.dispatcher.dispatch(.center) }
        menuItem("Maximize", shortcut: .maximize) { services.dispatcher.dispatch(.maximize) }
        menuItem("Full Screen", shortcut: .toggleFullScreen) { services.dispatcher.dispatch(.toggleFullScreen) }
        menuItem("Make Larger", shortcut: .increase) { services.dispatcher.dispatch(.increase) }
        menuItem("Make Smaller", shortcut: .decrease) { services.dispatcher.dispatch(.decrease) }

        Divider()

        // Display
        menuItem("Next Display", shortcut: .nextScreen) { services.dispatcher.dispatch(.nextScreen) }
        menuItem("Previous Display", shortcut: .previousScreen) { services.dispatcher.dispatch(.previousScreen) }

        Divider()

        // Focus Mode
        menuItem(
            services.focusModeService.isActive ? "Exit Focus Mode" : "Focus Mode",
            shortcut: .toggleFocusMode
        ) {
            services.focusModeService.toggle()
        }

        Divider()

        // Layout save/restore
        Button("Save Layout...") {
            promptSaveLayout()
        }

        if !savedLayouts.isEmpty {
            Menu("Restore Layout") {
                ForEach(savedLayouts) { layout in
                    Button(layout.name) {
                        let result = services.layoutService.restoreLayout(layout)
                        services.diagnosticsService.record(result: result, triggerSource: "manual")
                    }
                }
            }
        }

        Divider()

        Button("Export Layouts...") {
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

        Button("Import Layouts...") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                let validation = try services.importExportService.importFromFile(url: url)
                refreshLayouts()
                let alert = NSAlert()
                alert.messageText = "Import Complete"
                alert.informativeText = "\(validation.validLayouts.count) layout(s) imported."
                alert.runModal()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }

        Divider()

        Button("Settings...") {
            SettingsWindowController.shared.show()
        }

        Button("Quit MWM") {
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
        alert.messageText = "Save Current Layout"
        alert.informativeText = "Enter a name for this layout:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "My Layout"
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
