import SwiftUI

/// Window selection sheet for saving a layout.
/// Users can check/uncheck individual windows and choose the layout mode.
struct SaveLayoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var layoutName: String = ""
    @State private var mode: LayoutMode = .appSpecific
    @State private var windowSelections: [WindowSelection] = []

    let snapshots: [WindowSnapshot]
    let onSave: (String, [WindowSnapshot], LayoutMode) -> Void

    var selectedCount: Int {
        windowSelections.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Layout")
                .font(.headline)

            // Name field
            HStack {
                Text("Name:")
                    .frame(width: 50, alignment: .leading)
                TextField("My Layout", text: $layoutName)
                    .textFieldStyle(.roundedBorder)
            }

            // Mode picker
            HStack {
                Text("Mode:")
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: $mode) {
                    Text("App-Specific").tag(LayoutMode.appSpecific)
                    Text("Template (Any Window)").tag(LayoutMode.template)
                }
                .labelsHidden()
                .frame(width: 200)
            }

            if mode == .template {
                Text("Template mode applies positions to the most recently used windows, regardless of app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 54)
            }

            // Window selection list
            HStack {
                Text("Windows (\(selectedCount)/\(windowSelections.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select All") {
                    for i in windowSelections.indices { windowSelections[i].isSelected = true }
                }
                .controlSize(.mini)
                Button("Deselect All") {
                    for i in windowSelections.indices { windowSelections[i].isSelected = false }
                }
                .controlSize(.mini)
            }

            List {
                ForEach($windowSelections) { $item in
                    HStack(spacing: 8) {
                        Toggle("", isOn: $item.isSelected)
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                        if let icon = NSRunningApplication.runningApplications(
                            withBundleIdentifier: item.snapshot.appBundleID
                        ).first?.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.snapshot.appName)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            if let title = item.snapshot.title, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text(sizeLabel(item.snapshot.relativeFrame))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minHeight: 200)

            // Buttons
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
        }
        .padding()
        .frame(width: 480, height: 460)
        .onAppear {
            windowSelections = snapshots.map { WindowSelection(snapshot: $0, isSelected: true) }
        }
    }

    private func save() {
        let name = layoutName.isEmpty ? "Untitled" : layoutName
        let selected = windowSelections.filter(\.isSelected).map(\.snapshot)
        onSave(name, selected, mode)
        dismiss()
    }

    private func sizeLabel(_ frame: RelativeFrame) -> String {
        let w = Int(frame.width * 100)
        let h = Int(frame.height * 100)
        return "\(w)%x\(h)%"
    }
}

struct WindowSelection: Identifiable {
    let id = UUID()
    var snapshot: WindowSnapshot
    var isSelected: Bool
}

/// NSWindow wrapper for hosting the save layout sheet.
final class SaveLayoutWindowController {
    private var window: NSWindow?

    func show(snapshots: [WindowSnapshot], onSave: @escaping (String, [WindowSnapshot], LayoutMode) -> Void) {
        let view = SaveLayoutView(snapshots: snapshots, onSave: { name, selected, mode in
            onSave(name, selected, mode)
            self.window?.close()
        })

        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Save Layout"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
