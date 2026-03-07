import Foundation

/// State of an active Focus Mode session.
struct FocusSession {
    var focusedAppBundleID: String
    var focusedWindowTitle: String?
    var originalFrame: CGRect?
    var hiddenAppBundleIDs: [String]
}
