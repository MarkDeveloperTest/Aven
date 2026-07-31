import Foundation
import Observation

@MainActor
@Observable
final class RelationshipStore {
    nonisolated enum DeferredPairingState: Equatable, Sendable {
        case none
        case createInvitation
        case redeemInvitation
    }

    private enum PairingOperationResult {
        case invitation(PairingInvitation)
        case redeemed(relationshipID: String)
        case revoked
    }

    private let repository: any RelationshipRepository
    private let pairingIntentPersistence: PairingIntentPersistenceCoordinator
    private var pairingTask: Task<Void, Never>?
    private var pairingOwnerClaimTask: Task<Void, Never>?
    private var observedUserID: String?
    private var preparedProfile: UserProfile?
    private var deferredInvitationCode: String?
    private var wantsInvitationCreation = false
    private var pairingIdempotencyKey: String?
    private var revocationInvitationID: String?
    private var revocationIdempotencyKey: String?
    private var persistedPairingOwnerUserID: String?
    private var quarantinedPairingState: StoredPairingState?
    private var requiresPairingOwnerClaimPersistence = false
    private var pairingPersistenceRevision = 0
    private var didRestoreDeferredPairing = false

    private(set) var ownerUserID: String?
    private(set) var invitation: PairingInvitation?
    private(set) var isPairing = false
    private(set) var pairingError: AppError?

    var relationship = RelationshipSummary(
        id: "local-unpaired",
        memberIDs: [],
        partnerName: nil,
        status: .unpaired,
        startDate: nil,
        inviteCode: nil
    )
    var messages: [Message] = []
    var memories: [MemoryItem] = []
    var sharedDayEvents: [SharedDayEvent] = []

    var isActive: Bool { relationship.status == .active }
    var deferredPairingState: DeferredPairingState {
        if deferredInvitationCode != nil {
            return .redeemInvitation
        }
        return wantsInvitationCreation ? .createInvitation : .none
    }

    init(
        repository: any RelationshipRepository = UnavailableRelationshipRepository(),
        pairingIntentVault: any PairingIntentVault = NoOpPairingIntentVault()
    ) {
        self.repository = repository
        pairingIntentPersistence = PairingIntentPersistenceCoordinator(
            vault: pairingIntentVault
        )
    }

    func restoreDeferredPairing() async {
        guard didRestoreDeferredPairing == false else { return }

        do {
            guard let state = try await pairingIntentPersistence.load() else {
                didRestoreDeferredPairing = true
                return
            }
            guard state.isValid() else {
                didRestoreDeferredPairing = true
                persistPairingState()
                return
            }

            didRestoreDeferredPairing = true
            persistedPairingOwnerUserID = state.ownerUserID
            if state.ownerUserID != nil {
                // Keep account-owned bearer codes private until prepare(for:)
                // proves that Firebase restored the same UID.
                quarantinedPairingState = state
            } else {
                applyRestoredPairingState(state)
            }
        } catch {
            AppLogger.persistence.error("Secure pairing state restore failed")
        }
    }

