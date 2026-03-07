import SwiftUI

// MARK: - Read-only Minimap

/// Minimap preview of a saved window layout, showing window positions on each display.
struct LayoutPreviewView: View {
    let windows: [WindowSnapshot]
    var selectedWindowID: UUID? = nil
    var highlightColor: ((WindowSnapshot) -> Color)? = nil

    private var displayGroups: [DisplayGroup] {
        buildDisplayGroups(from: windows)
    }

    var body: some View {
        if windows.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                let arranged = arrangeDisplays(displayGroups, in: geo.size)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(arranged.enumerated()), id: \.offset) { _, item in
                        displayView(item: item, containerSize: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No windows in layout")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func displayView(item: ArrangedDisplay, containerSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            VStack {
                Text(item.group.fingerprint.localizedName ?? "Display")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                Spacer()
            }
            .frame(width: item.rect.width)

            ForEach(item.group.windows) { window in
                staticWindowTile(window: window, displayRect: item.rect)
            }
        }
        .frame(width: item.rect.width, height: item.rect.height)
        .position(
            x: item.rect.midX,
            y: item.rect.midY
        )
    }

    private func staticWindowTile(window: WindowSnapshot, displayRect: CGRect) -> some View {
        let tileRect = tileFrame(for: window.relativeFrame, in: displayRect)
        let color = highlightColor?(window) ?? windowColor(for: window)
        let isSelected = window.id == selectedWindowID

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(isSelected ? 0.45 : 0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(color.opacity(isSelected ? 1.0 : 0.6), lineWidth: isSelected ? 1.5 : 0.5)
                )

            Text(window.appName.prefix(12))
                .font(.system(size: max(min(tileRect.height * 0.35, 9), 6)))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 2)
                .padding(.top, 1)
        }
        .frame(width: tileRect.width, height: tileRect.height)
        .offset(x: tileRect.origin.x, y: tileRect.origin.y)
        .help("\(window.appName)\(window.title.map { " — \($0)" } ?? "")")
    }
}

// MARK: - Interactive Editor Minimap

/// Editable minimap where windows can be dragged to reposition (supports cross-display moves).
struct LayoutEditorPreview: View {
    @Binding var windows: [WindowSnapshot]
    @Binding var selectedWindowID: UUID?

    @State private var dragStartFrame: RelativeFrame?
    @State private var dragStartDisplayRect: CGRect?
    @State private var dragStartArranged: [ArrangedDisplay]?

    private var displayGroups: [DisplayGroup] {
        buildDisplayGroups(from: windows)
    }

