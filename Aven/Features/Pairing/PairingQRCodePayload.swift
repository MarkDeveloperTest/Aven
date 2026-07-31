import Foundation

nonisolated enum PairingQRCodePayload {
    private static let host = "pair"
    private static let version = "1"

    static func makePayload(
        invitationCode: String,
        environment: AppBuildEnvironment = .current
    ) -> String? {
        guard isValidInvitationCode(invitationCode) else { return nil }

        var components = URLComponents()
        components.scheme = scheme(for: environment)
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "code", value: invitationCode),
        ]
        return components.string
    }

    static func parse(
        _ payload: String,
        environment: AppBuildEnvironment = .current
    ) -> String? {
        guard
            let components = URLComponents(string: payload),
            components.scheme == scheme(for: environment),
            components.host == host,
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.path.isEmpty,
            components.fragment == nil,
            let queryItems = components.queryItems,
            queryItems.count == 2,
            queryItems[0].name == "v",
            queryItems[0].value == version,
            queryItems[1].name == "code",
            let invitationCode = queryItems[1].value,
            isValidInvitationCode(invitationCode),
            makePayload(
                invitationCode: invitationCode,
                environment: environment
            ) == payload
        else {
            return nil
        }

        return invitationCode
    }

    static func parseManualEntry(_ entry: String) -> String? {
        let invitationCode = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValidInvitationCode(invitationCode) ? invitationCode : nil
    }

    static func isValidInvitationCode(_ invitationCode: String) -> Bool {
        let bytes = Array(invitationCode.utf8)
        guard bytes.count == 84, bytes[40] == 46 else { return false }

        let invitationIDIsValid = bytes[..<40].allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
        let secretIsValid = bytes[41...].allSatisfy { byte in
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
                || byte == 45
                || byte == 95
        }
        return invitationIDIsValid && secretIsValid
    }

    private static func scheme(for environment: AppBuildEnvironment) -> String {
        switch environment {
        case .development:
            "aven-dev"
        case .staging:
            "aven-staging"
        case .production:
            "aven"
        }
    }
}
