import AppKit

/// A stable identifier for a display that survives app restarts.
///
/// `CGDirectDisplayID` is the primary key at runtime, but it can change
/// across reboots. For persistent matching (layout restore), we fall back
/// to `localizedName` + `bounds` approximate matching.
struct DisplayFingerprint: Codable, Hashable, Identifiable {
    var id: UInt32 { displayID }

    /// `CGDirectDisplayID` — stable within a session, may change across reboots.
    var displayID: UInt32

    /// Human-readable display name (e.g. "Built-in Retina Display").
    var localizedName: String?

    /// Full bounds in CG global coordinates.
    var bounds: CGRect

    /// Create from an NSScreen.
    static func from(_ screen: NSScreen) -> DisplayFingerprint {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        return DisplayFingerprint(
            displayID: displayID,
            localizedName: screen.localizedName,
            bounds: ScreenGeometry.frameInCG(for: screen)
        )
    }

    /// Check if this fingerprint approximately matches another
    /// (for cross-session restore where displayID may have changed).
    func approximatelyMatches(_ other: DisplayFingerprint) -> Bool {
        if displayID == other.displayID && displayID != 0 {
            return true
        }
        if let name = localizedName, let otherName = other.localizedName, name == otherName {
            let sizeSimilar = abs(bounds.width - other.bounds.width) < 100
                && abs(bounds.height - other.bounds.height) < 100
            return sizeSimilar
        }
        return false
    }
}

// MARK: - CGRect Codable conformance helper

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }
}
