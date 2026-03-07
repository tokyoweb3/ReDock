import Foundation

/// Protocol boundary for window operations.
/// Allows substituting a fake implementation in tests.
protocol WindowManaging {
    func execute(_ action: WindowAction)
}
