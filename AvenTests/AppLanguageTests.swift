import Foundation
import Testing
@testable import Aven

@Suite("Region language")
@MainActor
struct AppLanguageTests {
    @Test("Ukraine uses Ukrainian")
    func ukrainianRegion() {
        #expect(AppLanguage.inferred(fromRegionCode: "UA") == .ukrainian)
        #expect(AppLanguage.inferred(fromRegionCode: "ua") == .ukrainian)
    }

    @Test("Other regions use English")
    func otherRegions() {
        #expect(AppLanguage.inferred(fromRegionCode: "GB") == .english)
        #expect(AppLanguage.inferred(fromRegionCode: "US") == .english)
        #expect(AppLanguage.inferred(fromRegionCode: nil) == .english)
    }

    @Test("First launch settings use the device region")
    func settingsUseRegion() {
        let suiteName = "AvenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(
            defaults: defaults,
            locale: Locale(identifier: "uk_UA")
        )

        #expect(settings.language == .ukrainian)
    }
}
