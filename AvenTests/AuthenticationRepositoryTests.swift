import Testing
@testable import Aven

@Suite("Authentication configuration")
struct AuthenticationRepositoryTests {
    @Test("Google sign-in is exposed only in configured development builds")
    func googleEnvironmentAvailability() {
        #expect(AppBuildEnvironment.development.supportsGoogleAuthentication)
        #expect(!AppBuildEnvironment.staging.supportsGoogleAuthentication)
        #expect(!AppBuildEnvironment.production.supportsGoogleAuthentication)
    }
}
