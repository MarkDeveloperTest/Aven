import FirebaseFirestore
import FirebaseFunctions
import Foundation

@MainActor
final class FirebaseRelationshipRepository: RelationshipRepository {
    private enum Operation {
        case create
        case revoke
        case redeem
    }

    private let functions: Functions
    private let firestore: Firestore
    private var userObservationTask: Task<Void, Never>?
    private var relationshipObservationTask: Task<Void, Never>?
    private var observedUserID: String?
    private var observedRelationshipID: String?

    init(
        functions: Functions = .functions(region: "europe-west2"),
        firestore: Firestore = .firestore()
    ) {
        self.functions = functions
        self.firestore = firestore
    }

    deinit {
        userObservationTask?.cancel()
        relationshipObservationTask?.cancel()
    }

    func createInvitation(
        relationshipType: RelationshipType,
        relationshipStartDate: Date?,
        idempotencyKey: String
    ) async throws -> PairingInvitation {
        guard Self.isValidIdempotencyKey(idempotencyKey) else {
            throw AppError.unknown
        }
        let request = CreateInvitationRequest(
            relationshipType: relationshipType.rawValue,
            relationshipStartDate: relationshipStartDate.map(Self.encodeDate),
            idempotencyKey: idempotencyKey
        )
        let callable: Callable<CreateInvitationRequest, CreateInvitationResponse> =
            functions.httpsCallable("createInvitation")

        do {
            let response = try await callable.call(request)
            guard
                PairingInvitation.isValidCode(response.invitationCode),
                response.invitationCode.hasPrefix(response.invitationId + "."),
                Self.isValidInvitationID(response.invitationId),
                let expiresAt = Self.decodeDate(response.expiresAt)
            else {
                throw AppError.unknown
            }
            return PairingInvitation(
                id: response.invitationId,
                code: response.invitationCode,
                expiresAt: expiresAt
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw Self.mapCallableError(error, operation: .create)
        }
    }

    func revokeInvitation(id: String, idempotencyKey: String) async throws {
        guard
            Self.isValidInvitationID(id),
            Self.isValidIdempotencyKey(idempotencyKey)
        else {
            throw AppError.validation(.inviteCode)
        }

        let callable: Callable<RevokeInvitationRequest, RevokeInvitationResponse> =
            functions.httpsCallable("revokeInvitation")
        do {
            let response = try await callable.call(
                RevokeInvitationRequest(
                    invitationId: id,
                    idempotencyKey: idempotencyKey
                )
            )
            guard response.revoked else {
                throw AppError.unknown
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw Self.mapCallableError(error, operation: .revoke)
        }
    }

    func redeemInvitation(code: String, idempotencyKey: String) async throws -> String {
        guard
            PairingInvitation.isValidCode(code),
            Self.isValidIdempotencyKey(idempotencyKey)
        else {
            throw AppError.validation(.inviteCode)
        }

        let callable: Callable<RedeemInvitationRequest, RedeemInvitationResponse> =
            functions.httpsCallable("redeemInvitation")
        do {
            let response = try await callable.call(
                RedeemInvitationRequest(
                    invitationCode: code,
                    idempotencyKey: idempotencyKey
                )
            )
            guard Self.isValidRelationshipID(response.relationshipId) else {
                throw AppError.unknown
            }
            return response.relationshipId
        } catch let error as AppError {
            throw error
        } catch {
            throw Self.mapCallableError(error, operation: .redeem)
        }
    }

    func startObservingRelationship(
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    ) {
        stopObservingRelationship()
        observedUserID = userID

        let userReference = firestore.collection("users").document(userID)
        userObservationTask = Task { [weak self] in
            do {
                for try await snapshot in userReference.snapshots {
                    guard
                        let self,
                        Task.isCancelled == false,
                        self.observedUserID == userID
                    else {
                        return
                    }

                    guard snapshot.exists, let data = snapshot.data() else {
                        onChange(.failed(.unknown))
                        continue
                    }
                    let rawRelationshipID = data["activeRelationshipId"]
                    if rawRelationshipID == nil || rawRelationshipID is NSNull {
                        guard snapshot.metadata.isFromCache == false else {
                            onChange(.failed(.offline))
                            continue
                        }
                        self.stopRelationshipObservation()
                        onChange(.unpaired)
                        continue
                    }
                    guard
                        let relationshipID = rawRelationshipID as? String,
                        Self.isValidRelationshipID(relationshipID)
                    else {
                        onChange(.failed(.unknown))
                        continue
                    }
                    self.observeRelationship(
                        id: relationshipID,
                        for: userID,
                        onChange: onChange
                    )
                }
            } catch {
                guard
                    let self,
                    Task.isCancelled == false,
                    self.observedUserID == userID
                else {
                    return
                }
                self.userObservationTask = nil
                self.stopRelationshipObservation()
                self.observedUserID = nil
                onChange(.failed(Self.mapObservationError(error)))
            }
        }
    }

    func stopObservingRelationship() {
        userObservationTask?.cancel()
        userObservationTask = nil
        stopRelationshipObservation()
        observedUserID = nil
    }

    private func observeRelationship(
        id relationshipID: String,
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    ) {
        guard observedRelationshipID != relationshipID else { return }
        stopRelationshipObservation()
        observedRelationshipID = relationshipID

        let relationshipReference = firestore
            .collection("relationships")
            .document(relationshipID)
        relationshipObservationTask = Task { [weak self] in
            do {
                for try await snapshot in relationshipReference.snapshots {
                    guard
                        let self,
                        Task.isCancelled == false,
                        self.observedUserID == userID,
                        self.observedRelationshipID == relationshipID
                    else {
                        return
                    }
                    guard let summary = Self.relationshipSummary(
                        from: snapshot,
                        currentUserID: userID
                    ) else {
                        onChange(.failed(.unknown))
                        continue
                    }
                    onChange(.relationship(summary))
                }
            } catch {
                guard
                    let self,
                    Task.isCancelled == false,
                    self.observedUserID == userID,
                    self.observedRelationshipID == relationshipID
                else {
                    return
                }
                self.relationshipObservationTask = nil
                self.observedRelationshipID = nil
                onChange(.failed(Self.mapObservationError(error)))
            }
        }
    }

    private func stopRelationshipObservation() {
        relationshipObservationTask?.cancel()
        relationshipObservationTask = nil
        observedRelationshipID = nil
    }

    private nonisolated static func relationshipSummary(
        from snapshot: DocumentSnapshot,
        currentUserID: String
    ) -> RelationshipSummary? {
        guard
            snapshot.exists,
            let data = snapshot.data(),
            let memberIDs = data["memberIds"] as? [String],
            memberIDs.count == 2,
            Set(memberIDs).count == 2,
            memberIDs.contains(currentUserID),
            let statusValue = data["status"] as? String,
            let status = RelationshipStatus(rawValue: statusValue)
        else {
            return nil
        }

        let startDate = (data["relationshipStartDate"] as? Timestamp)?.dateValue()
        let memberDisplayNames = data["memberDisplayNames"] as? [String: Any]
        let partnerName = memberIDs
            .first(where: { $0 != currentUserID })
            .flatMap { memberDisplayNames?[$0] as? String }
            .flatMap(Self.validDisplayName)
        return RelationshipSummary(
            id: snapshot.documentID,
            memberIDs: memberIDs,
            partnerName: partnerName,
            status: status,
            startDate: startDate,
            inviteCode: nil
        )
    }

    private nonisolated static func isValidIdempotencyKey(_ value: String) -> Bool {
        value.count == 36 && UUID(uuidString: value) != nil
    }

    private nonisolated static func validDisplayName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, value.count <= 80 else { return nil }
        return value
    }

    private nonisolated static func mapObservationError(
        _ error: any Error
    ) -> AppError {
        let error = error as NSError
        return error.domain == NSURLErrorDomain ? .offline : .unknown
    }

    private nonisolated static func encodeDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private nonisolated static func decodeDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private nonisolated static func isValidInvitationID(_ value: String) -> Bool {
        value.range(
            of: #"^[a-f0-9]{40}$"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func isValidRelationshipID(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9_-]{16,128}$"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func mapCallableError(
        _ error: any Error,
        operation: Operation
    ) -> AppError {
        let error = error as NSError
        if error.domain == NSURLErrorDomain {
            return .offline
        }
        guard
            error.domain == FunctionsErrorDomain,
            let code = FunctionsErrorCode(rawValue: error.code)
        else {
            return .unknown
        }

        switch code {
        case .invalidArgument:
            return operation == .create ? .unknown : .validation(.inviteCode)
        case .unauthenticated:
            return .authentication(.invalidCredential)
        case .permissionDenied, .notFound, .alreadyExists:
            return .relationship(.notAuthorized)
        case .failedPrecondition:
            switch operation {
            case .create:
                return .relationship(.alreadyActive)
            case .revoke:
                return .relationship(.notAuthorized)
            case .redeem:
                return .relationship(.inviteExpired)
            }
        case .deadlineExceeded, .unavailable:
            return .offline
        default:
            return .unknown
        }
    }
}

private nonisolated struct CreateInvitationRequest: Encodable, Sendable {
    let relationshipType: String
    let relationshipStartDate: String?
    let idempotencyKey: String

    private enum CodingKeys: String, CodingKey {
        case relationshipType
        case relationshipStartDate
        case idempotencyKey
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relationshipType, forKey: .relationshipType)
        if let relationshipStartDate {
            try container.encode(
                relationshipStartDate,
                forKey: .relationshipStartDate
            )
        } else {
            try container.encodeNil(forKey: .relationshipStartDate)
        }
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
    }
}

private nonisolated struct CreateInvitationResponse: Decodable, Sendable {
    let invitationCode: String
    let invitationId: String
    let expiresAt: String
    let reused: Bool
}

private nonisolated struct RevokeInvitationRequest: Encodable, Sendable {
    let invitationId: String
    let idempotencyKey: String
}

private nonisolated struct RevokeInvitationResponse: Decodable, Sendable {
    let revoked: Bool
    let reused: Bool
}

private nonisolated struct RedeemInvitationRequest: Encodable, Sendable {
    let invitationCode: String
    let idempotencyKey: String
}

private nonisolated struct RedeemInvitationResponse: Decodable, Sendable {
    let relationshipId: String
    let alreadyRedeemed: Bool
}
