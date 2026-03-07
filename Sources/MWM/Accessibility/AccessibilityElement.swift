import AppKit
import ApplicationServices

/// A Swift wrapper around AXUIElement for window management.
/// Inspired by Rectangle's AccessibilityElement and alt-tab-macos patterns.
final class AccessibilityElement {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    init(pid: pid_t) {
        self.element = AXUIElementCreateApplication(pid)
    }

    // MARK: - Attribute Access

    func attribute<T>(_ key: String) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }

    func axValue<T>(_ key: String, type: AXValueType) -> T? {
        guard let rawValue: AXValue = attribute(key) else { return nil }
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        guard AXValueGetValue(rawValue, type, ptr) else { return nil }
        return ptr.pointee
    }

    func setAttribute(_ key: String, value: AnyObject) {
        AXUIElementSetAttributeValue(element, key as CFString, value)
    }

    func setPositionValue(_ key: String, value: CGPoint) {
        var point = value
        guard let axValue = AXValueCreate(.cgPoint, &point) else { return }
        setAttribute(key, value: axValue)
    }

    func setSizeValue(_ key: String, value: CGSize) {
        var size = value
        guard let axValue = AXValueCreate(.cgSize, &size) else { return }
        setAttribute(key, value: axValue)
    }

    // MARK: - Window Properties

    var position: CGPoint? {
        get { axValue(kAXPositionAttribute, type: .cgPoint) }
        set {
            guard let point = newValue else { return }
            setPositionValue(kAXPositionAttribute, value: point)
        }
    }

    var size: CGSize? {
        get { axValue(kAXSizeAttribute, type: .cgSize) }
        set {
            guard let size = newValue else { return }
            setSizeValue(kAXSizeAttribute, value: size)
        }
    }

    /// Window frame in CG global coordinates (same as AXUIElement native coords).
    var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size)
    }

    var title: String? {
        attribute(kAXTitleAttribute)
    }

    var role: String? {
        attribute(kAXRoleAttribute)
    }

    var subrole: String? {
        attribute(kAXSubroleAttribute)
    }

    var isMinimized: Bool {
        attribute(kAXMinimizedAttribute) ?? false
    }

    var isFullscreen: Bool {
        attribute("AXFullScreen") ?? false
    }

    var isResizable: Bool {
        var isSettable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &isSettable)
        return result == .success && isSettable.boolValue
    }

    var isWindow: Bool {
        guard role == kAXWindowRole else { return false }
        let validSubroles: Set<String?> = [kAXStandardWindowSubrole, kAXDialogSubrole]
        if validSubroles.contains(subrole) { return true }
        // Stage Manager may report windows with non-standard subroles;
        // accept them if they have a valid frame and are not minimized.
        if StageManagerDetector.isEnabled, frame != nil, !isMinimized {
            // Exclude known non-window subroles
            if let sr = subrole, StageManagerDetector.excludedSubroles.contains(sr) {
                return false
            }
            return true
        }
        return false
    }

    // MARK: - Frame Manipulation

    /// Set window frame with cross-display safety.
    /// When moving across displays, use size->position->size order
    /// to avoid macOS clamping the window to the wrong screen.
    /// (Pattern from Rectangle's AccessibilityElement)
    func setFrame(_ newFrame: CGRect) {
        guard let currentFrame = frame else { return }

        let currentScreen = ScreenGeometry.screen(containing: currentFrame)
        let targetScreen = ScreenGeometry.screen(containing: newFrame)
        let movingAcrossDisplays = currentScreen != targetScreen

        if movingAcrossDisplays {
            size = newFrame.size
            position = newFrame.origin
            size = newFrame.size
        } else {
            position = newFrame.origin
            size = newFrame.size
        }
    }

    // MARK: - Window Discovery

    var windows: [AccessibilityElement] {
        guard let windowList: [AXUIElement] = attribute(kAXWindowsAttribute) else {
            return []
        }
        return windowList
            .map { AccessibilityElement($0) }
            .filter { $0.isWindow }
    }

    var focusedWindow: AccessibilityElement? {
        guard let window: AXUIElement = attribute(kAXFocusedWindowAttribute) else {
            return nil
        }
        return AccessibilityElement(window)
    }

    // MARK: - Static Helpers

    static func focusedApplication() -> AccessibilityElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AccessibilityElement(pid: app.processIdentifier)
    }

    static func focusedWindow() -> AccessibilityElement? {
        focusedApplication()?.focusedWindow
    }

    static func systemWide() -> AccessibilityElement {
        AccessibilityElement(AXUIElementCreateSystemWide())
    }
}
