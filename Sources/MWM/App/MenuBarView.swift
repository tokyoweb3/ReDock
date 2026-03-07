import SwiftUI

struct MenuBarView: View {
    @State private var savedLayouts: [WindowLayout] = []

    private var services: AppServices { AppDelegate.services }

    var body: some View {
        // Window halves
        Button("Left Half") { services.dispatcher.dispatch(.leftHalf) }
        Button("Right Half") { services.dispatcher.dispatch(.rightHalf) }
        Button("Top Half") { services.dispatcher.dispatch(.topHalf) }
        Button("Bottom Half") { services.dispatcher.dispatch(.bottomHalf) }

        Divider()

        // Quarters
        Button("Top Left") { services.dispatcher.dispatch(.topLeft) }
        Button("Top Right") { services.dispatcher.dispatch(.topRight) }
        Button("Bottom Left") { services.dispatcher.dispatch(.bottomLeft) }
        Button("Bottom Right") { services.dispatcher.dispatch(.bottomRight) }

        Divider()

        // Sizing
        Button("Center") { services.dispatcher.dispatch(.center) }
        Button("Maximize") { services.dispatcher.dispatch(.maximize) }
        Button("Full Screen") { services.dispatcher.dispatch(.toggleFullScreen) }

        Divider()

        // Focus Mode
        Button(services.focusModeService.isActive ? "Exit Focus Mode" : "Focus Mode") {
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
                        _ = services.layoutService.restoreLayout(layout)
                    }
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings...")
        }

        Button("Quit MWM") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
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
