import Foundation

/// Built-in workspace presets for common AI development workflows.
/// Each preset defines a set of window positions and optionally enables Zen mode.
enum WorkspacePreset: String, CaseIterable, Identifiable {
    case coding
    case research
    case review
    case meeting
    case writing

    var id: String { rawValue }

    var displayName: String {
        L10n.string("workspace.\(rawValue)")
    }

    var icon: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .research: return "book"
        case .review: return "doc.text.magnifyingglass"
        case .meeting: return "video"
        case .writing: return "pencil.line"
        }
    }

    /// Whether this preset enables Zen (Focus) mode.
    var enablesZenMode: Bool {
        self == .writing
    }

    /// Window slot definitions for this preset as template positions.
    var slots: [WorkspaceSlot] {
        switch self {
        case .coding:
            // Editor left 60% + Terminal right-top 40%x50% + Browser right-bottom 40%x50%
            return [
                WorkspaceSlot(label: "Editor", frame: RelativeFrame(x: 0, y: 0, width: 0.6, height: 1)),
                WorkspaceSlot(label: "Terminal", frame: RelativeFrame(x: 0.6, y: 0, width: 0.4, height: 0.5)),
                WorkspaceSlot(label: "Browser", frame: RelativeFrame(x: 0.6, y: 0.5, width: 0.4, height: 0.5)),
            ]
        case .research:
            // Browser left 50% + Notes right 50%
            return [
                WorkspaceSlot(label: "Browser", frame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)),
                WorkspaceSlot(label: "Notes", frame: RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)),
            ]
        case .review:
            // Editor left 50% + Terminal right 50%
            return [
                WorkspaceSlot(label: "Editor", frame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)),
                WorkspaceSlot(label: "Terminal", frame: RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)),
            ]
        case .meeting:
            // Browser maximized
            return [
                WorkspaceSlot(label: "Browser", frame: RelativeFrame(x: 0, y: 0, width: 1, height: 1)),
            ]
        case .writing:
            // Editor centered at 70%
            return [
                WorkspaceSlot(label: "Editor", frame: RelativeFrame(x: 0.15, y: 0, width: 0.7, height: 1)),
            ]
        }
    }
}

/// A single window position slot in a workspace preset.
struct WorkspaceSlot {
    var label: String
    var frame: RelativeFrame
}

// MARK: - Convert to Layout

extension WorkspacePreset {
    /// Convert this preset into a template WindowLayout for customization.
    func toLayout(screenRegistry: ScreenRegistry) -> WindowLayout {
        let fingerprints = screenRegistry.fingerprints()
        let display = fingerprints.first ?? DisplayFingerprint(
            displayID: 0,
            localizedName: "Display",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        let snapshots = slots.map { slot in
            WindowSnapshot(
                id: UUID(),
                appBundleID: "placeholder.\(slot.label.lowercased())",
                appName: slot.label,
                title: nil,
                role: "AXWindow",
                subrole: "AXStandardWindow",
                relativeFrame: slot.frame,
                display: display,
                isMinimized: false,
                wasFullscreen: false
            )
        }

        return WindowLayout(
            name: displayName,
            mode: .template,
            windows: snapshots
        )
    }
}
