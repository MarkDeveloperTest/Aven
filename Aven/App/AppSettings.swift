import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let language = "aven.settings.language"
        static let theme = "aven.settings.theme"
        static let aiEnabled = "aven.settings.ai.enabled"
        static let relationshipScoreEnabled = "aven.settings.relationship-score.enabled"
        static let notificationPreviewsEnabled = "aven.settings.notification-previews.enabled"
    }

    private let defaults: UserDefaults

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    var theme: AvenTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    var aiEnabled: Bool {
        didSet {
            defaults.set(aiEnabled, forKey: Key.aiEnabled)
            if aiEnabled == false, relationshipScoreEnabled {
                relationshipScoreEnabled = false
            }
        }
    }

    var relationshipScoreEnabled: Bool {
        didSet { defaults.set(relationshipScoreEnabled, forKey: Key.relationshipScoreEnabled) }
    }

    var notificationPreviewsEnabled: Bool {
        didSet { defaults.set(notificationPreviewsEnabled, forKey: Key.notificationPreviewsEnabled) }
    }

    init(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) {
        self.defaults = defaults
        language = AppLanguage(
            rawValue: defaults.string(forKey: Key.language) ?? ""
        ) ?? AppLanguage.inferred(from: locale)
        theme = AvenTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .aven
        let persistedAIEnabled = defaults.object(forKey: Key.aiEnabled) as? Bool ?? false
        aiEnabled = persistedAIEnabled
        relationshipScoreEnabled = persistedAIEnabled
            ? defaults.object(forKey: Key.relationshipScoreEnabled) as? Bool ?? false
            : false
        notificationPreviewsEnabled = defaults.object(forKey: Key.notificationPreviewsEnabled) as? Bool ?? false
    }
}
