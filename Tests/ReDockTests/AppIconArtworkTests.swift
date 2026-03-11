import CoreGraphics
import Testing
@testable import ReDock

@Suite("App icon artwork")
struct AppIconArtworkTests {
    @Test("App icon palette uses graphite tones instead of saturated blue")
    func graphitePalette() {
        let palette = AppIconPalette.graphite

        #expect(palette.top.x == 0.33)
        #expect(palette.top.z < 0.5)
        #expect(palette.middle.y == 0.27)
        #expect(palette.bottom.z == 0.18)
    }

    @Test("Three pane app icon keeps dominant left pane on rounded background")
    func threePaneArtwork() {
        let artwork = AppIconArtwork.threePane(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))

        #expect(artwork.canvas.width == 1024)
        #expect(artwork.panes.count == 3)
        #expect(artwork.backgroundInset == 51.2)
        #expect(artwork.backgroundCornerRadiusRatio == 0.18)

        let leftPane = artwork.panes[0]
        let topRightPane = artwork.panes[1]
        let bottomRightPane = artwork.panes[2]

        #expect(leftPane.width > topRightPane.width)
        #expect(leftPane.height > topRightPane.height)
        #expect(topRightPane.width == bottomRightPane.width)
        #expect(topRightPane.minX == bottomRightPane.minX)
        #expect(topRightPane.minY > bottomRightPane.minY)
        #expect(topRightPane.maxX < artwork.canvas.maxX - artwork.backgroundInset)
        #expect(bottomRightPane.maxX < artwork.canvas.maxX - artwork.backgroundInset)
    }

    @Test("Small app icon preserves visible separators between panes")
    func smallArtworkKeepsSeparators() {
        let artwork = AppIconArtwork.threePane(in: CGRect(x: 0, y: 0, width: 16, height: 16))

        let leftPane = artwork.panes[0]
        let topRightPane = artwork.panes[1]
        let bottomRightPane = artwork.panes[2]

        #expect(topRightPane.minX - leftPane.maxX >= 2)
        #expect(topRightPane.minY - bottomRightPane.maxY >= 2)
    }
}