    func prepare(
        for user: AuthenticatedUser,
        profile: UserProfile?,
        locale: Locale? = nil
    ) {
        let matchingQuarantinedState: StoredPairingState?
        if let quarantinedPairingState {
            matchingQuarantinedState = quarantinedPairingState.ownerUserID == user.id
                ? quarantinedPairingState
                : nil
            self.quarantinedPairingState = nil
        } else {
            matchingQuarantinedState = nil
        }

        if ownerUserID != user.id {
            let belongsToAnotherUser = persistedPairingOwnerUserID.map {
                $0 != user.id
            } ?? false
            let shouldPreserveDeferredPairing = ownerUserID == nil
                && belongsToAnotherUser == false
            let shouldPersistOwnerClaim = shouldPreserveDeferredPairing
                && persistedPairingOwnerUserID == nil
                && storedPairingState != nil
            resetScopedState(clearDeferredPairing: shouldPreserveDeferredPairing == false)
            ownerUserID = user.id
            relationship.memberIDs = [user.id]
            if let matchingQuarantinedState {
                persistedPairingOwnerUserID = user.id
                applyRestoredPairingState(matchingQuarantinedState)
            } else if shouldPreserveDeferredPairing {
                persistedPairingOwnerUserID = user.id
                requiresPairingOwnerClaimPersistence = shouldPersistOwnerClaim
                if shouldPersistOwnerClaim == false {
                    persistPairingState()
                }
            }
        }
        preparedProfile = profile
        if relationship.status == .unpaired
            || relationship.status == .invitationPending {
            relationship.startDate = profile?.relationshipStartDate
        }

        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") else {
            startObservingRelationshipIfNeeded(for: user.id)
            processDeferredPairingIfPossible()
            return
        }
        activateDemoRelationship(currentUserID: user.id, locale: locale)
    }

    func createInvitation(
        relationshipType: RelationshipType = .unspecified,
        relationshipStartDate: Date? = nil
    ) {
        guard relationship.status == .unpaired else { return }
        pairingError = nil
        deferredInvitationCode = nil
        wantsInvitationCreation = true
        pairingIdempotencyKey = Self.makeIdempotencyKey()
        revocationInvitationID = nil
        revocationIdempotencyKey = nil
        persistPairingState()

        if preparedProfile == nil {
            return
        }

        let idempotencyKey = pairingIdempotencyKey
            ?? Self.makeIdempotencyKey()
        pairingIdempotencyKey = idempotencyKey
        performPairingOperation { [repository] in
            let invitation = try await repository.createInvitation(
                relationshipType: relationshipType,
                relationshipStartDate: relationshipStartDate,
                idempotencyKey: idempotencyKey
            )
            return .invitation(invitation)
        }
    }

    func revokeInvitation() {
        guard let invitation else {
            clearLocalInvitation()
            return
        }
        pairingError = nil
        let idempotencyKey: String
        if revocationInvitationID == invitation.id,
           let existingKey = revocationIdempotencyKey {
            idempotencyKey = existingKey
        } else {
            idempotencyKey = Self.makeIdempotencyKey()
            revocationInvitationID = invitation.id
            revocationIdempotencyKey = idempotencyKey
        }
        persistPairingState()
        performPairingOperation { [repository] in
            try await repository.revokeInvitation(
                id: invitation.id,
                idempotencyKey: idempotencyKey
            )
            return .revoked
        }
    }

    func redeemInvitation(code: String) {
        pairingError = nil
        guard PairingInvitation.isValidCode(code) else {
            pairingError = .validation(.inviteCode)
            return
        }

        wantsInvitationCreation = false
        deferredInvitationCode = code
        pairingIdempotencyKey = Self.makeIdempotencyKey()
        persistPairingState()
        processDeferredPairingIfPossible()
    }

    func retryDeferredPairing() {
        pairingError = nil
        processDeferredPairingIfPossible()
    }

    func clearDeferredPairing() {
        guard isPairing == false else { return }
        pairingOwnerClaimTask?.cancel()
        pairingOwnerClaimTask = nil
        requiresPairingOwnerClaimPersistence = false
        deferredInvitationCode = nil
        wantsInvitationCreation = false
        pairingIdempotencyKey = nil
        pairingError = nil
        persistPairingState()
    }

    func activateDemoRelationship(
        currentUserID: String,
        locale: Locale? = nil
    ) {
        relationship = RelationshipSummary(
            id: "demo-relationship",
            memberIDs: [currentUserID, "demo-partner-sam"],
            partnerName: "Sam",
            status: .active,
            startDate: Calendar.current.date(byAdding: .month, value: -18, to: .now),
            inviteCode: nil
        )

        if messages.isEmpty {
            messages = [
                Message(
                    id: UUID(),
                    senderID: "demo-partner-sam",
                    text: String(
                        localized: "demo.message.partner",
                        locale: locale ?? .current
                    ),
                    sentAt: Date.now.addingTimeInterval(-1_800),
                    deliveryState: .sent
                ),
                Message(
                    id: UUID(),
                    senderID: currentUserID,
                    text: String(
                        localized: "demo.message.me",
                        locale: locale ?? .current
                    ),
                    sentAt: Date.now.addingTimeInterval(-1_200),
                    deliveryState: .sent
                )
            ]
        }
    }

    func sendMessage(_ text: String, senderID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        messages.append(
            Message(
                id: UUID(),
                senderID: senderID,
                text: trimmed,
                sentAt: .now,
                deliveryState: .sent
            )
        )
    }

    func addMemory(caption: String, imageData: Data?, creatorID: String) {
        memories.insert(
            MemoryItem(
                id: UUID(),
                creatorID: creatorID,
                caption: caption,
                createdAt: .now,
                imageData: imageData
            ),
            at: 0
        )
    }

    func addSharedDayEvent(
        title: String,
        category: SharedDayEvent.Category,
        creatorID: String
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        sharedDayEvents.append(
            SharedDayEvent(
                id: UUID(),
                creatorID: creatorID,
                title: trimmed,
                occurredAt: .now,
                category: category
            )
        )
        sharedDayEvents.sort { $0.occurredAt < $1.occurredAt }
    }

    private func processDeferredPairingIfPossible() {
        guard
            isPairing == false,
            pairingOwnerClaimTask == nil,
            ownerUserID != nil
        else {
            return
        }

        if requiresPairingOwnerClaimPersistence {
            persistPairingOwnerClaim()
            return
        }

        guard let preparedProfile else { return }

        if let deferredInvitationCode {
            let idempotencyKey = pairingIdempotencyKey
                ?? Self.makeIdempotencyKey()
            pairingIdempotencyKey = idempotencyKey
            persistPairingState()
            performPairingOperation { [repository] in
                let relationshipID = try await repository.redeemInvitation(
                    code: deferredInvitationCode,
                    idempotencyKey: idempotencyKey
                )
                return .redeemed(relationshipID: relationshipID)
            }
        } else if wantsInvitationCreation {
            let idempotencyKey = pairingIdempotencyKey
                ?? Self.makeIdempotencyKey()
            pairingIdempotencyKey = idempotencyKey
            persistPairingState()
            performPairingOperation { [repository] in
                let invitation = try await repository.createInvitation(
                    relationshipType: preparedProfile.relationshipType,
                    relationshipStartDate: preparedProfile.relationshipStartDate,
                    idempotencyKey: idempotencyKey
                )
                return .invitation(invitation)
            }
        }
    }

    private func performPairingOperation(
        _ operation: @escaping @MainActor () async throws -> PairingOperationResult
    ) {
        guard isPairing == false, let expectedOwnerUserID = ownerUserID else { return }
        pairingTask?.cancel()
        pairingError = nil
        isPairing = true

        pairingTask = Task { [weak self] in
            defer {
                if self?.ownerUserID == expectedOwnerUserID {
                    self?.isPairing = false
                    self?.pairingTask = nil
                }
            }
            do {
                try Task.checkCancellation()
                let result = try await operation()
                try Task.checkCancellation()
                guard self?.ownerUserID == expectedOwnerUserID else { return }
                self?.apply(result)
            } catch is CancellationError {
                return
            } catch let appError as AppError {
                guard self?.ownerUserID == expectedOwnerUserID else { return }
                guard self?.relationship.status != .active else { return }
                self?.discardDeferredInvitationIfDefinitive(appError)
                self?.pairingError = appError
            } catch {
                guard self?.ownerUserID == expectedOwnerUserID else { return }
                guard self?.relationship.status != .active else { return }
                self?.pairingError = .unknown
            }
        }
    }

    private func apply(_ result: PairingOperationResult) {
        switch result {
        case .invitation(let invitation):
            self.invitation = invitation
            relationship.inviteCode = invitation.code
            relationship.status = .invitationPending
            deferredInvitationCode = nil
            wantsInvitationCreation = false
            pairingIdempotencyKey = nil
            revocationInvitationID = nil
            revocationIdempotencyKey = nil
            persistPairingState()
        case .redeemed(let relationshipID):
            invitation = nil
            deferredInvitationCode = nil
            wantsInvitationCreation = false
            pairingIdempotencyKey = nil
            revocationInvitationID = nil
            revocationIdempotencyKey = nil
            persistPairingState()
            if relationship.id == relationshipID,
               relationship.status == .active,
               relationship.memberIDs.count == 2 {
                return
            }
            relationship = RelationshipSummary(
                id: relationshipID,
                memberIDs: ownerUserID.map { [$0] } ?? [],
                partnerName: nil,
                status: .active,
                startDate: preparedProfile?.relationshipStartDate,
                inviteCode: nil
            )
        case .revoked:
            clearLocalInvitation()
        }
    }

    private func startObservingRelationshipIfNeeded(for userID: String) {
        guard observedUserID != userID else { return }
        repository.stopObservingRelationship()
        observedUserID = userID
        repository.startObservingRelationship(for: userID) { [weak self] observation in
            guard let self, self.ownerUserID == userID else { return }

            switch observation {
            case .unpaired:
                if self.relationship.status == .active {
                    self.relationship = Self.unpairedRelationship(ownerUserID: userID)
                }
            case .relationship(let summary):
                self.relationship = summary
                self.invitation = nil
                self.deferredInvitationCode = nil
                self.wantsInvitationCreation = false
                self.pairingIdempotencyKey = nil
                self.revocationInvitationID = nil
                self.revocationIdempotencyKey = nil
                self.pairingError = nil
                self.persistPairingState()
            case .failed:
                self.observedUserID = nil
                AppLogger.persistence.error("Firebase relationship observation failed")
            }
        }
    }

    private func clearLocalInvitation() {
        invitation = nil
        relationship.inviteCode = nil
        relationship.status = .unpaired
        wantsInvitationCreation = false
        pairingIdempotencyKey = nil
        revocationInvitationID = nil
        revocationIdempotencyKey = nil
        persistPairingState()
    }

    private func discardDeferredInvitationIfDefinitive(_ error: AppError) {
        guard deferredInvitationCode != nil else { return }
        switch error {
        case .validation(.inviteCode),
             .relationship(.alreadyActive),
             .relationship(.inviteExpired),
             .relationship(.notAuthorized):
            deferredInvitationCode = nil
            pairingIdempotencyKey = nil
            persistPairingState()
        case .authentication,
             .validation,
             .offline,
             .externalConfigurationRequired,
             .unknown:
            return
        }
    }

    func endRelationship() {
        relationship.status = .ended
        relationship.inviteCode = nil
        invitation = nil
        persistPairingState()
    }

    func reset() {
        resetScopedState(clearDeferredPairing: true)
    }

    private func resetScopedState(clearDeferredPairing: Bool) {
        pairingTask?.cancel()
        pairingTask = nil
        pairingOwnerClaimTask?.cancel()
        pairingOwnerClaimTask = nil
        requiresPairingOwnerClaimPersistence = false
        repository.stopObservingRelationship()
        observedUserID = nil
        ownerUserID = nil
        preparedProfile = nil
        isPairing = false
        pairingError = nil
        relationship = Self.unpairedRelationship(ownerUserID: nil)
        messages.removeAll(keepingCapacity: false)
        memories.removeAll(keepingCapacity: false)
        sharedDayEvents.removeAll(keepingCapacity: false)
        if clearDeferredPairing {
            invitation = nil
            deferredInvitationCode = nil
            wantsInvitationCreation = false
            pairingIdempotencyKey = nil
            revocationInvitationID = nil
            revocationIdempotencyKey = nil
            persistedPairingOwnerUserID = nil
            quarantinedPairingState = nil
            persistPairingState()
        } else if let invitation {
            relationship.inviteCode = invitation.code
            relationship.status = .invitationPending
        }
    }

    private func persistPairingState() {
        pairingPersistenceRevision += 1
        let revision = pairingPersistenceRevision
        let state = storedPairingState
        Task { [pairingIntentPersistence] in
            do {
                try await pairingIntentPersistence.apply(
                    state,
                    revision: revision
                )
            } catch {
                AppLogger.persistence.error("Secure pairing state save failed")
            }
        }
    }

    private func persistPairingOwnerClaim() {
        guard
            pairingOwnerClaimTask == nil,
            requiresPairingOwnerClaimPersistence,
            let expectedOwnerUserID = ownerUserID,
            let state = storedPairingState
        else {
            return
        }

        pairingPersistenceRevision += 1
        let revision = pairingPersistenceRevision
        pairingOwnerClaimTask = Task { [weak self, pairingIntentPersistence] in
            do {
                try await pairingIntentPersistence.apply(
                    state,
                    revision: revision
                )
                try Task.checkCancellation()
                guard self?.ownerUserID == expectedOwnerUserID else { return }
                self?.requiresPairingOwnerClaimPersistence = false
                self?.pairingOwnerClaimTask = nil
                self?.processDeferredPairingIfPossible()
            } catch is CancellationError {
                return
            } catch {
                guard self?.ownerUserID == expectedOwnerUserID else { return }
                self?.pairingOwnerClaimTask = nil
                self?.pairingError = .unknown
                AppLogger.persistence.error("Secure pairing owner claim failed")
            }
        }
    }

    private func applyRestoredPairingState(_ state: StoredPairingState) {
        switch state.kind {
        case .createInvitation:
            wantsInvitationCreation = true
            pairingIdempotencyKey = state.idempotencyKey
        case .redeemInvitation:
            deferredInvitationCode = state.invitationCode
            pairingIdempotencyKey = state.idempotencyKey
        case .invitation:
            guard
                let invitationID = state.invitationID,
                let invitationCode = state.invitationCode,
                let expiresAt = state.invitationExpiresAt
            else {
                persistPairingState()
                return
            }
            let restoredInvitation = PairingInvitation(
                id: invitationID,
                code: invitationCode,
                expiresAt: expiresAt
            )
            invitation = restoredInvitation
            relationship.inviteCode = invitationCode
            relationship.status = .invitationPending
            if let revocationIdempotencyKey = state.revocationIdempotencyKey {
                revocationInvitationID = invitationID
                self.revocationIdempotencyKey = revocationIdempotencyKey
            }
        }
    }

    private var storedPairingState: StoredPairingState? {
        if let invitation,
           let ownerUserID = ownerUserID ?? persistedPairingOwnerUserID {
            let revokeKey = revocationInvitationID == invitation.id
                ? revocationIdempotencyKey
                : nil
            return .invitation(
                ownerUserID: ownerUserID,
                invitation: invitation,
                revocationIdempotencyKey: revokeKey
            )
        }

        if let deferredInvitationCode,
           let pairingIdempotencyKey {
            return .redeemInvitation(
                ownerUserID: ownerUserID ?? persistedPairingOwnerUserID,
                idempotencyKey: pairingIdempotencyKey,
                invitationCode: deferredInvitationCode
            )
        }

        if wantsInvitationCreation,
           let pairingIdempotencyKey {
            return .createInvitation(
                ownerUserID: ownerUserID ?? persistedPairingOwnerUserID,
                idempotencyKey: pairingIdempotencyKey
            )
        }
        return nil
    }

    private static func unpairedRelationship(ownerUserID: String?) -> RelationshipSummary {
        RelationshipSummary(
            id: "local-unpaired",
            memberIDs: ownerUserID.map { [$0] } ?? [],
            partnerName: nil,
            status: .unpaired,
            startDate: nil,
            inviteCode: nil
        )
    }

    private nonisolated static func makeIdempotencyKey() -> String {
        UUID().uuidString.lowercased()
    }
}
