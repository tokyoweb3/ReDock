import CoreGraphics

/// Frame stored as ratios relative to the display's visible frame.
/// This allows restoration across different display resolutions.
struct RelativeFrame: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    /// Create from an absolute frame and the display's visible frame.
    static func from(absoluteFrame: CGRect, visibleFrame: CGRect) -> RelativeFrame {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else {
            return RelativeFrame(x: 0, y: 0, width: 1, height: 1)
        }
        return RelativeFrame(
            x: (absoluteFrame.origin.x - visibleFrame.origin.x) / visibleFrame.width,
            y: (absoluteFrame.origin.y - visibleFrame.origin.y) / visibleFrame.height,
            width: absoluteFrame.width / visibleFrame.width,
            height: absoluteFrame.height / visibleFrame.height
        )
    }

    /// Convert back to absolute frame given a target display's visible frame.
    func toAbsoluteFrame(in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.origin.x + x * visibleFrame.width,
            y: visibleFrame.origin.y + y * visibleFrame.height,
            width: width * visibleFrame.width,
            height: height * visibleFrame.height
        )
    }
}
