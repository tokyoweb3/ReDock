import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            LayoutsSettingsView()
                .tabItem {
                    Label("Layouts", systemImage: "rectangle.3.group")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 720, height: 540)
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                // Left column
                VStack(spacing: 0) {
                    shortcutSection("Halves") {
                        shortcutRow("Left Half", icon: "rectangle.lefthalf.filled", name: .leftHalf)
                        shortcutRow("Right Half", icon: "rectangle.righthalf.filled", name: .rightHalf)
                        shortcutRow("Top Half", icon: "rectangle.tophalf.filled", name: .topHalf)
                        shortcutRow("Bottom Half", icon: "rectangle.bottomhalf.filled", name: .bottomHalf)
                    }

                    shortcutSection("Quarters") {
                        shortcutRow("Top Left", icon: "rectangle.inset.topleft.filled", name: .topLeft)
                        shortcutRow("Top Right", icon: "rectangle.inset.topright.filled", name: .topRight)
                        shortcutRow("Bottom Left", icon: "rectangle.inset.bottomleft.filled", name: .bottomLeft)
                        shortcutRow("Bottom Right", icon: "rectangle.inset.bottomright.filled", name: .bottomRight)
                    }
                }

                // Right column
                VStack(spacing: 0) {
                    shortcutSection("Sizing") {
                        shortcutRow("Maximize", icon: "rectangle.fill", name: .maximize)
                        shortcutRow("Full Screen", icon: "arrow.up.left.and.arrow.down.right", name: .toggleFullScreen)
                        shortcutRow("Center", icon: "rectangle.center.inset.filled", name: .center)
                        shortcutRow("Make Larger", icon: "plus.square", name: .increase)
                        shortcutRow("Make Smaller", icon: "minus.square", name: .decrease)
                    }

                    shortcutSection("Display") {
                        shortcutRow("Next Display", icon: "display.2", name: .nextScreen)
                        shortcutRow("Previous Display", icon: "display", name: .previousScreen)
                    }

                    shortcutSection("Focus") {
                        shortcutRow("Focus Mode", icon: "eye", name: .toggleFocusMode)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 12)
                .padding(.bottom, 4)

            VStack(spacing: 1) {
                content()
            }
            .background(Color(nsColor: .separatorColor).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func shortcutRow(_ label: String, icon: String, name: KeyboardShortcuts.Name) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            KeyboardShortcuts.Recorder(for: name)
                .frame(width: 120)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Layouts Tab

struct LayoutsSettingsView: View {
    @State private var layouts: [WindowLayout] = []
    @State private var selectedLayoutID: UUID?

    private var services: AppServices { AppDelegate.services }

    private var selectedLayout: WindowLayout? {
        guard let id = selectedLayoutID else { return nil }
        return layouts.first { $0.id == id }
    }

    var body: some View {
        HSplitView {
            // Left: layout list
            VStack(spacing: 0) {
                List(selection: $selectedLayoutID) {
                    ForEach(layouts) { layout in
                        layoutRow(layout)
                            .tag(layout.id)
                    }
                }

                // Bottom toolbar
                HStack(spacing: 4) {
                    Button(action: { deleteSelected() }) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedLayoutID == nil)
                    .help("Delete selected layout")

                    Spacer()

                    Button(action: { exportLayouts() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export layouts")

                    Button(action: { importLayouts() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import layouts")
                }
                .padding(6)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Right: editor/preview
            VStack {
                if let binding = selectedLayoutBinding {
                    ScrollView {
                        LayoutEditorView(
                            layout: binding,
                            onSave: { saveSelectedLayout() }
                        )
                        .padding(12)
                    }

                    // Bottom controls
                    VStack(spacing: 4) {
                        HStack {
                            Toggle("Auto-restore", isOn: autoRestoreBinding)
                            Spacer()
                            Button("Restore Now") {
                                let result = services.layoutService.restoreLayout(binding.wrappedValue)
                                services.diagnosticsService.record(result: result, triggerSource: "settings")
                            }
                            .controlSize(.small)
                        }

                        if binding.wrappedValue.autoRestore {
                            let conflicts = autoRestoreConflicts(for: binding.wrappedValue)
                            if !conflicts.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                    Text("Conflicts with: \(conflicts.map(\.name).joined(separator: ", "))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 32))
                            .foregroundStyle(.quaternary)
                        Text("Select a layout to edit")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
        .onAppear { refresh() }
    }

    // MARK: - Subviews

    private func layoutRow(_ layout: WindowLayout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(layout.windows.count) windows")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if layout.mode == .template {
                        Text("Template")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            if layout.autoRestore {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                    .help("Auto-restore enabled")
            }
        }
    }

    // MARK: - Bindings

    private var selectedLayoutBinding: Binding<WindowLayout>? {
        guard let id = selectedLayoutID,
              let index = layouts.firstIndex(where: { $0.id == id }) else { return nil }
        return $layouts[index]
    }

    // MARK: - Actions

    private func saveSelectedLayout() {
        guard let id = selectedLayoutID,
              let layout = layouts.first(where: { $0.id == id }) else { return }
        try? services.layoutService.save(layout)
    }

    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: {
                selectedLayout?.autoRestore ?? false
            },
            set: { newValue in
                guard let id = selectedLayoutID,
                      var layout = layouts.first(where: { $0.id == id }) else { return }
                layout.autoRestore = newValue
                if newValue && layout.trigger == nil {
                    layout.trigger = .displayConfiguration(
                        fingerprints: services.screenRegistry.fingerprints()
                    )
                }
                try? services.layoutService.save(layout)
                refresh()
            }
        )
    }

    private func autoRestoreConflicts(for layout: WindowLayout) -> [WindowLayout] {
        layouts.filter { other in
            other.id != layout.id
                && other.autoRestore
                && other.trigger != nil
                && layout.trigger != nil
                && other.trigger == layout.trigger
        }
    }

    private func deleteSelected() {
        guard let id = selectedLayoutID else { return }
        try? services.layoutService.delete(id: id)
        selectedLayoutID = nil
        refresh()
    }

    private func exportLayouts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MWM-layouts.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try services.importExportService.exportToFile(layouts, url: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func importLayouts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let validation = try services.importExportService.importFromFile(url: url)
            refresh()
            let alert = NSAlert()
            alert.messageText = "Import Complete"
            var message = "\(validation.validLayouts.count) layout(s) imported."
            if !validation.warnings.isEmpty {
                message += "\n\nWarnings:\n" + validation.warnings.joined(separator: "\n")
            }
            alert.informativeText = message
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func refresh() {
        layouts = services.layoutService.loadAll()
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersion)
                LabeledContent("Build", value: Bundle.main.buildVersion)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
