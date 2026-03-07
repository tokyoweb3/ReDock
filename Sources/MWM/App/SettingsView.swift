import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
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
        .frame(width: 500, height: 550)
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Halves") {
                shortcutRow("Left Half", name: .leftHalf)
                shortcutRow("Right Half", name: .rightHalf)
                shortcutRow("Top Half", name: .topHalf)
                shortcutRow("Bottom Half", name: .bottomHalf)
            }

            Section("Quarters") {
                shortcutRow("Top Left", name: .topLeft)
                shortcutRow("Top Right", name: .topRight)
                shortcutRow("Bottom Left", name: .bottomLeft)
                shortcutRow("Bottom Right", name: .bottomRight)
            }

            Section("Sizing") {
                shortcutRow("Center", name: .center)
                shortcutRow("Maximize", name: .maximize)
                shortcutRow("Full Screen", name: .toggleFullScreen)
                shortcutRow("Increase Size", name: .increase)
                shortcutRow("Decrease Size", name: .decrease)
            }

            Section("Display") {
                shortcutRow("Next Screen", name: .nextScreen)
                shortcutRow("Previous Screen", name: .previousScreen)
            }

            Section("Focus") {
                shortcutRow("Toggle Focus Mode", name: .toggleFocusMode)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutRow(_ label: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(label)
                .frame(width: 160, alignment: .leading)
            KeyboardShortcuts.Recorder(for: name)
        }
    }
}

// MARK: - Layouts Tab

struct LayoutsSettingsView: View {
    @State private var layouts: [WindowLayout] = []
    @State private var selectedLayoutID: UUID?

    private var services: AppServices { AppDelegate.services }

    var body: some View {
        VStack(alignment: .leading) {
            List(selection: $selectedLayoutID) {
                ForEach(layouts) { layout in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(layout.name)
                                .font(.headline)
                            Text("\(layout.windows.count) windows")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if layout.autoRestore {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.blue)
                                .help("Auto-restore enabled")
                        }
                    }
                    .tag(layout.id)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("Delete") {
                    deleteSelected()
                }
                .disabled(selectedLayoutID == nil)

                Spacer()

                Toggle("Auto-restore", isOn: autoRestoreBinding)
                    .disabled(selectedLayoutID == nil)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear { refresh() }
    }

    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: {
                guard let id = selectedLayoutID else { return false }
                return layouts.first { $0.id == id }?.autoRestore ?? false
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

    private func deleteSelected() {
        guard let id = selectedLayoutID else { return }
        try? services.layoutService.delete(id: id)
        selectedLayoutID = nil
        refresh()
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
