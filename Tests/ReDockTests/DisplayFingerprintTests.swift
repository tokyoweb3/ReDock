import CoreGraphics
import Testing
@testable import ReDock

@Suite("DisplayFingerprint matching")
struct DisplayFingerprintTests {
    @Test("Exact displayID match")
    func exactMatch() {
        let a = DisplayFingerprint(
            displayID: 42,
            localizedName: "Dell U2723QE",
            bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )
        let b = DisplayFingerprint(
            displayID: 42,
            localizedName: "Dell U2723QE",
            bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )
        #expect(a.approximatelyMatches(b))
    }

    @Test("DisplayID mismatch but same name and similar size")
    func approximateMatchByNameAndSize() {
        let a = DisplayFingerprint(
            displayID: 42,
            localizedName: "Built-in Retina Display",
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117)
        )
        let b = DisplayFingerprint(
            displayID: 99,
            localizedName: "Built-in Retina Display",
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117)
        )
        #expect(a.approximatelyMatches(b))
    }

    @Test("Different name and different ID do not match")
    func noMatch() {
        let a = DisplayFingerprint(
            displayID: 1,
            localizedName: "Built-in Retina Display",
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117)
        )
        let b = DisplayFingerprint(
            displayID: 2,
            localizedName: "Dell U2723QE",
            bounds: CGRect(x: 1728, y: 0, width: 3840, height: 2160)
        )
        #expect(!a.approximatelyMatches(b))
    }

    @Test("Same name but very different size do not match")
    func sameNameDifferentSize() {
        let a = DisplayFingerprint(
            displayID: 1,
            localizedName: "LG HDR 4K",
            bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )
        let b = DisplayFingerprint(
            displayID: 2,
            localizedName: "LG HDR 4K",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        #expect(!a.approximatelyMatches(b))
    }

    @Test("Zero displayID forces name-based matching")
    func zeroDisplayID() {
        let a = DisplayFingerprint(
            displayID: 0,
            localizedName: "ASUS ProArt",
            bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440)
        )
        let b = DisplayFingerprint(
            displayID: 0,
            localizedName: "ASUS ProArt",
            bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440)
        )
        #expect(a.approximatelyMatches(b))
    }
}
