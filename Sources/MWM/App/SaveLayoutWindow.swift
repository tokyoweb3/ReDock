import SwiftUI

/// Window selection sheet for saving a layout.
/// Users can check/uncheck individual windows and choose the layout mode.
struct SaveLayoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var layoutName: String = ""
    @State private var mode: LayoutMode = .appSpecific
    @State private var ignoreObstructed: Bool = false
    @State private var windowSelections: [WindowSelection] = []

    let snapshots: [WindowSnapshot]
    /// Bundle IDs of windows that are fully obstructed (hidden behind others).
    let obstructedBundleIDs: Set<UUID>
    let onSave: (String, [WindowSnapshot], LayoutMode) -> Void

    var selectedCount: Int {
        windowSelections.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("saveLayout.title"))
                .font(.headline)

            // Name field
            HStack {
                Text(L10n.string("saveLayout.name"))
                    .frame(width: 50, alignment: .leading)
                TextField(L10n.string("saveLayout.namePlaceholder"), text: $layoutName)
                    .textFieldStyle(.roundedBorder)
            }

            // Mode picker
            HStack {
                Text(L10n.string("saveLayout.mode"))
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: $mode) {
                    Text(L10n.string("saveLayout.appSpecific")).tag(LayoutMode.appSpecific)
                    Text(L10n.string("saveLayout.template")).tag(LayoutMode.template)
                }
                .labelsHidden()
                .frame(width: 200)
            }

            if mode == .template {
                Text(L10n.string("saveLayout.templateDescription"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 54)
            }

            // Ignore obstructed windows option
            if !obstructedBundleIDs.isEmpty {
                Toggle(L10n.string("saveLayout.ignoreObstructed"), isOn: $ignoreObstructed)
                    .font(.system(size: 12))
                    .onChange(of: ignoreObstructed) { _, newValue in
                        applyObstructedFilter(newValue)
                    }

                if ignoreObstructed {
                    Text(L10n.string("saveLayout.ignoreObstructedHint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            }

            // Window selection list
            HStack {
                Text(L10n.string("saveLayout.windows", selectedCount, windowSelections.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.string("saveLayout.selectAll")) {
                    for i in windowSelections.indices { windowSelections[i].isSelected = true }
                }
                .controlSize(.mini)
                Button(L10n.string("saveLayout.deselectAll")) {
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

                        if item.isObstructed {
                            Text(L10n.string("saveLayout.obstructedBadge"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.5))
                                .clipShape(Capsule())
                        }

                        Text(sizeLabel(item.snapshot.relativeFrame))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .opacity(ignoreObstructed && item.isObstructed ? 0.4 : 1.0)
                }
            }
            .frame(minHeight: 200)

            // Buttons
            HStack {
                Spacer()
                Button(L10n.string("alert.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("saveLayout.save")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
        }
        .padding()
        .frame(width: 480, height: 460)
        .onAppear {
            windowSelections = snapshots.map {
                WindowSelection(
                    snapshot: $0,
                    isSelected: true,
                    isObstructed: obstructedBundleIDs.contains($0.id)
                )
            }
        }
    }

    private func save() {
        let name = layoutName.isEmpty ? "Untitled" : layoutName
        let selected = windowSelections
            .filter { $0.isSelected && !(ignoreObstructed && $0.isObstructed) }
            .map(\.snapshot)
        onSave(name, selected, mode)
        dismiss()
    }

    private func applyObstructedFilter(_ ignore: Bool) {
        for i in windowSelections.indices {
            if windowSelections[i].isObstructed {
                windowSelections[i].isSelected = !ignore
            }
        }
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
    var isObstructed: Bool = false
}

/// NSWindow wrapper for hosting the save layout sheet.
final class SaveLayoutWindowController {
    private var window: NSWindow?

    func show(snapshots: [WindowSnapshot], obstructedIDs: Set<UUID> = [], onSave: @escaping (String, [WindowSnapshot], LayoutMode) -> Void) {
        let view = SaveLayoutView(snapshots: snapshots, obstructedBundleIDs: obstructedIDs, onSave: { name, selected, mode in
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
        window.title = L10n.string("window.saveLayout")
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
