import Foundation
import Testing
@testable import Aven

@Suite("Onboarding")
@MainActor
struct OnboardingStoreTests {
    @Test("Fresh onboarding starts at Welcome and then introduces privacy")
    func startsAtWelcome() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")

        #expect(store.step == .welcome)
        #expect(store.canGoBack == false)

        store.goForward()
        #expect(store.step == .privacy)
        #expect(store.canGoBack)

        store.goBack()
        #expect(store.step == .welcome)
    }

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

        #expect(store.step == .gender)
        #expect(store.validationError == nil)
    }

    @Test("Gender requires an explicit male or female choice")
    func validatesGender() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .gender

        store.goForward()
        #expect(store.step == .gender)
        #expect(store.validationError == .validation(.gender))

        store.gender = .female
        store.goForward()
        #expect(store.step == .countryRegion)
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
        firstStore.gender = .female

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
        #expect(store.step == .preciseLocation)

        store.goBack()
        #expect(store.step == .notifications)

        store.wantsNotifications = true
        store.goForward()
        #expect(store.step == .notificationPreviews)

        store.goForward()
        #expect(store.step == .preciseLocation)
    }

    @Test("Focused screens move backward in the expected order")
    func navigatesBackward() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .countryRegion

        store.goBack()

        #expect(store.step == .gender)
    }

    @Test("Partner pairing is part of onboarding before completion")
    func includesPairingBeforeFinish() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .aiPreference

        store.goForward()
        #expect(store.step == .pairing)

        store.goForward()
        #expect(store.step == .pairing)

        store.goForward(pairingIsComplete: true)
        #expect(store.step == .finish)

        store.goBack()
        #expect(store.step == .pairing)
    }

    @Test("Persisted finish cannot bypass required pairing")
    func restoresRequiredPairing() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: "user-a")
        store.step = .finish

        store.requirePairingBeforeFinish()

        #expect(store.step == .pairing)
        #expect(
            OnboardingStore.hasSavedProgress(
                for: "user-a",
                defaults: defaults
            )
        )
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
        #expect(secondStore.step == .welcome)
    }

    @Test("Local onboarding draft survives sign-in until completion")
    func retainsLocalDraftForFinalSignIn() {
        let defaults = isolatedDefaults()
        let store = OnboardingStore(defaults: defaults)
        store.attach(to: AppSession.localOnboardingDraftUserID)
        store.displayName = "Oksana"
        store.gender = .female
        store.step = .finish

        let restoredStore = OnboardingStore(defaults: defaults)
        restoredStore.attach(to: AppSession.localOnboardingDraftUserID)

        #expect(restoredStore.displayName == "Oksana")
        #expect(restoredStore.step == .finish)
    }

    @Test("Local draft moves to the authenticated account")
    func transfersLocalDraftToAuthenticatedUser() {
        let defaults = isolatedDefaults()
        let localStore = OnboardingStore(defaults: defaults)
        localStore.attach(to: AppSession.localOnboardingDraftUserID)
        localStore.displayName = "Oksana"
        localStore.gender = .female
        localStore.step = .relationshipType

        OnboardingStore.transferProgress(
            from: AppSession.localOnboardingDraftUserID,
            to: "user-a",
            defaults: defaults
        )

        let accountStore = OnboardingStore(defaults: defaults)
        accountStore.attach(to: "user-a")
        #expect(accountStore.displayName == "Oksana")
        #expect(accountStore.gender == .female)
        #expect(accountStore.step == .relationshipType)
        #expect(
            OnboardingStore.hasSavedProgress(
                for: AppSession.localOnboardingDraftUserID,
                defaults: defaults
            ) == false
        )
    }

    @Test("An existing account draft wins over a stale local draft")
    func preservesExistingAccountDraftDuringTransfer() {
        let defaults = isolatedDefaults()
        let localStore = OnboardingStore(defaults: defaults)
        localStore.attach(to: AppSession.localOnboardingDraftUserID)
        localStore.displayName = "Wrong account"

        let accountStore = OnboardingStore(defaults: defaults)
        accountStore.attach(to: "user-a")
        accountStore.displayName = "Alex"
        accountStore.gender = .male
        accountStore.step = .pairing

        OnboardingStore.transferProgress(
            from: AppSession.localOnboardingDraftUserID,
            to: "user-a",
            defaults: defaults
        )

        let restoredStore = OnboardingStore(defaults: defaults)
        restoredStore.attach(to: "user-a")
        #expect(restoredStore.displayName == "Alex")
        #expect(restoredStore.gender == .male)
        #expect(restoredStore.step == .pairing)
    }

    @Test("Debug reset clears only the selected user's onboarding draft")
    func clearsSelectedUserDraft() {
        let defaults = isolatedDefaults()
        let firstStore = OnboardingStore(defaults: defaults)
        firstStore.attach(to: "user-a")
        firstStore.displayName = "Oksana"
        firstStore.step = .pairing

        let secondStore = OnboardingStore(defaults: defaults)
        secondStore.attach(to: "user-b")
        secondStore.displayName = "Alex"

        OnboardingStore.clearProgress(for: "user-a", defaults: defaults)

        let restoredFirstStore = OnboardingStore(defaults: defaults)
        restoredFirstStore.attach(to: "user-a")
        let restoredSecondStore = OnboardingStore(defaults: defaults)
        restoredSecondStore.attach(to: "user-b")

        #expect(restoredFirstStore.displayName.isEmpty)
        #expect(restoredFirstStore.step == .welcome)
        #expect(restoredSecondStore.displayName == "Alex")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AvenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
