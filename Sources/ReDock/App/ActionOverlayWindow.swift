import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

/// A floating HUD overlay that briefly shows the action name and shortcut key combo.
/// Provides visual feedback when workspace or zen mode shortcuts are activated.
final class ActionOverlayWindow {
    static let shared = ActionOverlayWindow()

    private var panel: NSPanel?
    private var fadeOutWorkItem: DispatchWorkItem?

    private init() {}

    /// Show overlay for a keyboard shortcut action.
    static func showForShortcut(name: KeyboardShortcuts.Name, title: String) {
        let subtitle = KeyboardShortcuts.getShortcut(for: name).map { formatShortcut($0) }
        shared.show(title: title, subtitle: subtitle)
    }

    static func showForShortcut(name: KeyboardShortcuts.Name, action: WindowAction) {
        showForShortcut(name: name, title: action.displayName)
    }

    /// Show the overlay with the given action name and optional shortcut description.
    func show(title: String, subtitle: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.showOnMainThread(title: title, subtitle: subtitle)
        }
    }

    private func showOnMainThread(title: String, subtitle: String?) {
        // Cancel any pending fade-out
        fadeOutWorkItem?.cancel()

        // Remove existing panel
        panel?.orderOut(nil)
        panel = nil

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = subtitle != nil ? 80 : 56

        let panel = NSPanel(
            contentRect: NSRect(
                x: screen.frame.midX - panelWidth / 2,
                y: screen.frame.midY + screen.frame.height * 0.15,
                width: panelWidth,
                height: panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        // Visual effect background
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true

        // Title label
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        if let subtitle {
            let subtitleLabel = NSTextField(labelWithString: subtitle)
            subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
            subtitleLabel.textColor = .white.withAlphaComponent(0.6)
            subtitleLabel.alignment = .center
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

            let stack = NSStackView(views: [titleLabel, subtitleLabel])
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 2
            stack.translatesAutoresizingMaskIntoConstraints = false
            effectView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -20),
            ])
        } else {
            effectView.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -20),
            ])
        }

        panel.contentView = effectView

        // Fade in
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        // Schedule fade out
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 0
            }
            // Guaranteed cleanup after animation duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        }
        fadeOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    // MARK: - Shortcut Formatting

    static func formatShortcut(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
        var result = ""
        if shortcut.modifiers.contains(.control) { result += "⌃" }
        if shortcut.modifiers.contains(.option) { result += "⌥" }
        if shortcut.modifiers.contains(.shift) { result += "⇧" }
        if shortcut.modifiers.contains(.command) { result += "⌘" }
        result += keyName(for: shortcut.carbonKeyCode)
        return result
    }

    private static func keyName(for carbonKeyCode: Int) -> String {
        switch carbonKeyCode {
        case 123: return "←"
        case 124: return "→"
        case 126: return "↑"
        case 125: return "↓"
        case 36: return "↩"
        case 53: return "⎋"
        case 49: return "Space"
        case 51: return "⌫"
        case 48: return "⇥"
        default: break
        }

        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        UCKeyTranslate(
            keyboardLayout,
            UInt16(carbonKeyCode),
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
