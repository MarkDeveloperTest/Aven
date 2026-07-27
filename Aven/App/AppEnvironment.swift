import Foundation

@MainActor
struct AppEnvironment {
    let buildEnvironment: AppBuildEnvironment
    let brand: BrandConfiguration
    let authenticationRepository: any AuthenticationRepository
    let profileRepository: any ProfileRepository

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

        return AppEnvironment(
            buildEnvironment: buildEnvironment,
            brand: .current,
            authenticationRepository: authenticationRepository,
            profileRepository: profileRepository
        )
    }
}
