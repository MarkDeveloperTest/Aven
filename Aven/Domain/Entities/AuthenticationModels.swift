import Foundation

nonisolated struct AuthenticatedUser: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String
    var email: String?
}

nonisolated enum AuthenticationState: Equatable, Sendable {
    case signedOut
    case authenticated(AuthenticatedUser)
}

nonisolated struct AppleSignInPayload: Sendable {
    let identityToken: String
    let authorizationCode: String?
    let rawNonce: String
    let displayName: String?
    let fullName: PersonNameComponents?
    let email: String?
    let appleUserIdentifier: String
}

nonisolated struct GoogleSignInPayload: Sendable {
    let identityToken: String
    let accessToken: String
}
