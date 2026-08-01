import Foundation
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

    @Test("Firebase network failures are shown as offline")
    func firebaseNetworkFailureMapping() {
        let error = NSError(domain: "FIRAuthErrorDomain", code: 17_020)

        #expect(FirebaseAuthenticationRepository.mapAuthenticationError(error) == .offline)
    }

    @Test("Firebase project configuration failures are actionable")
    func firebaseConfigurationFailureMapping() {
        let error = NSError(domain: "FIRAuthErrorDomain", code: 17_028)

        #expect(
            FirebaseAuthenticationRepository.mapAuthenticationError(error)
                == .authentication(.notConfigured)
        )
    }
}
