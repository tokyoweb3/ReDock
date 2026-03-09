import AppKit
import CoreGraphics

struct DropZoneSession {
    let window: WindowInfo
    var screen: NSScreen?
    var screenFrame: CGRect
    var zones: [DropZone]

    var activeZoneID: String?
    var isActive = true

    init(
        window: WindowInfo,
        screen: NSScreen? = nil,
        screenFrame: CGRect,
        zones: [DropZone] = [],
        activeZoneID: String? = nil,
        isActive: Bool = true
    ) {
        self.window = window
        self.screen = screen
        self.screenFrame = screenFrame
        self.zones = zones
        self.activeZoneID = activeZoneID
        self.isActive = isActive
    }

    var activeTarget: DropZoneTarget? {
        zones.first(where: { $0.id == activeZoneID })?.target
    }

    mutating func updateHover(at point: CGPoint) {
        activeZoneID = DropZoneResolver.hitTest(point: point, zones: zones)?.id
    }

    mutating func end() {
        isActive = false
        activeZoneID = nil
    }
}
