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
}

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
                self?.dispatcher.dispatch(action)
            }
        }

        // Focus Mode has its own handler (not a WindowAction)
        KeyboardShortcuts.onKeyUp(for: .toggleFocusMode) {
            AppDelegate.services.focusModeService.toggle()
        }
    }
}
