import Foundation

nonisolated enum AppBuildEnvironment: String, CaseIterable, Sendable {
    case development
    case staging
    case production

    static var current: AppBuildEnvironment {
        #if AVEN_PRODUCTION
        return .production
        #elseif AVEN_STAGING
        return .staging
        #else
        return .development
        #endif
    }

    var supportsGoogleAuthentication: Bool {
        self == .development
    }

    var expectedFirebaseProjectID: String? {
        #if AVEN_DEVELOPMENT
        return "aven-ios-dev-4f7c2"
        #else
        return nil
        #endif
    }
}
