import CoreGraphics
import Testing
@testable import MWM

@Suite("Drop zone resolver")
struct DropZoneResolverTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("Top edge drag exposes basic snap zones")
    func topEdgeShowsBasicZones() {
        let zones = DropZoneResolver.basicZones(in: screen)
        #expect(zones.contains { $0.target == .basic(.leftHalf) })
    }

    @Test("Basic snap zones are positioned near the top edge in CG coordinates")
    func basicZonesUseTopEdgeCoordinates() {
        let zones = DropZoneResolver.basicZones(in: screen)

        #expect(zones.allSatisfy { $0.frame.minY < screen.midY })
    }

    @Test("Favorite layouts do not create extra drop targets")
    func favoriteLayoutsDoNotCreateTargets() {
        let zones = DropZoneResolver.layoutZones(in: screen, targets: [])
        #expect(zones.isEmpty)
    }

    @Test("Overlay view model only shows snap section")
    func overlayViewModelOrdering() {
        let zones = DropZoneResolver.basicZones(in: screen) + DropZoneResolver.layoutZones(
            in: screen,
            targets: []
        )

        let model = DropZoneOverlayViewModel.make(from: zones)
        #expect(model.sections.count == 1)
        #expect(model.sections.first?.title == "Snap")
    }

    @Test("Overlay view model exposes snap previews for basic items")
    func overlayViewModelIncludesSnapPreviews() {
        let model = DropZoneOverlayViewModel.make(from: DropZoneResolver.basicZones(in: screen))

        let previews = model.sections.flatMap(\.items).map(\.preview)
        #expect(previews.contains(.leftHalf))
        #expect(previews.contains(.rightHalf))
        #expect(previews.contains(.topHalf))
        #expect(previews.contains(.bottomHalf))
    }

    @Test("Snap preview highlight rect uses the correct edge")
    func snapPreviewHighlightRectUsesCorrectEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 44, height: 30)

        #expect(DropZoneOverlayViewModel.SnapPreview.leftHalf.highlightRect(in: bounds) == CGRect(x: 0, y: 0, width: 22, height: 30))
        #expect(DropZoneOverlayViewModel.SnapPreview.rightHalf.highlightRect(in: bounds) == CGRect(x: 22, y: 0, width: 22, height: 30))
        #expect(DropZoneOverlayViewModel.SnapPreview.topHalf.highlightRect(in: bounds) == CGRect(x: 0, y: 0, width: 44, height: 15))
        #expect(DropZoneOverlayViewModel.SnapPreview.bottomHalf.highlightRect(in: bounds) == CGRect(x: 0, y: 15, width: 44, height: 15))
    }

    @Test("Overlay view model exposes activation band")
    func overlayModelIncludesActivationBand() {
        let model = DropZoneOverlayViewModel.make(
            from: DropZoneResolver.basicZones(in: screen),
            activeZoneID: nil,
            activationBandFrame: CGRect(x: 0, y: 0, width: 1440, height: 96)
        )

        #expect(model.activationBand != nil)
    }

    @Test("Drag session starts with focused window and screen")
    func dragSessionStarts() {
        let session = DropZoneSession(
            window: MockWindowQuerying.makeWindowInfo(),
            screenFrame: screen
        )
        #expect(session.activeZoneID == nil)
        #expect(session.isActive)
    }

    @Test("Drag session clears after drop")
    func dragSessionEnds() {
        var session = DropZoneSession(
            window: MockWindowQuerying.makeWindowInfo(),
            screenFrame: screen
        )
        session.end()
        #expect(session.isActive == false)
    }
}
