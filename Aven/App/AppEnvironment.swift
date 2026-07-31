import Foundation

@MainActor
struct AppEnvironment {
    let buildEnvironment: AppBuildEnvironment
    let brand: BrandConfiguration
    let authenticationRepository: any AuthenticationRepository
    let profileRepository: any ProfileRepository
    let relationshipRepository: any RelationshipRepository
    let pairingIntentVault: any PairingIntentVault

    static func live() -> AppEnvironment {
        let buildEnvironment = AppBuildEnvironment.current
        let firebaseStatus = FirebaseBootstrap.configureIfAvailable(
            for: buildEnvironment
        )
        let authenticationRepository: any AuthenticationRepository =
            firebaseStatus == .configured
                ? FirebaseAuthenticationRepository()
                : UnavailableAuthenticationRepository()
        let profileRepository: any ProfileRepository =
            firebaseStatus == .configured
                ? FirebaseProfileRepository()
                : UnavailableProfileRepository()
        let relationshipRepository: any RelationshipRepository =
            firebaseStatus == .configured
                ? FirebaseRelationshipRepository()
                : UnavailableRelationshipRepository()

        return AppEnvironment(
            buildEnvironment: buildEnvironment,
            brand: .current,
            authenticationRepository: authenticationRepository,
            profileRepository: profileRepository,
            relationshipRepository: relationshipRepository,
            pairingIntentVault: KeychainPairingIntentVault()
        )
    }
}
