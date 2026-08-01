import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    static let localOnboardingDraftUserID = "local-onboarding-draft"
    #if DEBUG
    static let simulatorUserID = "simulator-local-user"
    #endif

    nonisolated enum Phase: Equatable, Sendable {
        case launching
        case signedOut
        case onboarding
        case authenticated
    }

    private let environment: AppEnvironment

    var phase: Phase = .launching
    var user: AuthenticatedUser?
    var profile: UserProfile?
    var presentedError: AppError?
    var isWorking = false

    /// Before sign-in, onboarding is stored in a local draft. After sign-in the
    /// draft is moved to that account so another account can never inherit it.
    var onboardingDraftUserID: String {
        user?.id ?? Self.localOnboardingDraftUserID
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() async {
        guard phase == .launching else { return }

        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-sign-in") {
            OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            OnboardingStore.clearProgress(for: Self.simulatorUserID)
            user = nil
            profile = nil
            phase = .onboarding
            return
        }
        #endif

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") {
            let fixtureUserID = "ui-test-onboarding-user"
            OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            OnboardingStore.clearProgress(for: fixtureUserID)
            user = AuthenticatedUser(
                id: fixtureUserID,
                displayName: "Oksana",
                email: nil
            )
            profile = nil
            phase = .onboarding
            return
        }

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            let fixtureUser = AuthenticatedUser(
                id: "ui-test-user",
                displayName: "Alex",
                email: nil
            )
            let fixtureProfile = UserProfile(
                userID: fixtureUser.id,
                displayName: fixtureUser.displayName,
                dateOfBirth: Date(timeIntervalSince1970: 631_152_000),
                countryCode: "GB",
                timeZoneIdentifier: "Europe/London",
                relationshipType: .longDistance,
                relationshipStartDate: Calendar.current.date(
                    byAdding: .month,
                    value: -18,
                    to: .now
                )
            )
            user = fixtureUser
            profile = fixtureProfile
            phase = .authenticated
            return
        }

        guard let currentUser = await environment.authenticationRepository.currentUser() else {
            phase = .onboarding
            return
        }

        user = currentUser
        profile = await environment.profileRepository.loadProfile(for: currentUser.id)
        migrateLegacyLocalDraftIfNeeded(to: currentUser.id)
        phase = shouldContinueOnboarding(profile: profile, userID: currentUser.id)
            ? .onboarding
            : .authenticated
    }

    func signInWithApple(_ payload: AppleSignInPayload) async {
        await performAuthentication {
            try await environment.authenticationRepository.signInWithApple(payload)
        }
    }

    func signInWithGoogle(_ payload: GoogleSignInPayload) async {
        await performAuthentication {
            try await environment.authenticationRepository.signInWithGoogle(payload)
        }
    }

    func continueAsGuest() async {
        #if DEBUG && targetEnvironment(simulator)
        guard isWorking == false else { return }
        presentedError = nil
        OnboardingStore.transferProgress(
            from: Self.localOnboardingDraftUserID,
            to: Self.simulatorUserID
        )
        user = AuthenticatedUser(
            id: Self.simulatorUserID,
            displayName: "Simulator Guest",
            email: nil
        )
        profile = nil
        phase = .onboarding
        return
        #else
        await performAuthentication {
            try await environment.authenticationRepository.signInAnonymously()
        }
        #endif
    }

    func completeOnboarding(with profile: UserProfile) async {
        guard isWorking == false else { return }

        #if DEBUG && targetEnvironment(simulator)
        if usesLocalUITestProfilePersistence {
            self.profile = profile
            phase = .authenticated
            return
        }
        #endif

        isWorking = true
        defer { isWorking = false }
        do {
            try await environment.profileRepository.saveProfile(profile)
            self.profile = profile
            phase = .authenticated
        } catch let appError as AppError {
            presentedError = appError
        } catch {
            AppLogger.persistence.error("Profile save failed")
            presentedError = .unknown
        }
    }

    func prepareProfileForPairing(_ profile: UserProfile) async throws {
        guard
            phase == .onboarding,
            user?.id == profile.userID,
            self.profile == nil
        else {
            return
        }
        guard isWorking == false else {
            throw AppError.unknown
        }

        #if DEBUG && targetEnvironment(simulator)
        if usesLocalUITestProfilePersistence {
            self.profile = profile
            return
        }
        #endif

        isWorking = true
        defer { isWorking = false }
        do {
            try await environment.profileRepository.saveProfile(profile)
            self.profile = profile
        } catch let appError as AppError {
            throw appError
        } catch {
            AppLogger.persistence.error("Pairing profile preparation failed")
            throw AppError.unknown
        }
    }

    func signOut() async {
        guard isWorking == false else { return }
        let signedOutUserID = user?.id

        #if DEBUG && targetEnvironment(simulator)
        if user?.id == Self.simulatorUserID {
            resetLocalSession()
            return
        }
        #endif

        isWorking = true
        defer { isWorking = false }
        do {
            try await environment.authenticationRepository.signOut()
            OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            if let signedOutUserID {
                OnboardingStore.clearProgress(for: signedOutUserID)
            }
            user = nil
            profile = nil
            phase = .onboarding
        } catch {
            AppLogger.authentication.error("Sign out failed")
            presentedError = .unknown
        }
    }

    func deleteAccount() async {
        guard isWorking == false else { return }
        let deletedUserID = user?.id

        #if DEBUG && targetEnvironment(simulator)
        if user?.id == Self.simulatorUserID {
            resetLocalSession()
            return
        }
        #endif

        isWorking = true
        defer { isWorking = false }
        do {
            if let user {
                try await environment.profileRepository.deleteProfile(for: user.id)
            }
            try await environment.authenticationRepository.deleteCurrentAccount()
            OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            if let deletedUserID {
                OnboardingStore.clearProgress(for: deletedUserID)
            }
            self.user = nil
            profile = nil
            phase = .onboarding
        } catch {
            AppLogger.authentication.error("Account deletion failed")
            presentedError = .unknown
        }
    }

    func dismissError() {
        presentedError = nil
    }

    func present(_ error: AppError) {
        presentedError = error
    }

    #if DEBUG
    func debugRestartOnboarding() async {
        let userID = user?.id
        OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
        if let userID {
            OnboardingStore.clearProgress(for: userID)
        }
        profile = nil
        presentedError = nil
        do {
            try await environment.authenticationRepository.signOut()
            user = nil
        } catch {
            AppLogger.authentication.error("Debug onboarding reset could not sign out")
        }
        phase = .onboarding
    }
    #endif

    private func performAuthentication(
        _ operation: () async throws -> AuthenticatedUser
    ) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let authenticatedUser = try await operation()
            let loadedProfile = await environment.profileRepository.loadProfile(
                for: authenticatedUser.id
            )
            if loadedProfile == nil {
                OnboardingStore.transferProgress(
                    from: Self.localOnboardingDraftUserID,
                    to: authenticatedUser.id
                )
            } else {
                OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            }
            user = authenticatedUser
            profile = loadedProfile
            phase = shouldContinueOnboarding(
                profile: loadedProfile,
                userID: authenticatedUser.id
            )
                ? .onboarding
                : .authenticated
        } catch let appError as AppError {
            presentedError = appError
        } catch let authError as AuthenticationError {
            presentedError = .authentication(authError)
        } catch {
            AppLogger.authentication.error("Authentication operation failed")
            presentedError = .unknown
        }
    }

    private func shouldContinueOnboarding(
        profile: UserProfile?,
        userID: String
    ) -> Bool {
        profile == nil || OnboardingStore.hasSavedProgress(for: userID)
    }

    private func migrateLegacyLocalDraftIfNeeded(to userID: String) {
        guard OnboardingStore.hasSavedProgress(for: userID) == false else {
            OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
            return
        }
        OnboardingStore.transferProgress(
            from: Self.localOnboardingDraftUserID,
            to: userID
        )
    }

    private func resetLocalSession() {
        OnboardingStore.clearProgress(for: Self.localOnboardingDraftUserID)
        if let userID = user?.id {
            OnboardingStore.clearProgress(for: userID)
        }
        user = nil
        profile = nil
        phase = .onboarding
    }

    #if DEBUG && targetEnvironment(simulator)
    private var usesLocalUITestProfilePersistence: Bool {
        guard let userID = user?.id else { return false }
        return userID == Self.simulatorUserID
            || userID == "ui-test-onboarding-user"
    }
    #endif
}
