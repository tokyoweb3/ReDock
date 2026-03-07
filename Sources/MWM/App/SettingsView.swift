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
        .frame(width: 620, height: 480)
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
