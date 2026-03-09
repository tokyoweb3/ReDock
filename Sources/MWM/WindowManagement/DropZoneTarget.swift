import CoreGraphics

enum DropZoneTarget: Equatable {
    case basic(WindowAction)
}

struct DropZone: Equatable, Identifiable {
    let id: String
    let frame: CGRect
    let target: DropZoneTarget
    let title: String
}
