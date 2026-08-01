import Foundation

@MainActor
final class UnavailableRelationshipRepository: RelationshipRepository {
    func createInvitation(
        relationshipType: RelationshipType,
        relationshipStartDate: Date?,
        idempotencyKey: String
    ) async throws -> PairingInvitation {
        _ = relationshipType
        _ = relationshipStartDate
        _ = idempotencyKey
        throw AppError.externalConfigurationRequired
    }

    func revokeInvitation(id: String, idempotencyKey: String) async throws {
        _ = id
        _ = idempotencyKey
        throw AppError.externalConfigurationRequired
    }

    func redeemInvitation(
        credential: PairingCredential,
        idempotencyKey: String
    ) async throws -> String {
        _ = credential
        _ = idempotencyKey
        throw AppError.externalConfigurationRequired
    }

    func startObservingRelationship(
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    ) {
        _ = userID
        onChange(.failed(.externalConfigurationRequired))
    }

    func stopObservingRelationship() {}
}
