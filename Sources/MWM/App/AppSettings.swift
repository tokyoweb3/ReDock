import AppKit
import Combine
import Foundation

final class AppSettings: ObservableObject {
    private enum Key {
        static let actionCycleTimeout = "settings.actionCycleTimeout"
        static let dropZoneActivationBandHeight = "settings.dropZoneActivationBandHeight"
    }

    static let defaultActionCycleTimeout: TimeInterval = 1.0
    static let defaultDropZoneActivationBandHeight: CGFloat = 96
    static let actionCycleTimeoutRange: ClosedRange<TimeInterval> = 0.2...10.0
    static let dropZoneActivationBandHeightRange: ClosedRange<CGFloat> = 48...160

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var actionCycleTimeout: TimeInterval {
        get {
            let stored = userDefaults.object(forKey: Key.actionCycleTimeout) as? Double
            let value = stored ?? Self.defaultActionCycleTimeout
            return value.clamped(to: Self.actionCycleTimeoutRange)
        }
        set {
            let clamped = newValue.clamped(to: Self.actionCycleTimeoutRange)
            userDefaults.set(clamped, forKey: Key.actionCycleTimeout)
            objectWillChange.send()
        }
    }

    var dropZoneActivationBandHeight: CGFloat {
        get {
            let stored = userDefaults.object(forKey: Key.dropZoneActivationBandHeight) as? Double
            let value = CGFloat(stored ?? Self.defaultDropZoneActivationBandHeight)
            return value.clamped(to: Self.dropZoneActivationBandHeightRange)
        }
        set {
            let clamped = newValue.clamped(to: Self.dropZoneActivationBandHeightRange)
            userDefaults.set(Double(clamped), forKey: Key.dropZoneActivationBandHeight)
            objectWillChange.send()
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
