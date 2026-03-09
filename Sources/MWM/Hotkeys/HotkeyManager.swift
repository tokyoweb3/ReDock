import Foundation
import KeyboardShortcuts

// MARK: - Shortcut Name Definitions

extension KeyboardShortcuts.Name {
    // Halves
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option, .command]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option, .command]))
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option, .command]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option, .command]))

    // Quarters
    static let topLeft = Self("topLeft", default: .init(.one, modifiers: [.control, .option, .command]))
    static let topRight = Self("topRight", default: .init(.two, modifiers: [.control, .option, .command]))
    static let bottomLeft = Self("bottomLeft", default: .init(.three, modifiers: [.control, .option, .command]))
    static let bottomRight = Self("bottomRight", default: .init(.four, modifiers: [.control, .option, .command]))

    // Sizing
    static let center = Self("center", default: .init(.c, modifiers: [.control, .option, .command]))
    static let maximize = Self("maximize", default: .init(.m, modifiers: [.control, .option, .command]))
    static let toggleFullScreen = Self("toggleFullScreen", default: .init(.f, modifiers: [.control, .option, .command]))

    // Resize
    static let increase = Self("increase", default: .init(.equal, modifiers: [.control, .option, .command]))
    static let decrease = Self("decrease", default: .init(.minus, modifiers: [.control, .option, .command]))

    // Multi-display
    static let nextScreen = Self("nextScreen", default: .init(.n, modifiers: [.control, .option, .command]))
    static let previousScreen = Self("previousScreen", default: .init(.p, modifiers: [.control, .option, .command]))

    // Focus Mode
    static let toggleFocusMode = Self("toggleFocusMode", default: .init(.z, modifiers: [.control, .option, .command]))

    // Workspace slots (numbered 5-9)
    static let workspaceSlot5 = Self("workspaceSlot5", default: .init(.five, modifiers: [.control, .option, .command]))
    static let workspaceSlot6 = Self("workspaceSlot6", default: .init(.six, modifiers: [.control, .option, .command]))
    static let workspaceSlot7 = Self("workspaceSlot7", default: .init(.seven, modifiers: [.control, .option, .command]))
    static let workspaceSlot8 = Self("workspaceSlot8", default: .init(.eight, modifiers: [.control, .option, .command]))
    static let workspaceSlot9 = Self("workspaceSlot9", default: .init(.nine, modifiers: [.control, .option, .command]))

    // Legacy names (kept for backwards compat with saved shortcuts)
    static let workspaceCoding = Self("workspaceCoding")
    static let workspaceResearch = Self("workspaceResearch")
    static let workspaceReview = Self("workspaceReview")
    static let workspaceMeeting = Self("workspaceMeeting")
    static let workspaceWriting = Self("workspaceWriting")
}

/// All workspace slot shortcut names in order.
let workspaceSlotNames: [KeyboardShortcuts.Name] = [
    .workspaceSlot5, .workspaceSlot6, .workspaceSlot7,
    .workspaceSlot8, .workspaceSlot9,
]

// MARK: - Workspace Slot Manager

/// Manages which layout is assigned to each workspace slot (5-9).
/// Stored in UserDefaults as slot index -> layout UUID string.
enum WorkspaceSlotManager {
    private static let prefix = "workspaceSlot"

    /// Get the layout ID assigned to a slot index (5-9).
    static func layoutID(for slotIndex: Int) -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: "\(prefix).\(slotIndex)") else { return nil }
        return UUID(uuidString: str)
    }

    /// Set the layout ID for a slot index (5-9). Pass nil to unassign.
    static func setLayoutID(_ id: UUID?, for slotIndex: Int) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: "\(prefix).\(slotIndex)")
        } else {
            UserDefaults.standard.removeObject(forKey: "\(prefix).\(slotIndex)")
        }
    }

    /// Assign default preset layouts to empty slots.
    static func seedDefaultAssignments(layouts: [WindowLayout]) {
        let presetNames = WorkspacePreset.allCases.map(\.displayName)
        let slotIndices = [5, 6, 7, 8, 9]

        for (i, presetName) in presetNames.enumerated() {
            let slotIndex = slotIndices[i]
            // Only seed if slot is empty
            guard layoutID(for: slotIndex) == nil else { continue }
            // Find the layout matching this preset name
            if let layout = layouts.first(where: { $0.name == presetName }) {
                setLayoutID(layout.id, for: slotIndex)
            }
        }
    }
}

// MARK: - Hotkey Manager

/// Manages global hotkey registration.
/// Routes window actions through the shared WindowActionDispatcher.
final class HotkeyManager {
    private let dispatcher: WindowActionDispatcher

    init(dispatcher: WindowActionDispatcher) {
        self.dispatcher = dispatcher
    }

    func registerAll() {
        let bindings: [(KeyboardShortcuts.Name, WindowAction)] = [
            (.leftHalf, .leftHalf),
            (.rightHalf, .rightHalf),
            (.topHalf, .topHalf),
            (.bottomHalf, .bottomHalf),
            (.topLeft, .topLeft),
            (.topRight, .topRight),
            (.bottomLeft, .bottomLeft),
            (.bottomRight, .bottomRight),
            (.center, .center),
            (.maximize, .maximize),
            (.toggleFullScreen, .toggleFullScreen),
            (.increase, .increase),
            (.decrease, .decrease),
            (.nextScreen, .nextScreen),
            (.previousScreen, .previousScreen),
        ]

        for (name, action) in bindings {
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                guard let self else { return }
                guard let resolvedAction = self.dispatcher.dispatch(action) else { return }
                guard ActionCycle.sequence(for: action).count > 1 else { return }
                ActionOverlayWindow.showForShortcut(name: name, action: resolvedAction)
            }
        }

        // Focus Mode has its own handler (not a WindowAction)
        KeyboardShortcuts.onKeyUp(for: .toggleFocusMode) {
            let service = AppDelegate.services.focusModeService
            service.toggle()
            let title = service.isActive
                ? L10n.string("menu.focusMode")
                : L10n.string("menu.exitFocusMode")
            ActionOverlayWindow.showForShortcut(name: .toggleFocusMode, title: title)
        }

        // Workspace slots → restore assigned layout
        let slotIndices = [5, 6, 7, 8, 9]
        for (name, slotIndex) in zip(workspaceSlotNames, slotIndices) {
            KeyboardShortcuts.onKeyUp(for: name) {
                Self.restoreSlot(slotIndex)
            }
        }
    }

    private static func restoreSlot(_ slotIndex: Int) {
        let services = AppDelegate.services
        guard let layoutID = WorkspaceSlotManager.layoutID(for: slotIndex),
              let layout = services.layoutService.loadAll().first(where: { $0.id == layoutID }) else {
            return
        }
        Task {
            let result = await services.layoutService.restoreLayoutAsync(layout)
            services.diagnosticsService.record(result: result, triggerSource: "workspace-slot-\(slotIndex)")
        }

        let shortcutName = workspaceSlotNames[slotIndex - 5]
        ActionOverlayWindow.showForShortcut(name: shortcutName, title: layout.name)
    }

    static func displayTitle(for action: WindowAction) -> String {
        action.displayName
    }
}
