import Foundation

protocol AuthenticationRepository: Sendable {
    func currentUser() async -> AuthenticatedUser?
    func authenticationStateStream() async -> AsyncStream<AuthenticationState>
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AuthenticatedUser
    func signInWithGoogle(_ payload: GoogleSignInPayload) async throws -> AuthenticatedUser
    func signInAnonymously() async throws -> AuthenticatedUser
    func signOut() async throws
    func deleteCurrentAccount() async throws
    func reloadCurrentUser() async throws -> AuthenticatedUser?
}
