import Foundation
import Observation

@MainActor
@Observable
final class OnboardingStore {
    nonisolated enum Step: String, CaseIterable, Sendable {
        case privacy
        case displayName = "display-name"
        case birthDate = "birth-date"
        case countryRegion = "country-region"
        case relationshipType = "relationship-type"
        case relationshipStartDate = "relationship-start-date"
        case notifications
        case notificationPreviews = "notification-previews"
        case aiPreference = "ai-preference"
        case finish

        nonisolated static func migratedLegacyOrdinal(_ ordinal: Int) -> Step {
            switch ordinal {
            case 0, 1: .privacy
            case 2: .displayName
            case 3: .relationshipType
            case 4: .notifications
            case 5: .finish
            default: .privacy
            }
        }
    }

    private enum Key {
        static let step = "step"
        static let displayName = "display-name"
        static let dateOfBirth = "date-of-birth"
        static let countryCode = "country-code"
        static let relationshipType = "relationship-type"
        static let relationshipStartDate = "relationship-start-date"
        static let wantsNotifications = "wants-notifications"

        static let all = [
            step,
            displayName,
            dateOfBirth,
            countryCode,
            relationshipType,
            relationshipStartDate,
            wantsNotifications,
        ]
    }

    private let defaults: UserDefaults
    private var ownerUserID: String?

    var step: Step {
        didSet { persist(step.rawValue, for: Key.step) }
    }
    var displayName: String {
        didSet { persist(displayName, for: Key.displayName) }
    }
    var dateOfBirth: Date {
        didSet { persist(dateOfBirth.timeIntervalSince1970, for: Key.dateOfBirth) }
    }
    var countryCode: String {
        didSet { persist(countryCode, for: Key.countryCode) }
    }
    var relationshipType: RelationshipType {
        didSet { persist(relationshipType.rawValue, for: Key.relationshipType) }
    }
    var relationshipStartDate: Date? {
        didSet {
            guard let storageKey = storageKey(for: Key.relationshipStartDate) else { return }
            if let relationshipStartDate {
                defaults.set(relationshipStartDate.timeIntervalSince1970, forKey: storageKey)
            } else {
                defaults.removeObject(forKey: storageKey)
            }
        }
    }
    var wantsNotifications: Bool {
        didSet { persist(wantsNotifications, for: Key.wantsNotifications) }
    }
    var validationError: AppError?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        step = .privacy
        displayName = ""
        dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
        countryCode = Locale.current.region?.identifier ?? "GB"
        relationshipType = .dating
        relationshipStartDate = nil
        wantsNotifications = false
    }

    var canGoBack: Bool {
        step != .privacy
    }

    func attach(to userID: String) {
        guard ownerUserID != userID else { return }
        ownerUserID = userID

        step = restoredStep()
        displayName = defaults.string(forKey: requiredStorageKey(for: Key.displayName)) ?? ""
        if let timestamp = defaults.object(
            forKey: requiredStorageKey(for: Key.dateOfBirth)
        ) as? TimeInterval {
            dateOfBirth = Date(timeIntervalSince1970: timestamp)
        } else {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
        }
        countryCode = defaults.string(
            forKey: requiredStorageKey(for: Key.countryCode)
        ) ?? countryCode
        relationshipType = RelationshipType(
            rawValue: defaults.string(forKey: requiredStorageKey(for: Key.relationshipType)) ?? ""
        ) ?? .dating
        if relationshipType == .unspecified {
            relationshipType = .dating
        }
        if let timestamp = defaults.object(
            forKey: requiredStorageKey(for: Key.relationshipStartDate)
        ) as? TimeInterval {
            relationshipStartDate = Date(timeIntervalSince1970: timestamp)
        } else {
            relationshipStartDate = nil
        }
        wantsNotifications = defaults.object(
            forKey: requiredStorageKey(for: Key.wantsNotifications)
        ) as? Bool ?? false

        if step == .notificationPreviews, wantsNotifications == false {
            step = .aiPreference
        }
    }

    func goBack() {
        validationError = nil
        switch step {
        case .privacy:
            return
        case .displayName:
            step = .privacy
        case .birthDate:
            step = .displayName
        case .countryRegion:
            step = .birthDate
        case .relationshipType:
            step = .countryRegion
        case .relationshipStartDate:
            step = .relationshipType
        case .notifications:
            step = .relationshipStartDate
        case .notificationPreviews:
            step = .notifications
        case .aiPreference:
            step = wantsNotifications ? .notificationPreviews : .notifications
        case .finish:
            step = .aiPreference
        }
    }

    func goForward() {
        validationError = nil

        switch step {
        case .privacy:
            step = .displayName
        case .displayName:
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.count >= 2 else {
                validationError = .validation(.displayName)
                return
            }
            displayName = trimmedName
            step = .birthDate
        case .birthDate:
            step = .countryRegion
        case .countryRegion:
            step = .relationshipType
        case .relationshipType:
            step = .relationshipStartDate
        case .relationshipStartDate:
            step = .notifications
        case .notifications:
            step = wantsNotifications ? .notificationPreviews : .aiPreference
        case .notificationPreviews:
            step = .aiPreference
        case .aiPreference:
            step = .finish
        case .finish:
            return
        }
    }

    func makeProfile(userID: String) throws -> UserProfile {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= 2 else {
            throw AppError.validation(.displayName)
        }
        return UserProfile(
            userID: userID,
            displayName: trimmedName,
            dateOfBirth: dateOfBirth,
            countryCode: countryCode,
            timeZoneIdentifier: TimeZone.current.identifier,
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate
        )
    }

    func resetProgress() {
        guard ownerUserID != nil else { return }
        for key in Key.all {
            defaults.removeObject(forKey: requiredStorageKey(for: key))
        }
        ownerUserID = nil
    }

    private func restoredStep() -> Step {
        let stored = defaults.object(forKey: requiredStorageKey(for: Key.step))
        if let identifier = stored as? String, let step = Step(rawValue: identifier) {
            return step
        }
        if let ordinal = stored as? Int {
            return Step.migratedLegacyOrdinal(ordinal)
        }
        return .privacy
    }

    private func persist(_ value: Any, for key: String) {
        guard let storageKey = storageKey(for: key) else { return }
        defaults.set(value, forKey: storageKey)
    }

    private func storageKey(for key: String) -> String? {
        ownerUserID.map { "aven.onboarding.\($0).\(key)" }
    }

    private func requiredStorageKey(for key: String) -> String {
        precondition(ownerUserID != nil, "OnboardingStore must be attached before persistence")
        return storageKey(for: key) ?? key
    }
}
