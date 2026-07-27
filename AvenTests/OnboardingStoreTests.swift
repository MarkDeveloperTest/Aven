import Foundation
import Testing
@testable import Aven

@Suite("Onboarding")
@MainActor
struct OnboardingStoreTests {
    @Test("Profile validation requires a meaningful name")
    func validatesDisplayName() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.displayName = " "
        store.step = .displayName

        store.goForward()

        #expect(store.step == .displayName)
        #expect(store.validationError == .validation(.displayName))
    }

    @Test("Birth date accepts users of any age")
    func acceptsAnyAge() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .birthDate
        store.dateOfBirth = .now

        store.goForward()

        #expect(store.step == .countryRegion)
        #expect(store.validationError == nil)
    }

    @Test("Legacy unspecified relationship drafts migrate to dating")
    func migratesUnspecifiedRelationshipType() {
        let defaults = isolatedDefaults()
        defaults.set(
            RelationshipType.unspecified.rawValue,
            forKey: "aven.onboarding.user-a.relationship-type"
        )

        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")

        #expect(store.relationshipType == .dating)
    }

    @Test("Onboarding progress resumes from persisted state")
    func resumesProgress() {
        let defaults = isolatedDefaults()
        let firstStore = OnboardingStore(defaults: defaults)
        firstStore.attach(to: "user-a")
        firstStore.step = .relationshipType
        firstStore.displayName = "Oksana"

        let restoredStore = OnboardingStore(defaults: defaults)
        restoredStore.attach(to: "user-a")

        #expect(restoredStore.step == .relationshipType)
        #expect(restoredStore.displayName == "Oksana")
        #expect(
            defaults.string(forKey: "aven.onboarding.user-a.step")
                == OnboardingStore.Step.relationshipType.rawValue
        )
    }

    @Test("Legacy numeric chapters migrate to focused screens")
    func migratesLegacyProgress() {
        let defaults = isolatedDefaults()
        defaults.set(2, forKey: "aven.onboarding.user-a.step")

        let profileStore = OnboardingStore(defaults: defaults)
        profileStore.attach(to: "user-a")

        #expect(profileStore.step == .displayName)
        #expect(
            defaults.string(forKey: "aven.onboarding.user-a.step")
                == OnboardingStore.Step.displayName.rawValue
        )
    }

    @Test("Notification preview screen is conditional")
    func skipsNotificationPreviewsWhenDisabled() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .notifications
        store.wantsNotifications = false

        store.goForward()
        #expect(store.step == .aiPreference)

        store.goBack()
        #expect(store.step == .notifications)

        store.wantsNotifications = true
        store.goForward()
        #expect(store.step == .notificationPreviews)
    }

    @Test("Focused screens move backward in the expected order")
    func navigatesBackward() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .countryRegion

        store.goBack()

        #expect(store.step == .birthDate)
    }

    @Test("Drafts are isolated between authenticated users")
    func isolatesDraftsByUser() {
        let defaults = isolatedDefaults()
        let firstStore = OnboardingStore(defaults: defaults)
        firstStore.attach(to: "user-a")
        firstStore.displayName = "Oksana"
        firstStore.step = .relationshipType

        let secondStore = OnboardingStore(defaults: defaults)
        secondStore.attach(to: "user-b")

        #expect(secondStore.displayName.isEmpty)
        #expect(secondStore.step == .privacy)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AvenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
