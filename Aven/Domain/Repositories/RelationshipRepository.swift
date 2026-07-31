import Foundation

nonisolated struct PairingInvitation: Equatable, Sendable {
    let id: String
    let code: String
    let expiresAt: Date

    nonisolated static func isValidCode(_ code: String) -> Bool {
        code.range(
            of: #"^[a-f0-9]{40}\.[A-Za-z0-9_-]{43}$"#,
            options: .regularExpression
        ) != nil
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

    func redeemInvitation(code: String, idempotencyKey: String) async throws -> String

    func startObservingRelationship(
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    )

    func stopObservingRelationship()
}
