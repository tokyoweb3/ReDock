import Foundation

/// Summary of a layout restoration attempt.
struct RestoreResult {
    var layoutName: String
    var restored: Int
    var skipped: Int
    var failed: Int
    var details: [WindowRestoreDetail]

    var summary: String {
        "\(layoutName): \(restored) restored, \(skipped) skipped, \(failed) failed"
    }
}

struct WindowRestoreDetail {
    var appName: String
    var status: Status

    enum Status {
        case restored
        case skipped(reason: String)
        case failed(reason: String)
    }

    var statusDescription: String {
        switch status {
        case .restored: return "restored"
        case .skipped(let reason): return "skipped: \(reason)"
        case .failed(let reason): return "failed: \(reason)"
        }
    }
}
