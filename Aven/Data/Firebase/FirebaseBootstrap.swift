import FirebaseAppCheck
import FirebaseCore
import Foundation

nonisolated enum FirebaseConfigurationStatus: Equatable, Sendable {
    case configured
    case unavailable
}

@MainActor
enum FirebaseBootstrap {
    static func configureIfAvailable(
        for buildEnvironment: AppBuildEnvironment,
        bundle: Bundle = .main
    ) -> FirebaseConfigurationStatus {
        if let app = FirebaseApp.app() {
            return validates(
                options: app.options,
                buildEnvironment: buildEnvironment,
                bundle: bundle
            ) ? .configured : .unavailable
        }

        guard
            let expectedProjectID = buildEnvironment.expectedFirebaseProjectID,
            let configurationURL = bundle.url(
                forResource: "GoogleService-Info",
                withExtension: "plist"
            ),
            let options = FirebaseOptions(contentsOfFile: configurationURL.path),
            validates(
                options: options,
                expectedProjectID: expectedProjectID,
                bundle: bundle
            )
        else {
            AppLogger.application.notice(
                "Firebase is unavailable for the selected build environment"
            )
            return .unavailable
        }

        if buildEnvironment == .production {
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        }

        FirebaseApp.configure(options: options)
        AppLogger.application.notice("Firebase configured with validated local options")
        return .configured
    }

    private static func validates(
        options: FirebaseOptions,
        buildEnvironment: AppBuildEnvironment,
        bundle: Bundle
    ) -> Bool {
        guard
            let expectedProjectID = buildEnvironment.expectedFirebaseProjectID
        else {
            return false
        }
        return validates(
            options: options,
            expectedProjectID: expectedProjectID,
            bundle: bundle
        )
    }

    private static func validates(
        options: FirebaseOptions,
        expectedProjectID: String,
        bundle: Bundle
    ) -> Bool {
        guard
            expectedProjectID.isEmpty == false,
            options.projectID == expectedProjectID,
            options.bundleID == bundle.bundleIdentifier,
            options.googleAppID.isEmpty == false
        else {
            AppLogger.application.error(
                "Firebase options do not match the selected app environment"
            )
            return false
        }
        return true
    }

}
