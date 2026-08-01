import SwiftUI

nonisolated struct BrandConfiguration: Sendable {
    let displayName: String
    let legalName: String
    let supportEmail: String
    let privacyURL: URL
    let termsURL: URL
    let appStoreURL: URL
    let websiteURL: URL
    let analyticsNamespace: String
    let firebaseEnvironmentName: String
    let deepLinkHost: String
    let defaultAccent: Color

    static let current = BrandConfiguration(
        displayName: "Aven",
        legalName: "LEGAL_PRODUCT_NAME",
        supportEmail: "support@example.com",
        privacyURL: placeholderURL("https://example.com/privacy"),
        termsURL: placeholderURL("https://example.com/terms"),
        appStoreURL: placeholderURL("https://apps.apple.com/app/id0000000000"),
        websiteURL: placeholderURL("https://example.com"),
        analyticsNamespace: "aven",
        firebaseEnvironmentName: AppBuildEnvironment.current.rawValue,
        deepLinkHost: AppBuildEnvironment.current.pairingLinkHost ?? "",
        defaultAccent: Color(red: 0.91, green: 0.30, blue: 0.48)
    )

    private static func placeholderURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("Invalid compile-time brand URL placeholder")
        }
        return url
    }
}
