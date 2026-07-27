import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
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

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() async {
        guard phase == .launching else { return }

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") {
            user = AuthenticatedUser(
                id: "ui-test-onboarding-user",
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
            phase = .signedOut
            return
        }

        user = currentUser
        profile = await environment.profileRepository.loadProfile(for: currentUser.id)
        phase = profile == nil ? .onboarding : .authenticated
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

    func completeOnboarding(with profile: UserProfile) async {
        guard isWorking == false else { return }
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

    func signOut() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await environment.authenticationRepository.signOut()
            user = nil
            profile = nil
            phase = .signedOut
        } catch {
            AppLogger.authentication.error("Sign out failed")
            presentedError = .unknown
        }
    }

    func deleteAccount() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if let user {
                try await environment.profileRepository.deleteProfile(for: user.id)
            }
            try await environment.authenticationRepository.deleteCurrentAccount()
            self.user = nil
            profile = nil
            phase = .signedOut
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

    private func performAuthentication(
        _ operation: () async throws -> AuthenticatedUser
    ) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let authenticatedUser = try await operation()
            user = authenticatedUser
            profile = await environment.profileRepository.loadProfile(for: authenticatedUser.id)
            phase = profile == nil ? .onboarding : .authenticated
        } catch let appError as AppError {
            presentedError = appError
        } catch let authError as AuthenticationError {
            presentedError = .authentication(authError)
        } catch {
            AppLogger.authentication.error("Authentication operation failed")
            presentedError = .unknown
        }
    }
}
