import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        TabView {
            ShortcutsSettingsView()
                .tabItem {
                    Label(L10n.string("settings.shortcuts"), systemImage: "command")
                }

            LayoutsSettingsView()
                .tabItem {
                    Label(L10n.string("settings.layouts"), systemImage: "rectangle.3.group")
                }

            GeneralSettingsView()
                .tabItem {
                    Label(L10n.string("settings.general"), systemImage: "gear")
                }
        }
        .frame(width: 720, height: 540)
        .id(localization.currentLanguage)
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsView: View {
    @State private var layouts: [WindowLayout] = []
    @State private var slotAssignments: [Int: UUID?] = [:]
    @State private var shortcutConflict: String?

    /// Workspace slots with generic number icons.
    private static let workspaceSlots: [(name: KeyboardShortcuts.Name, index: Int)] = [
        (.workspaceSlot5, 5),
        (.workspaceSlot6, 6),
        (.workspaceSlot7, 7),
        (.workspaceSlot8, 8),
        (.workspaceSlot9, 9),
    ]

    private static let numberIcons = ["5.circle", "6.circle", "7.circle", "8.circle", "9.circle"]
    private static let slotIndices = [5, 6, 7, 8, 9]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 24) {
                    // Left column
                    VStack(spacing: 0) {
                        shortcutSection(L10n.string("shortcuts.halves")) {
                            shortcutRow(L10n.string("menu.leftHalf"), icon: "rectangle.lefthalf.filled", name: .leftHalf)
                            shortcutRow(L10n.string("menu.rightHalf"), icon: "rectangle.righthalf.filled", name: .rightHalf)
                            shortcutRow(L10n.string("menu.topHalf"), icon: "rectangle.tophalf.filled", name: .topHalf)
                            shortcutRow(L10n.string("menu.bottomHalf"), icon: "rectangle.bottomhalf.filled", name: .bottomHalf)
                        }

                        shortcutSection(L10n.string("shortcuts.quarters")) {
                            shortcutRow(L10n.string("menu.topLeft"), icon: "rectangle.inset.topleft.filled", name: .topLeft)
                            shortcutRow(L10n.string("menu.topRight"), icon: "rectangle.inset.topright.filled", name: .topRight)
                            shortcutRow(L10n.string("menu.bottomLeft"), icon: "rectangle.inset.bottomleft.filled", name: .bottomLeft)
                            shortcutRow(L10n.string("menu.bottomRight"), icon: "rectangle.inset.bottomright.filled", name: .bottomRight)
                        }

                        shortcutSection(L10n.string("shortcuts.sizing")) {
                            shortcutRow(L10n.string("menu.maximize"), icon: "rectangle.fill", name: .maximize)
                            shortcutRow(L10n.string("menu.fullScreen"), icon: "arrow.up.left.and.arrow.down.right", name: .toggleFullScreen)
                            shortcutRow(L10n.string("menu.center"), icon: "rectangle.center.inset.filled", name: .center)
                            shortcutRow(L10n.string("menu.makeLarger"), icon: "plus.square", name: .increase)
                            shortcutRow(L10n.string("menu.makeSmaller"), icon: "minus.square", name: .decrease)
                        }
                    }

                    // Right column
                    VStack(spacing: 0) {
                        shortcutSection(L10n.string("shortcuts.display")) {
                            shortcutRow(L10n.string("menu.nextDisplay"), icon: "display.2", name: .nextScreen)
                            shortcutRow(L10n.string("menu.previousDisplay"), icon: "display", name: .previousScreen)
                        }

                        shortcutSection(L10n.string("shortcuts.focus")) {
                            shortcutRow(L10n.string("menu.focusMode"), icon: "eye", name: .toggleFocusMode)
                        }

                        shortcutSection(L10n.string("shortcuts.workspaces")) {
                            ForEach(Array(Self.workspaceSlots.enumerated()), id: \.element.index) { i, slot in
                                workspaceSlotRow(slot: slot, iconIndex: i)
                            }
                        }

                        // Layout-specific shortcuts (non-workspace-slot)
                        if !layoutsWithCustomShortcuts.isEmpty {
                            shortcutSection(L10n.string("shortcuts.layoutShortcuts")) {
                                ForEach(layoutsWithCustomShortcuts) { layout in
                                    layoutShortcutRow(layout)
                                }
                            }
                        }
                    }
                }
                .padding(16)

                // Bottom bar: conflict message + reset button
                HStack(spacing: 8) {
                    if let conflict = shortcutConflict {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 10))
                            Text(conflict)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.orange)
                    }

                    Spacer()

                    Button {
                        resetAllShortcuts()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text(L10n.string("shortcuts.resetAll"))
                                .font(.system(size: 11))
                        }
                    }
                    .controlSize(.small)
                    .help(L10n.string("shortcuts.resetAllHelp"))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear { loadState() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"))) { notification in
            guard let changedName = notification.userInfo?["name"] as? KeyboardShortcuts.Name else { return }
            // Small delay to let LayoutsSettingsView's onChange handle its own conflicts first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                handleShortcutConflict(changedName: changedName)
            }
        }
    }

    private func loadState() {
        layouts = AppDelegate.services.layoutService.loadAll()
        for idx in Self.slotIndices {
            slotAssignments[idx] = WorkspaceSlotManager.layoutID(for: idx)
        }
    }

    /// Reset all built-in shortcuts to their default values and clear layout shortcuts.
    private func resetAllShortcuts() {
        // Reset built-in shortcuts to defaults
        for name in LayoutShortcutManager.builtInNames {
            KeyboardShortcuts.reset(name)
        }

        // Clear layout-specific shortcuts
        for layout in layouts {
            let name = LayoutShortcutManager.shortcutName(for: layout.id)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }

        shortcutConflict = nil
        loadState()
    }

    /// Detect and auto-resolve conflicts when any shortcut changes.
    private func handleShortcutConflict(changedName: KeyboardShortcuts.Name) {
        guard let newShortcut = KeyboardShortcuts.getShortcut(for: changedName) else {
            return
        }

        // Gather all shortcut names (built-in + layout-specific)
        let allNames = ShortcutNameResolver.allShortcutNames(layouts: layouts)

        for (otherName, _) in allNames {
            if otherName == changedName { continue }
            if let existing = KeyboardShortcuts.getShortcut(for: otherName),
               existing == newShortcut {
                let displayName = ShortcutNameResolver.displayName(for: otherName, layouts: layouts)
                KeyboardShortcuts.setShortcut(nil, for: otherName)
                shortcutConflict = L10n.string("layouts.shortcutReplaced", displayName)
                return
            }
        }
    }

    /// Layouts that have a custom shortcut (not assigned via workspace slot).
    private var layoutsWithCustomShortcuts: [WindowLayout] {
        let slotLayoutIDs = Set(Self.slotIndices.compactMap { WorkspaceSlotManager.layoutID(for: $0) })
        return layouts.filter { layout in
            let name = LayoutShortcutManager.shortcutName(for: layout.id)
            let hasShortcut = KeyboardShortcuts.getShortcut(for: name) != nil
            return hasShortcut && !slotLayoutIDs.contains(layout.id)
        }
    }

    private func layoutShortcutRow(_ layout: WindowLayout) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(layout.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            KeyboardShortcuts.Recorder(for: LayoutShortcutManager.shortcutName(for: layout.id))
                .frame(width: 120)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    /// Workspace slot row: number icon + layout picker + shortcut recorder.
    private func workspaceSlotRow(slot: (name: KeyboardShortcuts.Name, index: Int), iconIndex: Int) -> some View {
        let icon = Self.numberIcons[iconIndex]
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            // Layout picker dropdown
            Picker("", selection: slotBinding(for: slot.index)) {
                Text(L10n.string("shortcuts.slotEmpty", slot.index))
                    .tag(Optional<UUID>.none)
                ForEach(layouts) { layout in
                    Text(layout.name).tag(Optional(layout.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 130)

            Spacer()

            KeyboardShortcuts.Recorder(for: slot.name)
                .frame(width: 120)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func slotBinding(for slotIndex: Int) -> Binding<UUID?> {
        Binding(
            get: { slotAssignments[slotIndex] ?? nil },
            set: { newValue in
                slotAssignments[slotIndex] = newValue
                WorkspaceSlotManager.setLayoutID(newValue, for: slotIndex)
                AppDelegate.statusBar.rebuildMenu()
            }
        )
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

// MARK: - Layouts Tab (with Display Profiles segment)

struct LayoutsSettingsView: View {
    @State private var layouts: [WindowLayout] = []
    @State private var selectedLayoutID: UUID?
    @State private var showingAddLayout = false
    @State private var shortcutConflict: String?
    @State private var saveLayoutController: SaveLayoutWindowController?
    @State private var activeSegment: LayoutSegment = .layouts
    @State private var draftHasChanges = false
    @State private var pendingSelectionID: UUID?
    @State private var showUnsavedAlert = false

    private var services: AppServices { AppDelegate.services }

    enum LayoutSegment: String, CaseIterable {
        case layouts
        case profiles
    }

    private var selectedLayout: WindowLayout? {
        guard let id = selectedLayoutID else { return nil }
        return layouts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top segment picker
            Picker("", selection: $activeSegment) {
                Text(L10n.string("settings.layouts")).tag(LayoutSegment.layouts)
                Text(L10n.string("displayProfile.title")).tag(LayoutSegment.profiles)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if activeSegment == .layouts {
                layoutsContent
            } else {
                DisplayProfilesView(layouts: $layouts)
            }
        }
        .onAppear { refresh() }
        .onChange(of: selectedLayoutID) { _, _ in
            shortcutConflict = nil
        }
        .sheet(isPresented: $showingAddLayout) {
            AddLayoutSheet(
                onSave: { layout in saveNewLayout(layout) },
                onCapture: { captureCurrentAsLayout() }
            )
        }
        .alert(L10n.string("editor.unsavedChanges"), isPresented: $showUnsavedAlert) {
            Button(L10n.string("editor.save")) {
                saveSelectedLayout()
                draftHasChanges = false
                selectedLayoutID = pendingSelectionID
                pendingSelectionID = nil
            }
            Button(L10n.string("editor.discard"), role: .destructive) {
                draftHasChanges = false
                selectedLayoutID = pendingSelectionID
                pendingSelectionID = nil
            }
            Button(L10n.string("alert.cancel"), role: .cancel) {
                pendingSelectionID = nil
            }
        } message: {
            Text(L10n.string("editor.unsavedAlertMessage"))
        }
    }

    // MARK: - Layouts Content

    private var safeSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedLayoutID },
            set: { newValue in
                if draftHasChanges {
                    pendingSelectionID = newValue
                    showUnsavedAlert = true
                } else {
                    selectedLayoutID = newValue
                }
            }
        )
    }

    private var layoutsContent: some View {
        HSplitView {
            // Left: layout list
            VStack(spacing: 0) {
                List(selection: safeSelectionBinding) {
                    ForEach(layouts) { layout in
                        layoutRow(layout).tag(layout.id)
                    }
                }

                HStack(spacing: 4) {
                    Button(action: { deleteSelected() }) {
                        Image(systemName: "minus")
                            .frame(height: 12)
                    }
                    .disabled(selectedLayoutID == nil || (selectedLayout?.isFavorite ?? false))
                    .help(selectedLayout?.isFavorite == true
                        ? L10n.string("layouts.cannotDeleteFavorite")
                        : L10n.string("layouts.deleteSelected"))

                    Button(action: { showingAddLayout = true }) {
                        Image(systemName: "plus")
                    }
                    .help(L10n.string("layouts.addLayout"))

                    Spacer()

                    Button(action: { exportLayouts() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help(L10n.string("layouts.export"))

                    Button(action: { importLayouts() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help(L10n.string("layouts.import"))
                }
                .padding(6)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Right: editor
            VStack {
                if let binding = selectedLayoutBinding {
                    ScrollView {
                        LayoutEditorView(
                            layout: binding,
                            onSave: {
                                saveSelectedLayout()
                            },
                            hasUnsavedChanges: $draftHasChanges
                        )
                        .padding(12)
                    }

                    // Bottom controls
                    VStack(spacing: 4) {
                        HStack {
                            Text(L10n.string("layouts.shortcut"))
                                .font(.system(size: 11))
                            ShortcutRecorderView(
                                name: effectiveShortcutName(for: binding.wrappedValue.id),
                                onChange: { _ in
                                    guard let id = selectedLayoutID else { return }
                                    handleShortcutChange(layoutID: id)
                                }
                            )
                            .id(binding.wrappedValue.id)
                            .frame(width: 120, height: 22)
                            Spacer()
                            Button(L10n.string("layouts.restoreNow")) {
                                Task {
                                    let result = await services.layoutService.restoreLayoutAsync(binding.wrappedValue)
                                    services.diagnosticsService.record(result: result, triggerSource: "settings")
                                }
                            }
                            .controlSize(.small)
                            .help(L10n.string("layouts.restoreNow"))
                        }

                        // Show replacement message when shortcut was auto-overridden
                        if let conflict = shortcutConflict {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 9))
                                Text(conflict)
                                    .font(.system(size: 10))
                                Spacer()
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 32))
                            .foregroundStyle(.quaternary)
                        Text(L10n.string("layouts.selectToEdit"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
    }

    // MARK: - Subviews

    private func layoutRow(_ layout: WindowLayout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(L10n.string("layouts.windowCount", layout.windows.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(L10n.string(layout.mode == .appSpecific ? "layouts.appSpecificBadge" : "layouts.template"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(layout.mode == .appSpecific ? Color.blue.opacity(0.7) : Color.orange.opacity(0.7))
                        .clipShape(Capsule())
                        .help(L10n.string(layout.mode == .appSpecific ? "tooltip.appSpecificBadge" : "tooltip.templateBadge"))
                }
            }
            Spacer()

            Button(action: { toggleFavorite(layout) }) {
                Image(systemName: layout.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(layout.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(layout.isFavorite
                ? L10n.string("layouts.unfavorite")
                : L10n.string("layouts.favorite"))

            if layout.autoRestore {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                    .help(L10n.string("tooltip.autoRestore"))
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
        refreshShortcuts()
    }

    private func toggleFavorite(_ layout: WindowLayout) {
        guard let index = layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        var updated = layouts[index]
        updated.isFavorite = !updated.isFavorite
        try? services.layoutService.save(updated)
        refresh()
        AppDelegate.statusBar.rebuildMenu()
    }

    private func saveNewLayout(_ layout: WindowLayout) {
        do {
            try services.layoutService.save(layout)
            refresh()
            selectedLayoutID = layout.id
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func captureCurrentAsLayout() {
        guard services.permissions.isGranted else {
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.accessibilityRequired.title")
            alert.informativeText = L10n.string("alert.accessibilityRequired.message")
            alert.addButton(withTitle: L10n.string("alert.openSystemSettings"))
            alert.addButton(withTitle: L10n.string("alert.cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                services.permissions.openSystemSettings()
            }
            return
        }

        let capture = services.layoutService.captureWithObstructionInfo()
        guard !capture.snapshots.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.noWindowsFound.title")
            alert.informativeText = L10n.string("alert.noWindowsFound.message")
            alert.addButton(withTitle: L10n.string("alert.ok"))
            alert.runModal()
            return
        }

        let controller = SaveLayoutWindowController()
        controller.show(snapshots: capture.snapshots, obstructedIDs: capture.obstructedIDs) { [self] name, selected, mode in
            do {
                let layout = try services.layoutService.saveLayout(name: name, snapshots: selected, mode: mode)
                refresh()
                selectedLayoutID = layout.id
                refreshShortcuts()
                AppDelegate.statusBar.rebuildMenu()
            } catch {
                let errorAlert = NSAlert(error: error)
                errorAlert.runModal()
            }
        }
        saveLayoutController = controller
    }

    private func handleShortcutChange(layoutID: UUID) {
        let name = effectiveShortcutName(for: layoutID)
        guard let newShortcut = KeyboardShortcuts.getShortcut(for: name) else {
            // Shortcut was cleared
            shortcutConflict = nil
            refreshShortcuts()
            return
        }

        // Check all shortcuts for conflicts using shared resolver
        let allNames = ShortcutNameResolver.allShortcutNames(layouts: layouts)
        var conflictDescription: String?

        for (otherName, _) in allNames {
            if otherName == name { continue }
            if let existing = KeyboardShortcuts.getShortcut(for: otherName),
               existing == newShortcut {
                conflictDescription = ShortcutNameResolver.displayName(for: otherName, layouts: layouts)
                KeyboardShortcuts.setShortcut(nil, for: otherName)
                break
            }
        }

        if let desc = conflictDescription {
            shortcutConflict = L10n.string("layouts.shortcutReplaced", desc)
        } else {
            shortcutConflict = nil
        }

        refreshShortcuts()
    }

    /// Returns the effective shortcut name for a layout.
    /// If the layout is assigned to a workspace slot, use the slot's shortcut name
    /// so the Recorder displays the actual registered key combo.
    /// Otherwise, use the layout-specific shortcut name.
    private func effectiveShortcutName(for layoutID: UUID) -> KeyboardShortcuts.Name {
        let slots: [(KeyboardShortcuts.Name, Int)] = [
            (.workspaceSlot5, 5), (.workspaceSlot6, 6), (.workspaceSlot7, 7),
            (.workspaceSlot8, 8), (.workspaceSlot9, 9),
        ]
        for (name, idx) in slots {
            if WorkspaceSlotManager.layoutID(for: idx) == layoutID {
                return name
            }
        }
        return LayoutShortcutManager.shortcutName(for: layoutID)
    }


    private func deleteSelected() {
        guard let id = selectedLayoutID else { return }
        if let layout = layouts.first(where: { $0.id == id }), layout.isFavorite { return }
        try? services.layoutService.delete(id: id)
        selectedLayoutID = nil
        refresh()
        refreshShortcuts()
        AppDelegate.statusBar.rebuildMenu()
    }

    private func exportLayouts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ReDock-layouts.json"
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
            refreshShortcuts()
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.importComplete.title")
            var message = L10n.string("alert.importComplete.message", validation.validLayouts.count)
            if !validation.warnings.isEmpty {
                message += L10n.string("alert.importComplete.warnings", validation.warnings.joined(separator: "\n"))
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

    private func refreshShortcuts() {
        services.layoutShortcutManager.registerAll(layouts: layouts)
    }
}

// MARK: - Display Profiles View (embedded in Layouts tab)

struct DisplayProfilesView: View {
    @Binding var layouts: [WindowLayout]
    @State private var profiles: [DisplayProfile] = []
    private var services: AppServices { AppDelegate.services }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Current display info
                currentDisplaySection

                Divider()

                // Profiles list
                if profiles.isEmpty {
                    emptyView
                } else {
                    profilesList
                }
            }
            .padding(16)
        }
        .onAppear {
            profiles = services.displayProfileStore.loadAll()
                .sorted { ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast) }
        }
    }

    private var currentDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("displayProfile.connectedDisplays"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let fingerprints = services.screenRegistry.fingerprints()
            VStack(spacing: 1) {
                ForEach(Array(fingerprints.enumerated()), id: \.offset) { _, fp in
                    HStack(spacing: 8) {
                        Image(systemName: "display")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(fp.localizedName ?? "Display")
                                .font(.system(size: 12))
                            Text("\(Int(fp.bounds.width)) x \(Int(fp.bounds.height))")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text(L10n.string("displayProfile.noProfiles"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.string("displayProfile.noProfilesHint"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var profilesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("displayProfile.title"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 1) {
                ForEach(profiles) { profile in
                    profileRow(profile)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func profileRow(_ profile: DisplayProfile) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "display")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    L10n.string("displayProfile.profileNamePlaceholder"),
                    text: profileNameBinding(for: profile.id)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))

                Text(profile.displayDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if let layoutName = autoRestoreLayoutName(for: profile.id) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text(L10n.string("displayProfile.autoRestoreLayout", layoutName))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.blue)
                }

                if let lastSeen = profile.lastSeenAt {
                    Text(L10n.string("displayProfile.lastSeen", lastSeen.formatted(date: .abbreviated, time: .shortened)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Delete profile
            Button(action: { deleteProfile(profile.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func autoRestoreLayoutName(for profileID: UUID) -> String? {
        for layout in layouts {
            for variant in layout.variants {
                if variant.displayProfileID == profileID && variant.autoRestore {
                    return layout.name
                }
            }
        }
        return nil
    }

    private func profileNameBinding(for profileID: UUID) -> Binding<String> {
        Binding(
            get: {
                profiles.first(where: { $0.id == profileID })?.name ?? ""
            },
            set: { newValue in
                guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
                profiles[index].name = newValue
                services.displayProfileStore.save(profiles[index])
            }
        )
    }

    private func deleteProfile(_ profileID: UUID) {
        // Unlink any layouts referencing this profile
        for (i, layout) in layouts.enumerated() where layout.displayProfileID == profileID {
            var updated = layouts[i]
            updated.displayProfileID = nil
            updated.trigger = nil
            try? services.layoutService.save(updated)
            layouts[i] = updated
        }
        services.displayProfileStore.delete(id: profileID)
        profiles = services.displayProfileStore.loadAll()
            .sorted { ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast) }
    }
}

// MARK: - Add Layout Sheet (unified: new empty, from preset, capture)

struct AddLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum AddMode {
        case menu
        case newEmpty
        case fromPreset(WorkspacePreset?)
        case presetConfig(WorkspacePreset)
    }

    @State private var mode: AddMode = .menu
    @State private var layoutName: String = ""
    @State private var slotAssignments: [SlotAssignment] = []
    @State private var runningApps: [RunningAppInfo] = []

    let onSave: (WindowLayout) -> Void
    let onCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch mode {
            case .menu:
                menuView
            case .newEmpty:
                newEmptyView
            case .fromPreset:
                presetListView
            case .presetConfig(let preset):
                presetConfigView(preset)
            }

            HStack {
                if !isMenu {
                    Button(L10n.string("layouts.back")) { mode = .menu }
                }
                Spacer()
                Button(L10n.string("alert.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                switch mode {
                case .newEmpty:
                    Button(L10n.string("layouts.create")) { createEmpty() }
                        .keyboardShortcut(.defaultAction)
                case .presetConfig:
                    Button(L10n.string("saveLayout.save")) { savePreset() }
                        .keyboardShortcut(.defaultAction)
                default:
                    EmptyView()
                }
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear { loadRunningApps() }
    }

    private var isMenu: Bool {
        if case .menu = mode { return true }
        return false
    }

    // MARK: - Menu

    private var menuView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("layouts.addLayout"))
                .font(.headline)

            VStack(spacing: 1) {
                menuButton(
                    icon: "rectangle.dashed",
                    title: L10n.string("layouts.newEmpty"),
                    description: L10n.string("layouts.newEmptyDescription")
                ) { mode = .newEmpty }

                menuButton(
                    icon: "rectangle.3.group",
                    title: L10n.string("layouts.addFromPreset"),
                    description: L10n.string("layouts.addFromPresetDescription")
                ) { mode = .fromPreset(nil) }

                menuButton(
                    icon: "camera",
                    title: L10n.string("layouts.captureCurrentWindows"),
                    description: L10n.string("layouts.captureDescription")
                ) {
                    dismiss()
                    // Delay to let sheet dismiss before showing capture window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onCapture()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func menuButton(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - New Empty

    private var newEmptyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("layouts.newEmpty"))
                .font(.headline)

            HStack {
                Text(L10n.string("saveLayout.name"))
                    .frame(width: 50, alignment: .leading)
                TextField(L10n.string("saveLayout.namePlaceholder"), text: $layoutName)
                    .textFieldStyle(.roundedBorder)
            }

            Text(L10n.string("layouts.newEmptyHint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func createEmpty() {
        var name = layoutName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            name = L10n.string("saveLayout.namePlaceholder")
        }
        name = deduplicateName(name)
        let layout = WindowLayout(name: name, windows: [])
        onSave(layout)
        dismiss()
    }

    private func deduplicateName(_ name: String) -> String {
        let existingNames = Set(AppDelegate.services.layoutService.loadAll().map(\.name))
        guard existingNames.contains(name) else { return name }
        var suffix = 1
        var candidate = "\(name) (\(suffix))"
        while existingNames.contains(candidate) {
            suffix += 1
            candidate = "\(name) (\(suffix))"
        }
        return candidate
    }

    // MARK: - Preset List

    private var presetListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("layouts.addFromPreset"))
                .font(.headline)

            VStack(spacing: 1) {
                ForEach(WorkspacePreset.allCases) { preset in
                    Button(action: {
                        layoutName = preset.displayName
                        slotAssignments = preset.slots.map { slot in
                            SlotAssignment(label: slot.label, frame: slot.frame, selectedBundleID: nil)
                        }
                        mode = .presetConfig(preset)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(.system(size: 13))
                                Text(presetDescription(preset))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(preset.slots.count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Preset Config

    private func presetConfigView(_ preset: WorkspacePreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("layouts.configurePreset"))
                .font(.headline)

            HStack {
                Text(L10n.string("saveLayout.name"))
                    .frame(width: 50, alignment: .leading)
                TextField(L10n.string("saveLayout.namePlaceholder"), text: $layoutName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(spacing: 1) {
                ForEach($slotAssignments) { $slot in
                    HStack(spacing: 8) {
                        Text(slot.label)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 70, alignment: .leading)

                        Text(positionLabel(slot.frame))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 50)

                        Picker("", selection: $slot.selectedBundleID) {
                            Text(L10n.string("layouts.anyApp"))
                                .tag(Optional<String>.none)
                            ForEach(runningApps, id: \.bundleID) { app in
                                HStack {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                    }
                                    Text(app.name)
                                }
                                .tag(Optional(app.bundleID))
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if preset.enablesZenMode {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Zen Mode")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func savePreset() {
        guard case .presetConfig(let preset) = mode else { return }
        let screenRegistry = AppDelegate.services.screenRegistry
        let fingerprints = screenRegistry.fingerprints()
        let display = fingerprints.first ?? DisplayFingerprint(
            displayID: 0, localizedName: "Display",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        let hasAppAssignment = slotAssignments.contains { $0.selectedBundleID != nil }
        let layoutMode: LayoutMode = hasAppAssignment ? .appSpecific : .template

        let snapshots = slotAssignments.map { slot in
            let bundleID = slot.selectedBundleID ?? "placeholder.\(slot.label.lowercased())"
            let appName: String
            if let bid = slot.selectedBundleID,
               let app = runningApps.first(where: { $0.bundleID == bid }) {
                appName = app.name
            } else {
                appName = slot.label
            }
            return WindowSnapshot(
                id: UUID(), appBundleID: bundleID, appName: appName,
                title: nil, role: "AXWindow", subrole: "AXStandardWindow",
                relativeFrame: slot.frame, display: display,
                isMinimized: false, wasFullscreen: false
            )
        }

        let name = layoutName.isEmpty ? preset.displayName : layoutName
        let layout = WindowLayout(name: name, mode: layoutMode, windows: snapshots)
        onSave(layout)
        dismiss()
    }

    // MARK: - Helpers

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

    private func presetDescription(_ preset: WorkspacePreset) -> String {
        preset.slots.map(\.label).joined(separator: " + ")
            + (preset.enablesZenMode ? " + Zen" : "")
    }

    private func positionLabel(_ frame: RelativeFrame) -> String {
        "\(Int(frame.width * 100))x\(Int(frame.height * 100))%"
    }
}

struct SlotAssignment: Identifiable {
    let id = UUID()
    var label: String
    var frame: RelativeFrame
    var selectedBundleID: String?
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var appSettings = AppDelegate.services.appSettings

    var body: some View {
        Form {
            Section(L10n.string("general.language")) {
                LabeledContent(L10n.string("general.language")) {
                    Picker("", selection: $localization.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(languageLabel(lang)).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .onChange(of: localization.currentLanguage) { _, _ in
                    AppDelegate.statusBar.rebuildMenu()
                    if let window = NSApp.windows.first(where: { $0.title.contains("ReDock") || $0.title.contains("設定") }) {
                        window.title = L10n.string("window.reDockSettings")
                    }
                }
            }

            Section(L10n.string("general.startup")) {
                Toggle(L10n.string("general.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }
            }

            Section(L10n.string("general.windowManagement")) {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(L10n.string("general.repeatPressCycleTimeout")) {
                        HStack(spacing: 12) {
                            Text(String(format: "%.1fs", appSettings.actionCycleTimeout))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 52, alignment: .trailing)

                            Stepper(
                                "",
                                value: Binding(
                                    get: { appSettings.actionCycleTimeout },
                                    set: { appSettings.actionCycleTimeout = $0 }
                                ),
                                in: AppSettings.actionCycleTimeoutRange,
                                step: 0.1
                            )
                            .labelsHidden()
                            .fixedSize()
                        }
                    }

                    Text(L10n.string("general.repeatPressCycleTimeoutHelp"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.string("general.about")) {
                LabeledContent(L10n.string("general.version"), value: Bundle.main.shortVersion)
                LabeledContent(L10n.string("general.build"), value: Bundle.main.buildVersion)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func languageLabel(_ lang: AppLanguage) -> String {
        let systemLang = LocalizationManager.detectSystemLanguage()
        if lang == systemLang {
            return lang.displayName + lang.systemSuffix
        }
        return lang.displayName
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

// MARK: - Shortcut Name Resolver

/// Maps KeyboardShortcuts.Name to human-readable display names.
enum ShortcutNameResolver {
    /// Built-in shortcut name → localized display name.
    private static let builtInDisplayNames: [String: String] = [
        "leftHalf": "menu.leftHalf",
        "rightHalf": "menu.rightHalf",
        "topHalf": "menu.topHalf",
        "bottomHalf": "menu.bottomHalf",
        "topLeft": "menu.topLeft",
        "topRight": "menu.topRight",
        "bottomLeft": "menu.bottomLeft",
        "bottomRight": "menu.bottomRight",
        "center": "menu.center",
        "maximize": "menu.maximize",
        "toggleFullScreen": "menu.fullScreen",
        "increase": "menu.makeLarger",
        "decrease": "menu.makeSmaller",
        "nextScreen": "menu.nextDisplay",
        "previousScreen": "menu.previousDisplay",
        "toggleFocusMode": "menu.focusMode",
    ]

    /// All shortcut names in the system: built-in + workspace slots + layout-specific.
    static func allShortcutNames(layouts: [WindowLayout]) -> [(KeyboardShortcuts.Name, String)] {
        var result: [(KeyboardShortcuts.Name, String)] = []

        // Built-in shortcuts
        for builtIn in LayoutShortcutManager.builtInNames {
            let display = displayName(for: builtIn, layouts: layouts)
            result.append((builtIn, display))
        }

        // Layout-specific shortcuts (not assigned to workspace slots)
        let slotLayoutIDs = Set((5...9).compactMap { WorkspaceSlotManager.layoutID(for: $0) })
        for layout in layouts where !slotLayoutIDs.contains(layout.id) {
            let name = LayoutShortcutManager.shortcutName(for: layout.id)
            if KeyboardShortcuts.getShortcut(for: name) != nil {
                result.append((name, layout.name))
            }
        }

        return result
    }

    /// Human-readable name for a shortcut name.
    static func displayName(for name: KeyboardShortcuts.Name, layouts: [WindowLayout]) -> String {
        // Check built-in names
        if let locKey = builtInDisplayNames[name.rawValue] {
            return L10n.string(locKey)
        }

        // Workspace slot → show assigned layout name
        let slots: [(String, Int)] = [
            ("workspaceSlot5", 5), ("workspaceSlot6", 6), ("workspaceSlot7", 7),
            ("workspaceSlot8", 8), ("workspaceSlot9", 9),
        ]
        for (rawName, idx) in slots where name.rawValue == rawName {
            if let layoutID = WorkspaceSlotManager.layoutID(for: idx),
               let layout = layouts.first(where: { $0.id == layoutID }) {
                return layout.name
            }
            return L10n.string("layouts.workspaceSlot", idx)
        }

        // Layout-specific shortcut
        if name.rawValue.hasPrefix("layout-"),
           let uuidString = name.rawValue.split(separator: "-", maxSplits: 1).last,
           let uuid = UUID(uuidString: String(uuidString)),
           let layout = layouts.first(where: { $0.id == uuid }) {
            return layout.name
        }

        return name.rawValue
    }
}

// MARK: - Shortcut Recorder with updatable onChange

/// Wraps KeyboardShortcuts.RecorderCocoa so that the onChange callback
/// is always up-to-date (the library's SwiftUI Recorder only sets onChange
/// in makeNSView, never in updateNSView).
struct ShortcutRecorderView: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onChange: (KeyboardShortcuts.Shortcut?) -> Void

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name) { shortcut in
            context.coordinator.onChange(shortcut)
        }
        return recorder
    }

    func updateNSView(_ nsView: KeyboardShortcuts.RecorderCocoa, context: Context) {
        nsView.shortcutName = name
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator {
        var onChange: (KeyboardShortcuts.Shortcut?) -> Void

        init(onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void) {
            self.onChange = onChange
        }
    }
}
