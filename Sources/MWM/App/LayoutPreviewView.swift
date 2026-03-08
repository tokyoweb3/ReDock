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
            Text(L10n.string("editor.noWindows"))
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
                Text(item.group.fingerprint.localizedName ?? L10n.string("editor.display"))
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
    var allDisplayFingerprints: [DisplayFingerprint] = []
    var onDoubleClick: ((UUID) -> Void)?

    @State private var dragStartFrame: RelativeFrame?
    @State private var dragStartDisplayRect: CGRect?
    @State private var dragStartArranged: [ArrangedDisplay]?

    private var displayGroups: [DisplayGroup] {
        buildDisplayGroups(from: windows, allFingerprints: allDisplayFingerprints)
    }

    var body: some View {
        if windows.isEmpty && allDisplayFingerprints.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text(L10n.string("editor.addWindowsHint"))
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
                Text(item.group.fingerprint.localizedName ?? L10n.string("editor.display"))
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
        .onTapGesture(count: 2) {
            selectedWindowID = window.id
            onDoubleClick?(window.id)
        }
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
/// Edits are local until explicitly saved; Reset reverts to the last-saved state.
struct LayoutEditorView: View {
    @Binding var layout: WindowLayout
    @State private var draft: WindowLayout
    @State private var selectedWindowID: UUID?
    @State private var activeVariantIndex: Int = 0
    @State private var profiles: [DisplayProfile] = []
    @State private var selectedProfileID: UUID?
    @State private var showingAddWindow = false
    @State private var showingRecapture = false
    @State private var showingAppPicker = false
    let onSave: () -> Void
    var onReset: (() -> Void)?
    @Binding var hasUnsavedChanges: Bool

    init(
        layout: Binding<WindowLayout>,
        onSave: @escaping () -> Void,
        onReset: (() -> Void)? = nil,
        hasUnsavedChanges: Binding<Bool> = .constant(false)
    ) {
        self._layout = layout
        self._draft = State(initialValue: layout.wrappedValue)
        self.onSave = onSave
        self.onReset = onReset
        self._hasUnsavedChanges = hasUnsavedChanges
    }

    private var hasChanges: Bool {
        draft.name != layout.name
            || draft.mode != layout.mode
            || draft.variants != layout.variants
    }

    /// Safe index clamped to valid range.
    private var safeIndex: Int {
        min(activeVariantIndex, max(0, draft.variants.count - 1))
    }

    /// Active variant's windows (read-only access).
    private var activeWindows: [WindowSnapshot] {
        guard !draft.variants.isEmpty else { return [] }
        return draft.variants[safeIndex].windows
    }

    /// Binding to the active variant's windows for the minimap editor.
    private var activeWindowsBinding: Binding<[WindowSnapshot]> {
        Binding(
            get: {
                guard !draft.variants.isEmpty else { return [] }
                return draft.variants[safeIndex].windows
            },
            set: { newValue in
                guard !draft.variants.isEmpty else { return }
                draft.variants[safeIndex].windows = newValue
            }
        )
    }

    // MARK: - Variant Selector (Profile-linked Picker)

    @ViewBuilder
    private var variantSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L10n.string("variant.profile"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedProfileID) {
                    ForEach(profiles) { profile in
                        HStack(spacing: 4) {
                            let isConfigured = draft.variants.contains {
                                $0.displayProfileID == profile.id && !$0.windows.isEmpty
                            }
                            let hasAutoRestore = draft.variants.contains {
                                $0.displayProfileID == profile.id && $0.autoRestore
                            }
                            if hasAutoRestore {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("\(profile.name) (\(profile.fingerprints.count))")
                            Text(isConfigured
                                ? L10n.string("variant.configured")
                                : L10n.string("variant.notConfigured"))
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(profile.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)

                Spacer()
            }

            // Per-variant auto-restore and launch apps
            HStack(spacing: 12) {
                Toggle(L10n.string("layouts.autoRestore"), isOn: variantAutoRestoreBinding)
                    .help(L10n.string("tooltip.autoRestore"))
                Toggle(L10n.string("layouts.launchApps"), isOn: variantLaunchAppsBinding)
                    .help(L10n.string("layouts.launchAppsHelp"))
                Spacer()
            }
            .font(.system(size: 11))

        }
        .onChange(of: selectedProfileID) { _, newID in
            guard let profileID = newID else { return }
            if let idx = draft.variants.firstIndex(where: { $0.displayProfileID == profileID }) {
                activeVariantIndex = idx
            } else if let profile = profiles.first(where: { $0.id == profileID }) {
                draft.variants.append(DisplayVariant(
                    displayProfileID: profileID,
                    displayFingerprints: profile.fingerprints,
                    windows: []
                ))
                activeVariantIndex = draft.variants.count - 1
                // Persist auto-created variant to prevent false change detection
                layout = draft
            }
            selectedWindowID = nil
        }
    }

    private var variantAutoRestoreBinding: Binding<Bool> {
        Binding(
            get: {
                guard !draft.variants.isEmpty else { return false }
                return draft.variants[safeIndex].autoRestore
            },
            set: { newValue in
                guard !draft.variants.isEmpty else { return }
                draft.variants[safeIndex].autoRestore = newValue

                if newValue, let profileID = draft.variants[safeIndex].displayProfileID {
                    // Exclusive control: disable auto-restore on same-profile variants in other layouts
                    AppDelegate.services.layoutService.disableConflictingAutoRestore(
                        keepVariantID: draft.variants[safeIndex].id,
                        displayProfileID: profileID
                    )
                    // Also disable within the same draft (other variants with same profile)
                    for i in draft.variants.indices where i != safeIndex {
                        if draft.variants[i].displayProfileID == profileID {
                            draft.variants[i].autoRestore = false
                        }
                    }
                }
            }
        )
    }

    private var variantLaunchAppsBinding: Binding<Bool> {
        Binding(
            get: {
                guard !draft.variants.isEmpty else { return false }
                return draft.variants[safeIndex].launchMissingApps
            },
            set: { newValue in
                guard !draft.variants.isEmpty else { return }
                draft.variants[safeIndex].launchMissingApps = newValue
            }
        )
    }

    private func clearCurrentVariantWindows() {
        guard !draft.variants.isEmpty else { return }
        draft.variants[safeIndex].windows = []
        selectedWindowID = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Variant selector (shown when multiple variants exist)
            variantSelector

            // Interactive minimap
            LayoutEditorPreview(
                windows: activeWindowsBinding,
                selectedWindowID: $selectedWindowID,
                allDisplayFingerprints: allDisplayFingerprints,
                onDoubleClick: { windowID in
                    selectedWindowID = windowID
                    showingAppPicker = true
                }
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

            // Save / Reset buttons
            HStack(spacing: 8) {
                Button(action: { save() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text(L10n.string("editor.save"))
                            .font(.system(size: 11))
                    }
                }
                .controlSize(.small)
                .disabled(!hasChanges)
                .help(L10n.string("editor.saveHelp"))

                Button(action: { reset() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text(L10n.string("editor.reset"))
                            .font(.system(size: 11))
                    }
                }
                .controlSize(.small)
                .disabled(!hasChanges)
                .help(L10n.string("editor.resetHelp"))

                if hasChanges {
                    Text(L10n.string("editor.unsavedChanges"))
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                Spacer()
            }

            // Layout name
            HStack {
                Text(L10n.string("editor.name"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField(L10n.string("editor.layoutName"), text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                metaRow(L10n.string("editor.windowsLabel"), value: "\(activeWindows.count)")
                metaRow(L10n.string("editor.created"), value: formatted(draft.createdAt))

                HStack {
                    Text(L10n.string("editor.modeLabel"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                        .help(L10n.string("tooltip.mode"))
                    Picker("", selection: $draft.mode) {
                        Text(L10n.string("editor.appSpecific")).tag(LayoutMode.appSpecific)
                        Text(L10n.string("editor.templateLabel")).tag(LayoutMode.template)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .help(draft.mode == .appSpecific
                        ? L10n.string("tooltip.appSpecific")
                        : L10n.string("tooltip.template"))
                }

                if draft.mode == .template {
                    Text(L10n.string("tooltip.template"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 60)
                }

                if let trigger = draft.trigger {
                    metaRow(L10n.string("editor.trigger"), value: trigger.displayDescription)
                }
            }

            // Re-capture from current windows
            Button(action: { showingRecapture = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                    Text(L10n.string("editor.recapture"))
                        .font(.system(size: 11))
                }
            }
            .controlSize(.small)
            .help(L10n.string("editor.recaptureHelp"))

            // Window list header
            HStack {
                Text(L10n.string("editor.windowsLabel"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()

                Button(role: .destructive, action: { clearCurrentVariantWindows() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .controlSize(.small)
                .disabled(activeWindows.isEmpty)
                .help(L10n.string("variant.clearWindows"))

                Button(action: {
                    if selectedWindowID != nil {
                        showingAppPicker = true
                    }
                }) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 10))
                }
                .controlSize(.small)
                .disabled(selectedWindowID == nil)
                .help(L10n.string("editor.changeApp"))

                Button(action: { showingAddWindow = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .controlSize(.small)
                .help(L10n.string("editor.addWindowHelp"))
            }

            // Editable window list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(activeWindows) { window in
                        editableWindowRow(window)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .onAppear {
            loadProfilesAndMigrate()
            selectInitialProfile()
            // Persist migration to prevent false change detection
            if hasChanges { layout = draft }
            hasUnsavedChanges = false
        }
        .onChange(of: layout) { _, newValue in
            draft = newValue
            selectedWindowID = nil
            if activeVariantIndex >= newValue.variants.count {
                activeVariantIndex = 0
            }
            loadProfilesAndMigrate()
            // Keep selectedProfileID in sync with the current activeVariantIndex
            if !draft.variants.isEmpty {
                selectedProfileID = draft.variants[safeIndex].displayProfileID
            }
            // Persist migration to prevent false change detection
            if hasChanges { layout = draft }
            hasUnsavedChanges = false
        }
        .onChange(of: draft) { _, _ in
            hasUnsavedChanges = hasChanges
        }
        .sheet(isPresented: $showingAddWindow) {
            AddWindowSheet(
                existingWindows: draft.variants.isEmpty ? [] : draft.variants[safeIndex].windows,
                onAdd: { snapshots in
                    guard !draft.variants.isEmpty else { return }
                    draft.variants[safeIndex].windows.append(contentsOf: snapshots)
                }
            )
        }
        .sheet(isPresented: $showingRecapture) {
            RecaptureSheet(
                onRecapture: { snapshots in
                    guard !draft.variants.isEmpty else { return }
                    // Only update windows; keep the selected display profile unchanged
                    draft.variants[safeIndex].windows = snapshots
                }
            )
        }
        .sheet(isPresented: $showingAppPicker) {
            if !draft.variants.isEmpty,
               let windowID = selectedWindowID,
               let index = draft.variants[safeIndex].windows.firstIndex(where: { $0.id == windowID }) {
                ChangeAppSheet(currentApp: draft.variants[safeIndex].windows[index].appName) { bundleID, appName in
                    draft.variants[safeIndex].windows[index].appBundleID = bundleID
                    draft.variants[safeIndex].windows[index].appName = appName
                }
            }
        }
    }

    /// All unique display fingerprints for the preview.
    /// Uses the selected display profile's fingerprints as the authoritative source,
    /// falling back to the variant's stored fingerprints.
    private var allDisplayFingerprints: [DisplayFingerprint] {
        var seen = Set<DisplayFingerprint>()
        var result: [DisplayFingerprint] = []
        // Windows' displays first
        for window in activeWindows {
            if seen.insert(window.display).inserted {
                result.append(window.display)
            }
        }
        // Use selected profile's fingerprints (authoritative, has all displays)
        if let profileID = selectedProfileID,
           let profile = profiles.first(where: { $0.id == profileID }) {
            for fp in profile.fingerprints {
                if seen.insert(fp).inserted {
                    result.append(fp)
                }
            }
        } else if !draft.variants.isEmpty {
            for fp in draft.variants[safeIndex].displayFingerprints {
                if seen.insert(fp).inserted {
                    result.append(fp)
                }
            }
        }
        return result.sorted {
            ($0.bounds.origin.x, $0.bounds.origin.y) < ($1.bounds.origin.x, $1.bounds.origin.y)
        }
    }

    // MARK: - Profile Loading & Migration

    private func loadProfilesAndMigrate() {
        let store = AppDelegate.services.displayProfileStore
        // Ensure current displays have a profile
        let currentFPs = AppDelegate.services.screenRegistry.fingerprints()
        if !currentFPs.isEmpty {
            _ = store.findOrCreate(fingerprints: currentFPs)
        }
        profiles = store.loadAll()

        // Migrate existing variants without displayProfileID
        for i in draft.variants.indices {
            if draft.variants[i].displayProfileID == nil {
                let fps = draft.variants[i].displayFingerprints
                if let match = profiles.first(where: { $0.matches(fps) }) {
                    draft.variants[i].displayProfileID = match.id
                }
            }
        }
    }

    /// Select initial profile on first appearance only.
    private func selectInitialProfile() {
        if let firstVariant = draft.variants.first, let pid = firstVariant.displayProfileID {
            selectedProfileID = pid
        } else if !draft.variants.isEmpty, let firstProfile = profiles.first {
            // Existing variant without matching profile — link it to current profile
            // so we don't create an empty variant and lose the actual windows
            draft.variants[0].displayProfileID = firstProfile.id
            selectedProfileID = firstProfile.id
        } else if let firstProfile = profiles.first {
            selectedProfileID = firstProfile.id
        }
    }

    // MARK: - Actions

    private func save() {
        layout = draft
        onSave()
        hasUnsavedChanges = false
    }

    private func reset() {
        draft = layout
        selectedWindowID = nil
        hasUnsavedChanges = false
        onReset?()
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        HStack(spacing: 4) {
            Text(L10n.string("editor.snap"))
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
            guard let id = selectedWindowID, !draft.variants.isEmpty,
                  let index = draft.variants[safeIndex].windows.firstIndex(where: { $0.id == id }) else { return }
            var updated = draft.variants[safeIndex].windows[index]
            updated.relativeFrame = RelativeFrame(x: x, y: y, width: w, height: h)
            draft.variants[safeIndex].windows[index] = updated
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
            .help(L10n.string("editor.removeFromLayout"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected
            ? Color.accentColor.opacity(0.1)
            : Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            selectedWindowID = window.id
            showingAppPicker = true
        }
        .onTapGesture {
            selectedWindowID = window.id
        }
    }

    private func removeWindow(id: UUID) {
        guard !draft.variants.isEmpty else { return }
        draft.variants[safeIndex].windows.removeAll { $0.id == id }
        if selectedWindowID == id {
            selectedWindowID = nil
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

// MARK: - Add Window Sheet (multi-select)

/// Sheet to add window entries from currently running apps (supports multi-selection).
struct AddWindowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var windowItems: [AddWindowItem] = []
    @State private var useCurrentPosition = true
    @State private var selectedPreset: PositionPreset = .leftHalf

    /// Windows already in the layout, used to show "already added" indicator.
    let existingWindows: [WindowSnapshot]
    let onAdd: ([WindowSnapshot]) -> Void

    private var selectedCount: Int {
        windowItems.filter(\.isSelected).count
    }

    /// Check if a window is already in the layout by matching bundleID + title.
    private func isAlreadyInLayout(_ snapshot: WindowSnapshot) -> Bool {
        existingWindows.contains { existing in
            existing.appBundleID == snapshot.appBundleID
                && existing.title == snapshot.title
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("addWindow.title"))
                .font(.headline)

            // Position mode
            HStack {
                Text(L10n.string("addWindow.position"))
                    .font(.system(size: 12))
                Picker("", selection: $useCurrentPosition) {
                    Text(L10n.string("addWindow.currentPosition")).tag(true)
                    ForEach(PositionPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(false)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: useCurrentPosition) { _, newValue in
                    if !newValue && selectedPreset == .leftHalf {
                        // Keep default preset
                    }
                }

                if !useCurrentPosition {
                    Picker("", selection: $selectedPreset) {
                        ForEach(PositionPreset.allCases, id: \.self) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            }

            // Select all / deselect all
            HStack {
                Text(L10n.string("addWindow.windowCount", selectedCount, windowItems.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.string("saveLayout.selectAll")) {
                    for i in windowItems.indices { windowItems[i].isSelected = true }
                }
                .controlSize(.mini)
                Button(L10n.string("saveLayout.deselectAll")) {
                    for i in windowItems.indices { windowItems[i].isSelected = false }
                }
                .controlSize(.mini)
            }

            // Window list with checkboxes
            List {
                ForEach($windowItems) { $item in
                    let alreadyAdded = isAlreadyInLayout(item.snapshot)
                    HStack(spacing: 8) {
                        Toggle("", isOn: $item.isSelected)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(alreadyAdded)

                        if let icon = item.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.appName)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            if let title = item.windowTitle, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if alreadyAdded {
                            Text(L10n.string("addWindow.alreadyAdded"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.5))
                                .clipShape(Capsule())
                        }

                        if let displayName = item.displayName {
                            Text(displayName)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .opacity(alreadyAdded ? 0.5 : 1.0)
                }
            }
            .frame(height: 240)

            HStack {
                Spacer()
                Button(L10n.string("addWindow.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("addWindow.addCount", selectedCount)) { addWindows() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
        }
        .padding()
        .frame(width: 440, height: 420)
        .onAppear { loadWindowItems() }
    }

    private func loadWindowItems() {
        let services = AppDelegate.services
        let snapshots = services.layoutService.captureCurrentWindows()
        windowItems = snapshots.map { snapshot in
            let icon = NSRunningApplication.runningApplications(
                withBundleIdentifier: snapshot.appBundleID
            ).first?.icon
            return AddWindowItem(
                snapshot: snapshot,
                appName: snapshot.appName,
                windowTitle: snapshot.title,
                displayName: snapshot.display.localizedName,
                icon: icon,
                isSelected: false
            )
        }
    }

    private func addWindows() {
        let selected = windowItems.filter(\.isSelected)
        let snapshots: [WindowSnapshot] = selected.map { item in
            if useCurrentPosition {
                return WindowSnapshot(
                    id: UUID(),
                    appBundleID: item.snapshot.appBundleID,
                    appName: item.snapshot.appName,
                    title: item.snapshot.title,
                    role: item.snapshot.role,
                    subrole: item.snapshot.subrole,
                    relativeFrame: item.snapshot.relativeFrame,
                    display: item.snapshot.display,
                    isMinimized: item.snapshot.isMinimized,
                    wasFullscreen: item.snapshot.wasFullscreen
                )
            } else {
                let display = item.snapshot.display
                return WindowSnapshot(
                    id: UUID(),
                    appBundleID: item.snapshot.appBundleID,
                    appName: item.snapshot.appName,
                    title: item.snapshot.title,
                    role: "AXWindow",
                    subrole: "AXStandardWindow",
                    relativeFrame: selectedPreset.relativeFrame,
                    display: display,
                    isMinimized: false,
                    wasFullscreen: false
                )
            }
        }
        onAdd(snapshots)
        dismiss()
    }
}

// MARK: - Re-capture Sheet

/// Sheet to replace all windows in the layout with a fresh capture.
struct RecaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var windowSelections: [WindowSelection] = []
    @State private var obstructedIDs: Set<UUID> = []
    @State private var ignoreObstructed = false

    let onRecapture: ([WindowSnapshot]) -> Void

    private var selectedCount: Int {
        windowSelections.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("editor.recaptureTitle"))
                .font(.headline)

            Text(L10n.string("editor.recaptureDescription"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if !obstructedIDs.isEmpty {
                Toggle(L10n.string("saveLayout.ignoreObstructed"), isOn: $ignoreObstructed)
                    .font(.system(size: 12))
                    .onChange(of: ignoreObstructed) { _, newValue in
                        for i in windowSelections.indices {
                            if windowSelections[i].isObstructed {
                                windowSelections[i].isSelected = !newValue
                            }
                        }
                    }
            }

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
                    .opacity(item.isObstructed && !item.isSelected ? 0.4 : 1.0)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Spacer()
                Button(L10n.string("alert.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("editor.recaptureConfirm", selectedCount)) { recapture() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
        }
        .padding()
        .frame(width: 480, height: 440)
        .onAppear { captureWindows() }
    }

    private func captureWindows() {
        let capture = AppDelegate.services.layoutService.captureWithObstructionInfo()
        obstructedIDs = capture.obstructedIDs
        windowSelections = capture.snapshots.map {
            WindowSelection(
                snapshot: $0,
                isSelected: true,
                isObstructed: capture.obstructedIDs.contains($0.id)
            )
        }
    }

    private func recapture() {
        let selected = windowSelections
            .filter(\.isSelected)
            .map(\.snapshot)
        onRecapture(selected)
        dismiss()
    }

    private func sizeLabel(_ frame: RelativeFrame) -> String {
        "\(Int(frame.width * 100))%x\(Int(frame.height * 100))%"
    }
}

// MARK: - Change App Sheet

/// Sheet to reassign a window slot to a different app.
struct ChangeAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runningApps: [RunningAppInfo] = []
    @State private var selectedBundleID: String?
    let currentApp: String
    let onChange: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("changeApp.title"))
                .font(.headline)

            Text(L10n.string("changeApp.current", currentApp))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

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

            HStack {
                Spacer()
                Button(L10n.string("alert.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("changeApp.change")) { changeApp() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedBundleID == nil)
            }
        }
        .padding()
        .frame(width: 360, height: 340)
        .onAppear { loadRunningApps() }
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(bundleID: bundleID, name: name, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleID).inserted }
    }

    private func changeApp() {
        guard let bundleID = selectedBundleID,
              let app = runningApps.first(where: { $0.bundleID == bundleID }) else { return }
        onChange(bundleID, app.name)
        dismiss()
    }
}

// MARK: - Supporting Types

struct RunningAppInfo {
    var bundleID: String
    var name: String
    var icon: NSImage?
}

struct AddWindowItem: Identifiable {
    let id = UUID()
    var snapshot: WindowSnapshot
    var appName: String
    var windowTitle: String?
    var displayName: String?
    var icon: NSImage?
    var isSelected: Bool
}

enum PositionPreset: CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center

    var label: String {
        switch self {
        case .leftHalf: return L10n.string("preset.leftHalf")
        case .rightHalf: return L10n.string("preset.rightHalf")
        case .topHalf: return L10n.string("preset.topHalf")
        case .bottomHalf: return L10n.string("preset.bottomHalf")
        case .topLeft: return L10n.string("preset.topLeft")
        case .topRight: return L10n.string("preset.topRight")
        case .bottomLeft: return L10n.string("preset.bottomLeft")
        case .bottomRight: return L10n.string("preset.bottomRight")
        case .maximize: return L10n.string("preset.maximize")
        case .center: return L10n.string("preset.center")
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

private func buildDisplayGroups(from windows: [WindowSnapshot], allFingerprints: [DisplayFingerprint] = []) -> [DisplayGroup] {
    let grouped = Dictionary(grouping: windows, by: \.display)
    var groups = grouped.map { (fingerprint, wins) in
        DisplayGroup(fingerprint: fingerprint, windows: wins)
    }
    // Include displays that have no windows (so they remain visible in the editor)
    let existing = Set(groups.map(\.fingerprint))
    for fp in allFingerprints where !existing.contains(fp) {
        groups.append(DisplayGroup(fingerprint: fp, windows: []))
    }
    return groups.sorted {
        ($0.fingerprint.bounds.origin.x, $0.fingerprint.bounds.origin.y) < ($1.fingerprint.bounds.origin.x, $1.fingerprint.bounds.origin.y)
    }
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
