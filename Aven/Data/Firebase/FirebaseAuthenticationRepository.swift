import FirebaseAuth
import Foundation

actor FirebaseAuthenticationRepository: AuthenticationRepository {
    private let auth: Auth

    init(auth: Auth = .auth()) {
        self.auth = auth
    }

    func currentUser() -> AuthenticatedUser? {
        auth.currentUser.map { Self.mapUser($0) }
    }

    func authenticationStateStream() -> AsyncStream<AuthenticationState> {
        let changes = auth.authStateChanges
        return AsyncStream { continuation in
            let observation = Task {
                for await firebaseUser in changes {
                    let state = firebaseUser
                        .map { Self.mapUser($0) }
                        .map(AuthenticationState.authenticated)
                        ?? .signedOut
                    continuation.yield(state)
                }
            }
            continuation.onTermination = { @Sendable _ in
                observation.cancel()
            }
        }
    }

    func signInWithApple(
        _ payload: AppleSignInPayload
    ) async throws -> AuthenticatedUser {
        let credential = OAuthProvider.appleCredential(
            withIDToken: payload.identityToken,
            rawNonce: payload.rawNonce,
            fullName: payload.fullName
        )

        do {
            let result = try await auth.signIn(with: credential)
            return Self.mapUser(
                result.user,
                fallbackDisplayName: payload.displayName,
                fallbackEmail: payload.email
            )
        } catch {
            throw Self.mapAuthenticationError(error)
        }
    }

    func signInWithGoogle(
        _ payload: GoogleSignInPayload
    ) async throws -> AuthenticatedUser {
        let credential = GoogleAuthProvider.credential(
            withIDToken: payload.identityToken,
            accessToken: payload.accessToken
        )

        do {
            let result = try await auth.signIn(with: credential)
            return Self.mapUser(result.user)
        } catch {
            throw Self.mapAuthenticationError(error)
        }
    }

    func signInAnonymously() async throws -> AuthenticatedUser {
        do {
            let result = try await auth.signInAnonymously()
            return Self.mapUser(result.user)
        } catch {
            guard Self.isNetworkError(error) else {
                throw Self.mapAuthenticationError(error)
            }

            do {
                let result = try await auth.signInAnonymously()
                return Self.mapUser(result.user)
            } catch {
                throw Self.mapAuthenticationError(error)
            }
        }
    }

    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            throw Self.mapAuthenticationError(error)
        }
    }

    func deleteCurrentAccount() async throws {
        guard let user = auth.currentUser else {
            return
        }
        do {
            try await user.delete()
        } catch {
            throw Self.mapAuthenticationError(error)
        }
    }

    func reloadCurrentUser() async throws -> AuthenticatedUser? {
        guard let user = auth.currentUser else {
            return nil
        }
        do {
            try await user.reload()
            return auth.currentUser.map { Self.mapUser($0) }
        } catch {
            throw Self.mapAuthenticationError(error)
        }
    }

    private nonisolated static func mapUser(
        _ user: FirebaseAuth.User,
        fallbackDisplayName: String? = nil,
        fallbackEmail: String? = nil
    ) -> AuthenticatedUser {
        let displayName = user.displayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fallback = fallbackDisplayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return AuthenticatedUser(
            id: user.uid,
            displayName: nonEmpty(displayName)
                ?? nonEmpty(fallback)
                ?? "Aven Member",
            email: user.email ?? fallbackEmail
        )
    }

    private nonisolated static func nonEmpty(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }

    nonisolated static func mapAuthenticationError(
        _ error: any Error
    ) -> AppError {
        let error = error as NSError
        if isNetworkError(error) {
            return .offline
        }

        if error.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: error.code) {
            case .operationNotAllowed, .invalidAPIKey, .appNotAuthorized:
                return .authentication(.notConfigured)
            case .tooManyRequests:
                return .authentication(.providerUnavailable)
            default:
                break
            }
        }

        return .authentication(.invalidCredential)
    }

    private nonisolated static func isNetworkError(
        _ error: any Error
    ) -> Bool {
        let error = error as NSError
        if error.domain == NSURLErrorDomain {
            return true
        }
        if error.domain == AuthErrorDomain,
           error.code == AuthErrorCode.networkError.rawValue {
            return true
        }
        guard let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError else {
            return false
        }
        return underlyingError.domain == NSURLErrorDomain
    }
}
