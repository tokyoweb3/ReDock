import Foundation
import Testing
@testable import ReDock

@Suite("App settings")
struct AppSettingsTests {
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ReDockTests.\(name)")!
        defaults.removePersistentDomain(forName: "ReDockTests.\(name)")
        return defaults
    }

    @Test("Cycle timeout defaults to one second")
    func cycleTimeoutDefault() {
        let settings = AppSettings(userDefaults: makeDefaults())
        #expect(settings.actionCycleTimeout == 1.0)
    }

    @Test("Cycle timeout persists user changes")
    func cycleTimeoutPersists() {
        let defaults = makeDefaults()
        let settings = AppSettings(userDefaults: defaults)
        settings.actionCycleTimeout = 1.4

        let reloaded = AppSettings(userDefaults: defaults)
        #expect(reloaded.actionCycleTimeout == 1.4)
    }

    @Test("Cycle timeout clamps to supported range")
    func cycleTimeoutClamps() {
        let settings = AppSettings(userDefaults: makeDefaults())
        settings.actionCycleTimeout = 12.0
        #expect(settings.actionCycleTimeout == 10.0)
    }
}
