import AppKit
import KeyboardShortcuts
import SwiftUI

/// Manages the settings window as a standalone NSWindow.
/// SwiftUI Settings scene doesn't work reliably with MenuBarExtra(.menu).
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 620, height: 480)

        let window = ShortcutAwareWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.string("window.mwmSettings")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

// MARK: - Window that suspends Carbon hot keys only while a Recorder is focused

/// Overrides `makeFirstResponder` to detect when a KeyboardShortcuts.RecorderCocoa
/// gains/loses focus. Suspends Carbon hot keys only during active recording so that
/// already-registered key combos can be re-assigned, while keeping shortcuts working
/// the rest of the time.
final class ShortcutAwareWindow: NSWindow {
    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let result = super.makeFirstResponder(responder)
        if result {
            KeyboardShortcuts.isEnabled = !isRecorderActive(responder)
        }
        return result
    }

    private func isRecorderActive(_ responder: NSResponder?) -> Bool {
        // Walk the responder chain: field editor → RecorderCocoa → superview → ...
        var current: NSResponder? = responder
        while let r = current {
            if r is KeyboardShortcuts.RecorderCocoa { return true }
            current = r.nextResponder
        }
        return false
    }
}
