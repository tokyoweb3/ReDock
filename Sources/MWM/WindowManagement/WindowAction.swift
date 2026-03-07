import Foundation

/// All supported window actions, inspired by ShiftIt keybindings.
enum WindowAction: String, CaseIterable, Identifiable {
    // Halves
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf

    // Quarters
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    // Sizing
    case center
    case maximize
    case toggleFullScreen

    // Resize
    case increase
    case decrease

    // Multi-display
    case nextScreen
    case previousScreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .center: return "Center"
        case .maximize: return "Maximize"
        case .toggleFullScreen: return "Toggle Full Screen"
        case .increase: return "Increase Size"
        case .decrease: return "Decrease Size"
        case .nextScreen: return "Next Screen"
        case .previousScreen: return "Previous Screen"
        }
    }
}
