import Foundation

nonisolated enum AppError: Error, Equatable, Sendable {
    case authentication(AuthenticationError)
    case validation(ValidationError)
    case relationship(RelationshipError)
    case offline
    case externalConfigurationRequired
    case unknown

    var localizedResource: LocalizedStringResource {
        switch self {
        case .authentication(.cancelled):
            "error.auth.cancelled"
        case .authentication(.invalidCredential):
            "error.auth.invalid_credential"
        case .authentication(.providerUnavailable):
            "error.auth.provider_unavailable"
        case .authentication(.notConfigured), .externalConfigurationRequired:
            "error.external_configuration"
        case .validation(.displayName):
            "error.validation.display_name"
        case .validation(.inviteCode):
            "error.validation.invite_code"
        case .relationship(.alreadyActive):
            "error.relationship.already_active"
        case .relationship(.inviteExpired):
            "error.relationship.invite_expired"
        case .relationship(.notAuthorized):
            "error.relationship.not_authorized"
        case .offline:
            "error.offline"
        case .unknown:
            "error.unknown"
        }
    }
}

nonisolated enum AuthenticationError: Error, Equatable, Sendable {
    case cancelled
    case invalidCredential
    case providerUnavailable
    case notConfigured
}

nonisolated enum ValidationError: Error, Equatable, Sendable {
    case displayName
    case inviteCode
}

nonisolated enum RelationshipError: Error, Equatable, Sendable {
    case alreadyActive
    case inviteExpired
    case notAuthorized
}
