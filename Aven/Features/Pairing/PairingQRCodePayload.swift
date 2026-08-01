import Foundation

nonisolated enum PairingQRCodePayload {
    private static let invitationPathComponent = "invite"

    static func makePayload(
        linkToken: String,
        environment: AppBuildEnvironment = .current
    ) -> String? {
        guard
            PairingInvitation.isValidLinkToken(linkToken),
            let host = environment.pairingLinkHost
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(invitationPathComponent)/\(linkToken)"
        return components.url?.absoluteString
    }

    static func parse(
        _ payload: String,
        environment: AppBuildEnvironment = .current
    ) -> String? {
        guard
            let expectedHost = environment.pairingLinkHost,
            let components = URLComponents(string: payload),
            components.scheme?.lowercased() == "https",
            components.host?.lowercased() == expectedHost,
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.query == nil,
            components.fragment == nil
        else {
            return nil
        }

        let pathComponents = components.path.split(separator: "/")
        guard
            pathComponents.count == 2,
            pathComponents[0] == Substring(invitationPathComponent),
            PairingInvitation.isValidLinkToken(String(pathComponents[1])),
            makePayload(
                linkToken: String(pathComponents[1]),
                environment: environment
            ) == components.url?.absoluteString
        else {
            return nil
        }

        return String(pathComponents[1])
    }

    static func parse(
        _ url: URL,
        environment: AppBuildEnvironment = .current
    ) -> PairingCredential? {
        parse(url.absoluteString, environment: environment)
            .map(PairingCredential.linkToken)
    }

    static func parseManualEntry(_ entry: String) -> String? {
        let manualCode = PairingInvitation.normalizeManualCode(entry)
        return PairingInvitation.isValidManualCode(manualCode) ? manualCode : nil
    }
}