    var body: some View {
        if windows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text("Add windows using the + button below")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                let liveArranged = arrangeDisplays(displayGroups, in: geo.size)
                let arranged = dragStartArranged ?? liveArranged
                ZStack(alignment: .topLeading) {
                    // Display backgrounds (stable during drag)
                    ForEach(Array(arranged.enumerated()), id: \.offset) { _, item in
                        displayBackground(item: item)
                    }

                    // Window tiles in flat layer (stable identity during cross-display drag)
                    ForEach(windows) { window in
                        let dispRect = displayRect(for: window, in: arranged)
                        draggableWindowTile(window: window, displayRect: dispRect, allArranged: arranged)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedWindowID = nil
                }
            }
        }
    }

    private func displayBackground(item: ArrangedDisplay) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            VStack {
                Text(item.group.fingerprint.localizedName ?? "Display")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                Spacer()
            }
            .frame(width: item.rect.width)
        }
        .frame(width: item.rect.width, height: item.rect.height)
        .position(x: item.rect.midX, y: item.rect.midY)
    }

    private func displayRect(for window: WindowSnapshot, in arranged: [ArrangedDisplay]) -> CGRect {
        arranged.first { $0.group.fingerprint == window.display }?.rect
            ?? arranged.first?.rect ?? .zero
    }

    private func draggableWindowTile(window: WindowSnapshot, displayRect: CGRect, allArranged: [ArrangedDisplay]) -> some View {
        let tileRect = tileFrame(for: window.relativeFrame, in: displayRect)
        let absX = displayRect.origin.x + tileRect.origin.x
        let absY = displayRect.origin.y + tileRect.origin.y
        let color = windowColor(for: window)
        let isSelected = window.id == selectedWindowID

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(isSelected ? 0.45 : 0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(color.opacity(isSelected ? 1.0 : 0.6), lineWidth: isSelected ? 1.5 : 0.5)
                )

            Text(window.appName.prefix(12))
                .font(.system(size: max(min(tileRect.height * 0.35, 9), 6)))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 2)
                .padding(.top, 1)
        }
        .frame(width: tileRect.width, height: tileRect.height)
        .offset(x: absX, y: absY)
        .gesture(
            DragGesture()
                .onChanged { value in
                    selectedWindowID = window.id
                    if dragStartFrame == nil {
                        dragStartFrame = window.relativeFrame
                        dragStartDisplayRect = displayRect
                        dragStartArranged = allArranged
                    }
                    updatePosition(windowID: window.id, translation: value.translation)
                }
                .onEnded { _ in
                    dragStartFrame = nil
                    dragStartDisplayRect = nil
                    dragStartArranged = nil
                }
        )
        .onTapGesture {
            selectedWindowID = window.id
        }
        .help("\(window.appName)\(window.title.map { " — \($0)" } ?? "")")
    }

    private func updatePosition(windowID: UUID, translation: CGSize) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }),
              let startFrame = dragStartFrame,
              let startDisplayRect = dragStartDisplayRect,
              let startArranged = dragStartArranged else { return }

        // Absolute tile position at drag start
        let startTile = tileFrame(for: startFrame, in: startDisplayRect)
        let startAbsX = startDisplayRect.origin.x + startTile.origin.x
        let startAbsY = startDisplayRect.origin.y + startTile.origin.y

        // New absolute position from cumulative translation
        let newAbsX = startAbsX + translation.width
        let newAbsY = startAbsY + translation.height
        let centerX = newAbsX + startTile.width / 2
        let centerY = newAbsY + startTile.height / 2

        // Hit-test: find which display the tile center is over
        let targetArranged = startArranged.first { $0.rect.contains(CGPoint(x: centerX, y: centerY)) }
            ?? startArranged.first { $0.group.fingerprint == windows[index].display }
            ?? startArranged[0]

        let targetRect = targetArranged.rect
        let inset: CGFloat = 2
        let usableWidth = targetRect.width - inset * 2
        let usableHeight = targetRect.height - 14 - inset
        guard usableWidth > 0, usableHeight > 0 else { return }

        // Convert absolute position to relative within target display
        let relX = (newAbsX - targetRect.origin.x - inset) / usableWidth
        let relY = (newAbsY - targetRect.origin.y - 14) / usableHeight

        var updated = windows[index]
        updated.relativeFrame = RelativeFrame(
            x: max(0, min(1 - startFrame.width, relX)),
            y: max(0, min(1 - startFrame.height, relY)),
            width: startFrame.width,
            height: startFrame.height
        )
        updated.display = targetArranged.group.fingerprint
        windows[index] = updated
    }
}

// MARK: - Layout Detail / Editor Panel

/// Editable detail panel: minimap editor, window list with delete, add window.
struct LayoutEditorView: View {
    @Binding var layout: WindowLayout
    @State private var selectedWindowID: UUID?
    @State private var showingAddWindow = false
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Interactive minimap
            LayoutEditorPreview(
                windows: $layout.windows,
                selectedWindowID: $selectedWindowID
            )
            .frame(height: 180)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            // Preset position buttons (when a window is selected)
            if selectedWindowID != nil {
                presetButtons
            }

