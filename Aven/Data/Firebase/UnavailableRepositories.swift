import Foundation

actor UnavailableAuthenticationRepository: AuthenticationRepository {
    func currentUser() -> AuthenticatedUser? {
        nil
    }

    func authenticationStateStream() -> AsyncStream<AuthenticationState> {
        AsyncStream { continuation in
            continuation.yield(.signedOut)
            continuation.finish()
        }
    }

    func signInWithApple(
        _ payload: AppleSignInPayload
    ) throws -> AuthenticatedUser {
        _ = payload
        throw AppError.authentication(.notConfigured)
    }

    func signInWithGoogle(
        _ payload: GoogleSignInPayload
    ) throws -> AuthenticatedUser {
        _ = payload
        throw AppError.authentication(.notConfigured)
    }

    func signOut() throws {
        throw AppError.authentication(.notConfigured)
    }

    func deleteCurrentAccount() throws {
        throw AppError.authentication(.notConfigured)
    }

    func reloadCurrentUser() throws -> AuthenticatedUser? {
        throw AppError.authentication(.notConfigured)
    }
}

actor UnavailableProfileRepository: ProfileRepository {
    func loadProfile(for userID: String) -> UserProfile? {
        _ = userID
        return nil
    }

    func saveProfile(_ profile: UserProfile) throws {
        _ = profile
        throw AppError.externalConfigurationRequired
    }

    func deleteProfile(for userID: String) throws {
        _ = userID
        throw AppError.externalConfigurationRequired
    }
}
