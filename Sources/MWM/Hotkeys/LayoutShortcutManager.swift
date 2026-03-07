import Foundation
import KeyboardShortcuts
import os

/// Manages dynamic keyboard shortcuts for individual layouts.
/// Each layout gets its own KeyboardShortcuts.Name keyed by UUID.
final class LayoutShortcutManager {
    private static let logger = Logger(subsystem: "com.mwm.app", category: "LayoutShortcuts")

    private var registeredIDs: Set<UUID> = []

    /// KeyboardShortcuts.Name for a given layout UUID.
    static func shortcutName(for layoutID: UUID) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("layout-\(layoutID.uuidString)")
    }

    /// All built-in shortcut names that can conflict with layout shortcuts.
    static let builtInNames: [KeyboardShortcuts.Name] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf,
        .topLeft, .topRight, .bottomLeft, .bottomRight,
        .center, .maximize, .toggleFullScreen,
        .increase, .decrease,
        .nextScreen, .previousScreen,
        .toggleFocusMode,
        .workspaceSlot5, .workspaceSlot6, .workspaceSlot7,
        .workspaceSlot8, .workspaceSlot9,
    ]

    /// Register shortcuts for all layouts that have a shortcut assigned.
    /// Resolves conflicts using last-write-wins: if a new shortcut conflicts
    /// with an existing one, the old binding is removed.
    func registerAll(layouts: [WindowLayout]) {
        // Clear old handlers
        for id in registeredIDs {
            KeyboardShortcuts.onKeyUp(for: Self.shortcutName(for: id)) {}
        }
        registeredIDs.removeAll()

        // Resolve conflicts: last-write-wins
        resolveConflicts(layouts: layouts)

        // Register handlers for layouts that have shortcuts
        for layout in layouts {
            let name = Self.shortcutName(for: layout.id)
            guard KeyboardShortcuts.getShortcut(for: name) != nil else { continue }

            let layoutID = layout.id
            KeyboardShortcuts.onKeyUp(for: name) {
                Self.restoreLayout(id: layoutID)
            }
            registeredIDs.insert(layout.id)
        }

        Self.logger.info("Registered shortcuts for \(self.registeredIDs.count) layouts")
    }

    /// Resolve shortcut conflicts. When a layout shortcut conflicts with a
    /// built-in or another layout shortcut, the older binding is removed.
    private func resolveConflicts(layouts: [WindowLayout]) {
        // Collect all layout shortcuts
        var seenShortcuts: [(shortcut: KeyboardShortcuts.Shortcut, name: KeyboardShortcuts.Name)] = []

        // First collect built-in shortcuts
        for builtIn in Self.builtInNames {
            if let shortcut = KeyboardShortcuts.getShortcut(for: builtIn) {
                seenShortcuts.append((shortcut, builtIn))
            }
        }

        // Then process layout shortcuts in order (later = higher priority)
        for layout in layouts {
            let name = Self.shortcutName(for: layout.id)
            guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { continue }

            // Check for conflicts with everything seen so far
            for (existingShortcut, existingName) in seenShortcuts {
                if existingShortcut == shortcut {
                    // Remove the OLD conflicting binding (last-write-wins)
                    KeyboardShortcuts.reset(existingName)
                    Self.logger.info("Removed conflicting shortcut from '\(existingName.rawValue)' in favor of layout '\(layout.name)'")
                }
            }

            // Remove earlier conflicts from the seen list and add this one
            seenShortcuts.removeAll { $0.shortcut == shortcut }
            seenShortcuts.append((shortcut, name))
        }
    }

    /// Check if a layout's shortcut conflicts with built-in or other layout shortcuts.
    /// Returns the display name of the conflicting action, or nil.
    static func conflictingAction(for layoutID: UUID, allLayouts: [WindowLayout]) -> String? {
        let name = shortcutName(for: layoutID)
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return nil }

        // Check against built-in shortcuts
        for builtIn in builtInNames {
            if let existing = KeyboardShortcuts.getShortcut(for: builtIn),
               existing == shortcut {
                return builtIn.rawValue
            }
        }

        // Check against other layout shortcuts
        for layout in allLayouts where layout.id != layoutID {
            let otherName = shortcutName(for: layout.id)
            if let existing = KeyboardShortcuts.getShortcut(for: otherName),
               existing == shortcut {
                return layout.name
            }
        }

        return nil
    }

    /// Remove all conflicting bindings for a given shortcut, except the specified layout.
    static func removeConflicting(shortcut: KeyboardShortcuts.Shortcut, except layoutID: UUID, allLayouts: [WindowLayout]) {
        // Remove from built-in shortcuts
        for builtIn in builtInNames {
            if let existing = KeyboardShortcuts.getShortcut(for: builtIn),
               existing == shortcut {
                KeyboardShortcuts.reset(builtIn)
                logger.info("Removed conflicting built-in shortcut '\(builtIn.rawValue)'")
            }
        }

        // Remove from other layout shortcuts
        for layout in allLayouts where layout.id != layoutID {
            let otherName = shortcutName(for: layout.id)
            if let existing = KeyboardShortcuts.getShortcut(for: otherName),
               existing == shortcut {
                KeyboardShortcuts.reset(otherName)
                logger.info("Removed conflicting layout shortcut '\(layout.name)'")
            }
        }
    }

    private static func restoreLayout(id: UUID) {
        let services = AppDelegate.services
        guard let layout = services.layoutService.loadAll().first(where: { $0.id == id }) else {
            logger.warning("Layout \(id) not found for shortcut")
            return
        }
        let result = services.layoutService.restoreLayout(layout)
        services.diagnosticsService.record(result: result, triggerSource: "shortcut")
    }
}