            // Layout name
            HStack {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("Layout name", text: $layout.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { onSave() }
                    .onChange(of: layout.name) { _, _ in onSave() }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                metaRow("Windows", value: "\(layout.windows.count)")
                metaRow("Created", value: formatted(layout.createdAt))

                HStack {
                    Text("Mode")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Picker("", selection: $layout.mode) {
                        Text("App-Specific").tag(LayoutMode.appSpecific)
                        Text("Template").tag(LayoutMode.template)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: layout.mode) { _, _ in onSave() }
                }

                if layout.mode == .template {
                    Text("Applies to the most recently used windows, regardless of app.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 60)
                }

                if let trigger = layout.trigger {
                    metaRow("Trigger", value: trigger.displayDescription)
                }
            }

            // Update from current button
            Button(action: { updateFromCurrent() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Update from Current Windows")
                        .font(.system(size: 11))
                }
            }
            .controlSize(.small)
            .help("Update positions from currently open windows")

            // Window list header
            HStack {
                Text("Windows")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { showingAddWindow = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .controlSize(.small)
                .help("Add window from running apps")
            }

            // Editable window list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(layout.windows) { window in
                        editableWindowRow(window)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .sheet(isPresented: $showingAddWindow) {
            AddWindowSheet(
                onAdd: { snapshot in
                    layout.windows.append(snapshot)
                    onSave()
                }
            )
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        HStack(spacing: 4) {
            Text("Snap:")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            presetButton("L½", x: 0, y: 0, w: 0.5, h: 1)
            presetButton("R½", x: 0.5, y: 0, w: 0.5, h: 1)
            presetButton("T½", x: 0, y: 0, w: 1, h: 0.5)
            presetButton("B½", x: 0, y: 0.5, w: 1, h: 0.5)
            presetButton("TL", x: 0, y: 0, w: 0.5, h: 0.5)
            presetButton("TR", x: 0.5, y: 0, w: 0.5, h: 0.5)
            presetButton("BL", x: 0, y: 0.5, w: 0.5, h: 0.5)
            presetButton("BR", x: 0.5, y: 0.5, w: 0.5, h: 0.5)
            presetButton("Max", x: 0, y: 0, w: 1, h: 1)
        }
    }

    private func presetButton(_ label: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        Button(label) {
            guard let id = selectedWindowID,
                  let index = layout.windows.firstIndex(where: { $0.id == id }) else { return }
            var updated = layout.windows[index]
            updated.relativeFrame = RelativeFrame(x: x, y: y, width: w, height: h)
            layout.windows[index] = updated
            onSave()
        }
        .controlSize(.mini)
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }

    // MARK: - Window Row

    private func editableWindowRow(_ window: WindowSnapshot) -> some View {
        let isSelected = window.id == selectedWindowID

        return HStack(spacing: 6) {
            Circle()
                .fill(windowColor(for: window))
                .frame(width: 8, height: 8)

            Text(window.appName)
                .font(.system(size: 11))
                .lineLimit(1)

            if let title = window.title, !title.isEmpty {
                Text("— \(title)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(positionLabel(window.relativeFrame))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Button(action: { removeWindow(id: window.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from layout")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected
            ? Color.accentColor.opacity(0.1)
            : Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedWindowID = window.id
        }
    }

    private func removeWindow(id: UUID) {
        layout.windows.removeAll { $0.id == id }
        if selectedWindowID == id {
            selectedWindowID = nil
        }
        onSave()
    }

    private func updateFromCurrent() {
        do {
            let updated = try AppDelegate.services.layoutService.updateFromCurrent(layoutID: layout.id)
            layout.windows = updated.windows
        } catch {
            // Layout may not be saved yet; silently ignore
        }
    }

    // MARK: - Helpers

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .lineLimit(1)
        }
    }

    private func positionLabel(_ frame: RelativeFrame) -> String {
        let w = Int(frame.width * 100)
        let h = Int(frame.height * 100)
        return "\(w)x\(h)"
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Window Sheet

/// Sheet to add a window entry from currently running apps.
struct AddWindowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runningApps: [RunningAppInfo] = []
    @State private var selectedBundleID: String?
    @State private var selectedPreset: PositionPreset = .leftHalf

    let onAdd: (WindowSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Window to Layout")
                .font(.headline)

            // App list
            List(runningApps, id: \.bundleID, selection: $selectedBundleID) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.system(size: 12))
                        Text(app.bundleID)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tag(app.bundleID)
            }
            .frame(height: 200)

            // Position preset
            HStack {
                Text("Position:")
                    .font(.system(size: 12))
                Picker("", selection: $selectedPreset) {
                    ForEach(PositionPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            // Preview of selected preset
            presetPreview

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addWindow() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedBundleID == nil)
            }
        }
        .padding()
        .frame(width: 380, height: 400)
        .onAppear { loadRunningApps() }
    }

    private var presetPreview: some View {
        let frame = selectedPreset.relativeFrame
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 0.5)
                )
                .frame(
                    width: 120 * frame.width,
                    height: 70 * frame.height
                )
                .offset(
                    x: 2 + 120 * frame.x,
                    y: 2 + 70 * frame.y
                )
        }
        .frame(width: 124, height: 74)
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(
                    bundleID: bundleID,
                    name: name,
                    icon: app.icon
                )
            }
            .sorted { $0.name < $1.name }

        // Deduplicate by bundleID
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleID).inserted }
    }

    private func addWindow() {
        guard let bundleID = selectedBundleID,
              let app = runningApps.first(where: { $0.bundleID == bundleID }) else { return }

        let fingerprints = AppDelegate.services.screenRegistry.fingerprints()
        let display = fingerprints.first ?? DisplayFingerprint(
            displayID: 0,
            localizedName: "Display",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        let snapshot = WindowSnapshot(
            id: UUID(),
            appBundleID: app.bundleID,
            appName: app.name,
            title: nil,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            relativeFrame: selectedPreset.relativeFrame,
            display: display,
            isMinimized: false,
            wasFullscreen: false
        )

        onAdd(snapshot)
        dismiss()
    }
}

