import Foundation
import Observation

@MainActor
@Observable
final class OnboardingStore {
    nonisolated enum Step: String, CaseIterable, Sendable {
        case privacy
        case displayName = "display-name"
        case birthDate = "birth-date"
        case gender
        case countryRegion = "country-region"
        case relationshipType = "relationship-type"
        case relationshipStartDate = "relationship-start-date"
        case notifications
        case notificationPreviews = "notification-previews"
        case preciseLocation = "precise-location"
        case aiPreference = "ai-preference"
        case pairing
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
        static let gender = "gender"
        static let countryCode = "country-code"
        static let relationshipType = "relationship-type"
        static let relationshipStartDate = "relationship-start-date"
        static let wantsNotifications = "wants-notifications"
        static let wantsPreciseLocation = "wants-precise-location"

        static let all = [
            step,
            displayName,
            dateOfBirth,
            gender,
            countryCode,
            relationshipType,
            relationshipStartDate,
            wantsNotifications,
            wantsPreciseLocation,
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
    var gender: Gender? {
        didSet {
            guard let storageKey = storageKey(for: Key.gender) else { return }
            if let gender {
                defaults.set(gender.rawValue, forKey: storageKey)
            } else {
                defaults.removeObject(forKey: storageKey)
            }
        }
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
    var wantsPreciseLocation: Bool {
        didSet { persist(wantsPreciseLocation, for: Key.wantsPreciseLocation) }
    }
    var validationError: AppError?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        step = .privacy
        displayName = ""
        dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
        gender = nil
        countryCode = Locale.current.region?.identifier ?? "GB"
        relationshipType = .dating
        relationshipStartDate = .now
        wantsNotifications = false
        wantsPreciseLocation = false
    }

    var canGoBack: Bool {
        step != .privacy
    }

    static func hasSavedProgress(
        for userID: String,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(
            forKey: "aven.onboarding.\(userID).\(Key.step)"
        ) != nil
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
        gender = defaults.string(
            forKey: requiredStorageKey(for: Key.gender)
        ).flatMap(Gender.init(rawValue:))
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
            relationshipStartDate = .now
        }
        wantsNotifications = defaults.object(
            forKey: requiredStorageKey(for: Key.wantsNotifications)
        ) as? Bool ?? false
        wantsPreciseLocation = defaults.object(
            forKey: requiredStorageKey(for: Key.wantsPreciseLocation)
        ) as? Bool ?? false

        if step == .notificationPreviews, wantsNotifications == false {
            step = .preciseLocation
        }
        if gender == nil,
           let currentIndex = Step.allCases.firstIndex(of: step),
           let genderIndex = Step.allCases.firstIndex(of: .gender),
           currentIndex > genderIndex {
            step = .gender
        }
        if relationshipStartDate == nil,
           let currentIndex = Step.allCases.firstIndex(of: step),
           let relationshipDateIndex = Step.allCases.firstIndex(of: .relationshipStartDate),
           currentIndex > relationshipDateIndex {
            step = .relationshipStartDate
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
        case .gender:
            step = .birthDate
        case .countryRegion:
            step = .gender
        case .relationshipType:
            step = .countryRegion
        case .relationshipStartDate:
            step = .relationshipType
        case .notifications:
            step = .relationshipStartDate
        case .notificationPreviews:
            step = .notifications
        case .preciseLocation:
            step = wantsNotifications ? .notificationPreviews : .notifications
        case .aiPreference:
            step = .preciseLocation
        case .pairing:
            step = .aiPreference
        case .finish:
            step = .pairing
        }
    }

    func goForward(pairingIsComplete: Bool = false) {
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
            step = .gender
        case .gender:
            guard gender != nil else {
                validationError = .validation(.gender)
                return
            }
            step = .countryRegion
        case .countryRegion:
            step = .relationshipType
        case .relationshipType:
            step = .relationshipStartDate
        case .relationshipStartDate:
            guard relationshipStartDate != nil else {
                validationError = .validation(.relationshipStartDate)
                return
            }
            step = .notifications
        case .notifications:
            step = wantsNotifications ? .notificationPreviews : .preciseLocation
        case .notificationPreviews:
            step = .preciseLocation
        case .preciseLocation:
            step = .aiPreference
        case .aiPreference:
            step = .pairing
        case .pairing:
            guard pairingIsComplete else { return }
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
        guard let gender else {
            throw AppError.validation(.gender)
        }
        guard let relationshipStartDate else {
            throw AppError.validation(.relationshipStartDate)
        }
        return UserProfile(
            userID: userID,
            displayName: trimmedName,
            dateOfBirth: dateOfBirth,
            countryCode: countryCode,
            timeZoneIdentifier: TimeZone.current.identifier,
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate,
            gender: gender
        )
    }

    func resetProgress() {
        guard let ownerUserID else { return }
        Self.clearProgress(for: ownerUserID, defaults: defaults)
        self.ownerUserID = nil
    }

    func requirePairingBeforeFinish() {
        guard step == .finish else { return }
        step = .pairing
    }

    static func clearProgress(
        for userID: String,
        defaults: UserDefaults = .standard
    ) {
        for key in Key.all {
            defaults.removeObject(
                forKey: "aven.onboarding.\(userID).\(key)"
            )
        }
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
