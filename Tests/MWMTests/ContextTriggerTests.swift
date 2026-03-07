import CoreGraphics
import Foundation
import Testing
@testable import MWM

@Suite("ContextTrigger evaluation")
struct ContextTriggerTests {
    let mainDisplay = DisplayFingerprint(
        displayID: 1,
        localizedName: "Built-in Retina Display",
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )

    let externalDisplay = DisplayFingerprint(
        displayID: 2,
        localizedName: "LG UltraFine",
        bounds: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    )

    // MARK: - Display trigger

    @Test("Display trigger matches when fingerprints match")
    func displayTriggerMatch() {
        let trigger = ContextTrigger.displayConfiguration(fingerprints: [mainDisplay])
        let context = EnvironmentContext(displayFingerprints: [mainDisplay], wifiSSID: nil)
        #expect(trigger.matches(context))
    }

    @Test("Display trigger does not match with different count")
    func displayTriggerCountMismatch() {
        let trigger = ContextTrigger.displayConfiguration(fingerprints: [mainDisplay, externalDisplay])
        let context = EnvironmentContext(displayFingerprints: [mainDisplay], wifiSSID: nil)
        #expect(!trigger.matches(context))
    }

    @Test("Display trigger does not match with different display")
    func displayTriggerDifferentDisplay() {
        let trigger = ContextTrigger.displayConfiguration(fingerprints: [externalDisplay])
        let context = EnvironmentContext(displayFingerprints: [mainDisplay], wifiSSID: nil)
        #expect(!trigger.matches(context))
    }

    // MARK: - Wi-Fi trigger

    @Test("Wi-Fi trigger matches correct SSID")
    func wifiMatch() {
        let trigger = ContextTrigger.wifiSSID(ssid: "HomeNetwork")
        let context = EnvironmentContext(displayFingerprints: [], wifiSSID: "HomeNetwork")
        #expect(trigger.matches(context))
    }

    @Test("Wi-Fi trigger does not match different SSID")
    func wifiMismatch() {
        let trigger = ContextTrigger.wifiSSID(ssid: "HomeNetwork")
        let context = EnvironmentContext(displayFingerprints: [], wifiSSID: "OfficeNetwork")
        #expect(!trigger.matches(context))
    }

    @Test("Wi-Fi trigger does not match when Wi-Fi is off")
    func wifiOff() {
        let trigger = ContextTrigger.wifiSSID(ssid: "HomeNetwork")
        let context = EnvironmentContext(displayFingerprints: [], wifiSSID: nil)
        #expect(!trigger.matches(context))
    }

    // MARK: - Compound trigger

    @Test("Compound trigger matches when all conditions met")
    func compoundMatch() {
        let trigger = ContextTrigger.compound(conditions: [
            .displayConfiguration(fingerprints: [mainDisplay]),
            .wifiSSID(ssid: "Office"),
        ])
        let context = EnvironmentContext(displayFingerprints: [mainDisplay], wifiSSID: "Office")
        #expect(trigger.matches(context))
    }

    @Test("Compound trigger fails when one condition not met")
    func compoundPartialMatch() {
        let trigger = ContextTrigger.compound(conditions: [
            .displayConfiguration(fingerprints: [mainDisplay]),
            .wifiSSID(ssid: "Office"),
        ])
        let context = EnvironmentContext(displayFingerprints: [mainDisplay], wifiSSID: "Home")
        #expect(!trigger.matches(context))
    }

    @Test("Empty compound trigger always matches")
    func compoundEmpty() {
        let trigger = ContextTrigger.compound(conditions: [])
        let context = EnvironmentContext(displayFingerprints: [], wifiSSID: nil)
        #expect(trigger.matches(context))
    }

    // MARK: - Display description

    @Test("Display description for display trigger")
    func displayDescription() {
        let trigger = ContextTrigger.displayConfiguration(fingerprints: [mainDisplay, externalDisplay])
        #expect(trigger.displayDescription == "Built-in Retina Display + LG UltraFine")
    }

    @Test("Display description for Wi-Fi trigger")
    func wifiDescription() {
        let trigger = ContextTrigger.wifiSSID(ssid: "MyNetwork")
        #expect(trigger.displayDescription == "Wi-Fi: MyNetwork")
    }

    @Test("Display description for compound trigger")
    func compoundDescription() {
        let trigger = ContextTrigger.compound(conditions: [
            .wifiSSID(ssid: "Office"),
            .displayConfiguration(fingerprints: [mainDisplay]),
        ])
        #expect(trigger.displayDescription.contains("AND"))
    }

    // MARK: - Codable

    @Test("ContextTrigger encodes and decodes all variants")
    func codableRoundTrip() throws {
        let triggers: [ContextTrigger] = [
            .displayConfiguration(fingerprints: [mainDisplay]),
            .wifiSSID(ssid: "Test"),
            .compound(conditions: [
                .wifiSSID(ssid: "Net"),
                .displayConfiguration(fingerprints: [externalDisplay]),
            ]),
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in triggers {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ContextTrigger.self, from: data)
            #expect(decoded == original)
        }
    }
}