// MARK: - Supporting Types

struct RunningAppInfo {
    var bundleID: String
    var name: String
    var icon: NSImage?
}

enum PositionPreset: CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center

    var label: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .maximize: return "Maximize"
        case .center: return "Center (60%)"
        }
    }

    var relativeFrame: RelativeFrame {
        switch self {
        case .leftHalf:    return RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf:   return RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf:     return RelativeFrame(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf:  return RelativeFrame(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft:     return RelativeFrame(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight:    return RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft:  return RelativeFrame(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return RelativeFrame(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .maximize:    return RelativeFrame(x: 0, y: 0, width: 1, height: 1)
        case .center:      return RelativeFrame(x: 0.2, y: 0.15, width: 0.6, height: 0.7)
        }
    }
}

private struct DisplayGroup {
    var fingerprint: DisplayFingerprint
    var windows: [WindowSnapshot]
}

private struct ArrangedDisplay {
    var group: DisplayGroup
    var rect: CGRect
}

// MARK: - Shared Layout Helpers

private func buildDisplayGroups(from windows: [WindowSnapshot]) -> [DisplayGroup] {
    let grouped = Dictionary(grouping: windows, by: \.display)
    return grouped.map { (fingerprint, wins) in
        DisplayGroup(fingerprint: fingerprint, windows: wins)
    }
    .sorted { ($0.fingerprint.bounds.origin.x, $0.fingerprint.bounds.origin.y) < ($1.fingerprint.bounds.origin.x, $1.fingerprint.bounds.origin.y) }
}

private func arrangeDisplays(_ groups: [DisplayGroup], in size: CGSize) -> [ArrangedDisplay] {
    guard !groups.isEmpty else { return [] }

    let allBounds = groups.map(\.fingerprint.bounds)
    let minX = allBounds.map(\.minX).min() ?? 0
    let minY = allBounds.map(\.minY).min() ?? 0
    let maxX = allBounds.map(\.maxX).max() ?? 1
    let maxY = allBounds.map(\.maxY).max() ?? 1
    let totalWidth = maxX - minX
    let totalHeight = maxY - minY

    guard totalWidth > 0, totalHeight > 0 else { return [] }

    let padding: CGFloat = 8
    let available = CGSize(
        width: size.width - padding * 2,
        height: size.height - padding * 2
    )

    let scale = min(available.width / totalWidth, available.height / totalHeight)
    let scaledWidth = totalWidth * scale
    let scaledHeight = totalHeight * scale
    let offsetX = padding + (available.width - scaledWidth) / 2
    let offsetY = padding + (available.height - scaledHeight) / 2

    return groups.map { group in
        let b = group.fingerprint.bounds
        let rect = CGRect(
            x: offsetX + (b.origin.x - minX) * scale,
            y: offsetY + (b.origin.y - minY) * scale,
            width: b.width * scale,
            height: b.height * scale
        )
        return ArrangedDisplay(group: group, rect: rect)
    }
}

private func tileFrame(for relativeFrame: RelativeFrame, in displayRect: CGRect) -> CGRect {
    let inset: CGFloat = 2
    let usableWidth = displayRect.width - inset * 2
    let usableHeight = displayRect.height - 14 - inset
    return CGRect(
        x: inset + relativeFrame.x * usableWidth,
        y: 14 + relativeFrame.y * usableHeight,
        width: max(relativeFrame.width * usableWidth, 8),
        height: max(relativeFrame.height * usableHeight, 8)
    )
}

func windowColor(for window: WindowSnapshot) -> Color {
    let hash = window.appBundleID.hashValue
    let hue = Double(abs(hash) % 360) / 360.0
    return Color(hue: hue, saturation: 0.5, brightness: 0.8)
}
