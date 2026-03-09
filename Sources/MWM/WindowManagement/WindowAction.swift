import Foundation

/// All supported window actions, inspired by ShiftIt keybindings.
enum WindowAction: String, CaseIterable, Identifiable {
    // Halves
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case leftThird
    case leftTwoThirds
    case rightThird
    case rightTwoThirds
    case topThird
    case topTwoThirds
    case bottomThird
    case bottomTwoThirds

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
        let localized = L10n.string(localizationKey)
        if localized != localizationKey {
            return localized
        }

        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .leftThird: return "Left Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightThird: return "Right Third"
        case .rightTwoThirds: return "Right Two Thirds"
        case .topThird: return "Top Third"
        case .topTwoThirds: return "Top Two Thirds"
        case .bottomThird: return "Bottom Third"
        case .bottomTwoThirds: return "Bottom Two Thirds"
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

    private var localizationKey: String {
        switch self {
        case .leftHalf: return "menu.leftHalf"
        case .rightHalf: return "menu.rightHalf"
        case .topHalf: return "menu.topHalf"
        case .bottomHalf: return "menu.bottomHalf"
        case .leftThird: return "menu.leftThird"
        case .leftTwoThirds: return "menu.leftTwoThirds"
        case .rightThird: return "menu.rightThird"
        case .rightTwoThirds: return "menu.rightTwoThirds"
        case .topThird: return "menu.topThird"
        case .topTwoThirds: return "menu.topTwoThirds"
        case .bottomThird: return "menu.bottomThird"
        case .bottomTwoThirds: return "menu.bottomTwoThirds"
        case .topLeft: return "menu.topLeft"
        case .topRight: return "menu.topRight"
        case .bottomLeft: return "menu.bottomLeft"
        case .bottomRight: return "menu.bottomRight"
        case .center: return "menu.center"
        case .maximize: return "menu.maximize"
        case .toggleFullScreen: return "menu.fullScreen"
        case .increase: return "menu.makeLarger"
        case .decrease: return "menu.makeSmaller"
        case .nextScreen: return "menu.nextDisplay"
        case .previousScreen: return "menu.previousDisplay"
        }
    }
}
