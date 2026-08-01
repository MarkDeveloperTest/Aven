import Foundation

nonisolated struct PairingInvitation: Equatable, Sendable {
    let id: String
    let linkToken: String
    let manualCode: String
    let expiresAt: Date

    nonisolated static func isValidLinkToken(_ token: String) -> Bool {
        token.range(
            of: #"^[a-f0-9]{40}\.[A-Za-z0-9_-]{43}$"#,
            options: .regularExpression
        ) != nil
    }

    nonisolated static func normalizeManualCode(_ code: String) -> String {
        code
            .uppercased()
            .filter { $0.isWhitespace == false && $0 != "-" }
    }

    nonisolated static func isValidManualCode(_ code: String) -> Bool {
        normalizeManualCode(code).range(
            of: #"^[2-9A-HJ-NP-Z]{6}$"#,
            options: .regularExpression
        ) != nil
    }

    var formattedManualCode: String {
        let normalized = Self.normalizeManualCode(manualCode)
        guard normalized.count == 6 else { return manualCode }
        let splitIndex = normalized.index(normalized.startIndex, offsetBy: 3)
        return String(normalized[..<splitIndex]) + "-" + String(normalized[splitIndex...])
    }
}

nonisolated enum PairingCredential: Codable, Equatable, Sendable {
    case linkToken(String)
    case manualCode(String)

    nonisolated enum Kind: String, Codable, Sendable {
        case token
        case code
    }

    var kind: Kind {
        switch self {
        case .linkToken: .token
        case .manualCode: .code
        }
    }

    var value: String {
        switch self {
        case .linkToken(let token): token
        case .manualCode(let code): PairingInvitation.normalizeManualCode(code)
        }
    }

    var isValid: Bool {
        switch self {
        case .linkToken(let token): PairingInvitation.isValidLinkToken(token)
        case .manualCode(let code): PairingInvitation.isValidManualCode(code)
        }
    }
}

nonisolated enum RelationshipObservation: Equatable, Sendable {
    case unpaired
    case relationship(RelationshipSummary)
    case failed(AppError)
}

@MainActor
protocol RelationshipRepository: AnyObject {
    func createInvitation(
        relationshipType: RelationshipType,
        relationshipStartDate: Date?,
        idempotencyKey: String
    ) async throws -> PairingInvitation

    func revokeInvitation(id: String, idempotencyKey: String) async throws

    func redeemInvitation(
        credential: PairingCredential,
        idempotencyKey: String
    ) async throws -> String

    func startObservingRelationship(
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    )

    func stopObservingRelationship()
}
