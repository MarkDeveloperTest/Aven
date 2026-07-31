import Foundation
import Testing
@testable import Aven

@Suite("Relationship store")
@MainActor
struct RelationshipStoreTests {
    @Test("Invitation creation waits for a prepared profile")
    func invitationCreationWaitsForProfile() async {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(
            userID: user.id,
            relationshipType: .married,
            relationshipStartDate: relationshipStartDate
        )

        store.createInvitation(
            relationshipType: .dating,
            relationshipStartDate: nil
        )

        #expect(store.deferredPairingState == .createInvitation)
        #expect(repository.createCalls.isEmpty)

        store.prepare(for: user, profile: profile)

        #expect(await waitUntil {
            repository.createCalls.count == 1 && store.isPairing == false
        })
        #expect(repository.createCalls.first?.relationshipType == .married)
        #expect(
            repository.createCalls.first?.relationshipStartDate
                == relationshipStartDate
        )
        #expect(store.invitation == repository.invitationResult)
        #expect(store.relationship.status == .invitationPending)
        #expect(store.relationship.inviteCode == repository.invitationResult.code)
        #expect(store.deferredPairingState == .none)
        #expect(store.pairingError == nil)
    }

    @Test("A valid scanned invitation waits for a prepared profile")
    func scannedInvitationWaitsForProfile() async {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)

        store.redeemInvitation(code: validInvitationCode)

        #expect(store.deferredPairingState == .redeemInvitation)
        #expect(repository.redeemCalls.isEmpty)

        store.prepare(for: user, profile: profile)

        #expect(await waitUntil {
            repository.redeemCalls.count == 1 && store.isPairing == false
        })
        #expect(repository.redeemCalls == [validInvitationCode])
        #expect(store.relationship.id == repository.redeemedRelationshipID)
        #expect(store.relationship.status == .active)
        #expect(store.relationship.memberIDs == [user.id])
        #expect(store.relationship.inviteCode == nil)
        #expect(store.deferredPairingState == .none)
        #expect(store.pairingError == nil)
    }

    @Test("Malformed scanned invitations never reach the repository")
    func malformedInvitationIsRejectedLocally() {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        store.prepare(for: user, profile: makeProfile(userID: user.id))

        store.redeemInvitation(code: "not-an-invitation")

        #expect(repository.redeemCalls.isEmpty)
        #expect(store.deferredPairingState == .none)
        #expect(store.isPairing == false)
        #expect(store.relationship.status == .unpaired)
        #expect(store.pairingError == .validation(.inviteCode))
    }

    @Test("Invitation creation retries reuse one Firebase idempotency key")
    func createRetryReusesIdempotencyKey() async {
        let repository = FakeRelationshipRepository()
        repository.createFailuresRemaining = 1
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        store.prepare(for: user, profile: profile)

        store.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            store.pairingError == .offline && store.isPairing == false
        })

        store.retryDeferredPairing()
        #expect(await waitUntil {
            store.invitation != nil && store.isPairing == false
        })
        #expect(repository.createIdempotencyKeys.count == 2)
        #expect(Set(repository.createIdempotencyKeys).count == 1)
    }

    @Test("Invitation redemption retries reuse one Firebase idempotency key")
    func redeemRetryReusesIdempotencyKey() async {
        let repository = FakeRelationshipRepository()
        repository.redeemFailuresRemaining = 1
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        store.prepare(for: user, profile: makeProfile(userID: user.id))

        store.redeemInvitation(code: validInvitationCode)
        #expect(await waitUntil {
            store.pairingError == .offline && store.isPairing == false
        })

        store.retryDeferredPairing()
        #expect(await waitUntil {
            store.relationship.status == .active && store.isPairing == false
        })
        #expect(repository.redeemIdempotencyKeys.count == 2)
        #expect(Set(repository.redeemIdempotencyKeys).count == 1)
    }

    @Test("A successful server revoke clears the pending invitation")
    func successfulRevokeClearsInvitation() async {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        store.prepare(for: user, profile: profile)

        store.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            store.relationship.status == .invitationPending
                && store.isPairing == false
        })

        store.revokeInvitation()

        #expect(await waitUntil {
            repository.revokeCalls.count == 1 && store.isPairing == false
        })
        #expect(repository.revokeCalls == [repository.invitationResult.id])
        #expect(store.invitation == nil)
        #expect(store.relationship.status == .unpaired)
        #expect(store.relationship.inviteCode == nil)
        #expect(store.pairingError == nil)
    }

    @Test("Invitation revocation retries reuse one Firebase idempotency key")
    func revokeRetryReusesIdempotencyKey() async {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        store.prepare(for: user, profile: profile)
        store.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            store.invitation != nil && store.isPairing == false
        })
        repository.revokeFailuresRemaining = 1

        store.revokeInvitation()
        #expect(await waitUntil {
            store.pairingError == .offline && store.isPairing == false
        })
        store.revokeInvitation()

        #expect(await waitUntil {
            store.relationship.status == .unpaired && store.isPairing == false
        })
        #expect(repository.revokeIdempotencyKeys.count == 2)
        #expect(Set(repository.revokeIdempotencyKeys).count == 1)
    }

    @Test("An observed active relationship replaces pending invitation state")
    func observedRelationshipUpdatesStore() async {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        store.prepare(for: user, profile: profile)
        store.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            store.relationship.status == .invitationPending
                && store.isPairing == false
        })

        let activeRelationship = makeActiveRelationship(
            id: "relationship-observed",
            currentUserID: user.id
        )
        #expect(repository.emit(activeRelationship))

        #expect(store.relationship == activeRelationship)
        #expect(store.invitation == nil)
        #expect(store.deferredPairingState == .none)
        #expect(store.pairingError == nil)
    }

    @Test("A callable response cannot overwrite an observed couple")
    func observedRelationshipWinsRedeemRace() async {
        let repository = FakeRelationshipRepository()
        repository.shouldSuspendRedeem = true
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        store.prepare(for: user, profile: makeProfile(userID: user.id))

        store.redeemInvitation(code: validInvitationCode)
        #expect(await waitUntil {
            repository.hasSuspendedRedeem && store.isPairing
        })

        let activeRelationship = makeActiveRelationship(
            id: repository.redeemedRelationshipID,
            currentUserID: user.id
        )
        #expect(repository.emit(activeRelationship))
        repository.resumeRedeem(returning: repository.redeemedRelationshipID)

        #expect(await waitUntil { store.isPairing == false })
        #expect(store.relationship == activeRelationship)
        #expect(store.relationship.memberIDs.count == 2)
        #expect(store.pairingError == nil)
    }

    @Test("A Firestore observation failure keeps the last confirmed couple")
    func observationFailureKeepsActiveRelationship() {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        store.prepare(for: user, profile: makeProfile(userID: user.id))
        let activeRelationship = makeActiveRelationship(
            id: "relationship-observed",
            currentUserID: user.id
        )
        #expect(repository.emit(activeRelationship))

        #expect(repository.emitObservation(.failed(.offline)))

        #expect(store.relationship == activeRelationship)
        #expect(store.pairingError == nil)
    }

    @Test("Preparing again preserves the Firebase relationship start date")
    func preparingAgainPreservesObservedStartDate() {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let activeRelationship = makeActiveRelationship(
            id: "relationship-observed",
            currentUserID: user.id
        )
        store.prepare(for: user, profile: makeProfile(userID: user.id))
        #expect(repository.emit(activeRelationship))

        let differentProfile = makeProfile(
            userID: user.id,
            relationshipStartDate: Date(timeIntervalSince1970: 1_800_000_000)
        )
        store.prepare(for: user, profile: differentProfile)

        #expect(store.relationship == activeRelationship)
        #expect(store.relationship.startDate == relationshipStartDate)
    }

    @Test("A scanned Firebase invitation survives a process restart")
    func scannedInvitationSurvivesRestart() async throws {
        let vault = FakePairingIntentVault()
        let firstStore = RelationshipStore(
            repository: FakeRelationshipRepository(),
            pairingIntentVault: vault
        )
        firstStore.redeemInvitation(code: validInvitationCode)

        let savedState = try #require(
            await waitForVaultState(vault, kind: .redeemInvitation)
        )
        let savedKey = try #require(savedState.idempotencyKey)
        #expect(savedState.kind == .redeemInvitation)

        let repository = FakeRelationshipRepository()
        let restoredStore = RelationshipStore(
            repository: repository,
            pairingIntentVault: vault
        )
        await restoredStore.restoreDeferredPairing()
        #expect(restoredStore.deferredPairingState == .redeemInvitation)

        let user = makeUser(id: "user-a")
        restoredStore.prepare(
            for: user,
            profile: makeProfile(userID: user.id)
        )
        #expect(await waitUntil {
            repository.redeemCalls.count == 1
                && restoredStore.isPairing == false
        })
        #expect(repository.redeemIdempotencyKeys == [savedKey])
    }

    @Test("A generated QR survives restart and remains revocable")
    func generatedInvitationSurvivesRestart() async throws {
        let vault = FakePairingIntentVault()
        let repository = FakeRelationshipRepository()
        let firstStore = RelationshipStore(
            repository: repository,
            pairingIntentVault: vault
        )
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        firstStore.prepare(for: user, profile: profile)
        firstStore.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            firstStore.invitation != nil && firstStore.isPairing == false
        })
        let savedState = try #require(
            await waitForVaultState(vault, kind: .invitation)
        )
        #expect(savedState.kind == .invitation)

        let restoredRepository = FakeRelationshipRepository()
        let restoredStore = RelationshipStore(
            repository: restoredRepository,
            pairingIntentVault: vault
        )
        await restoredStore.restoreDeferredPairing()
        restoredStore.prepare(for: user, profile: profile)
        #expect(restoredStore.invitation == repository.invitationResult)
        #expect(restoredStore.relationship.status == .invitationPending)

        restoredStore.revokeInvitation()
        #expect(await waitUntil {
            restoredRepository.revokeCalls.count == 1
                && restoredStore.isPairing == false
        })
        #expect(restoredStore.relationship.status == .unpaired)
    }

    @Test("A late callable error cannot undo an observed couple")
    func observedRelationshipWinsLateRedeemError() async {
        let repository = FakeRelationshipRepository()
        repository.shouldSuspendRedeem = true
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        store.prepare(for: user, profile: makeProfile(userID: user.id))

        store.redeemInvitation(code: validInvitationCode)
        #expect(await waitUntil {
            repository.hasSuspendedRedeem && store.isPairing
        })

        let activeRelationship = makeActiveRelationship(
            id: repository.redeemedRelationshipID,
            currentUserID: user.id
        )
        #expect(repository.emit(activeRelationship))
        repository.resumeRedeem(throwing: AppError.offline)

        #expect(await waitUntil { store.isPairing == false })
        #expect(store.relationship == activeRelationship)
        #expect(store.pairingError == nil)
    }

    @Test("Changing accounts clears scoped data and ignores stale observations")
    func changingAccountsClearsContent() async throws {
        let repository = FakeRelationshipRepository()
        let store = RelationshipStore(repository: repository)
        let firstUser = makeUser(id: "user-a")
        let secondUser = makeUser(id: "user-b")
        let firstProfile = makeProfile(userID: firstUser.id)
        let secondProfile = makeProfile(userID: secondUser.id)

        store.prepare(for: firstUser, profile: firstProfile)
        let staleFirstUserObservation = try #require(repository.observer)
        store.sendMessage("Private to A", senderID: firstUser.id)
        store.addMemory(
            caption: "Private memory",
            imageData: Data([0x01]),
            creatorID: firstUser.id
        )
        store.addSharedDayEvent(
            title: "Private event",
            category: .note,
            creatorID: firstUser.id
        )
        store.createInvitation(
            relationshipType: firstProfile.relationshipType,
            relationshipStartDate: firstProfile.relationshipStartDate
        )
        #expect(await waitUntil {
            store.relationship.status == .invitationPending
                && store.isPairing == false
        })

        store.prepare(for: secondUser, profile: secondProfile)

        #expect(store.ownerUserID == secondUser.id)
        #expect(store.relationship.memberIDs == [secondUser.id])
        #expect(store.relationship.status == .unpaired)
        #expect(store.invitation == nil)
        #expect(store.deferredPairingState == .none)
        #expect(store.messages.isEmpty)
        #expect(store.memories.isEmpty)
        #expect(store.sharedDayEvents.isEmpty)
        #expect(repository.observedUserIDs == [firstUser.id, secondUser.id])
        #expect(repository.stopObservationCount >= 2)

        staleFirstUserObservation(
            .relationship(makeActiveRelationship(
                id: "relationship-for-user-a",
                currentUserID: firstUser.id
            ))
        )

        #expect(store.ownerUserID == secondUser.id)
        #expect(store.relationship.status == .unpaired)
        #expect(store.relationship.memberIDs == [secondUser.id])
    }

    @Test("Reset cancels an in-flight create and clears all pairing state")
    func resetCancelsInFlightCreate() async {
        let repository = FakeRelationshipRepository()
        repository.shouldSuspendCreate = true
        let store = RelationshipStore(repository: repository)
        let user = makeUser(id: "user-a")
        let profile = makeProfile(userID: user.id)
        store.prepare(for: user, profile: profile)

        store.createInvitation(
            relationshipType: profile.relationshipType,
            relationshipStartDate: profile.relationshipStartDate
        )
        #expect(await waitUntil {
            repository.hasSuspendedCreate && store.isPairing
        })

        store.reset()
        repository.resumeCreate()
        await drainEnqueuedTasks()

        #expect(store.ownerUserID == nil)
        #expect(store.relationship.status == .unpaired)
        #expect(store.relationship.memberIDs.isEmpty)
        #expect(store.invitation == nil)
        #expect(store.deferredPairingState == .none)
        #expect(store.isPairing == false)
        #expect(store.pairingError == nil)
        #expect(repository.stopObservationCount >= 2)
    }

    @Test("Blank messages are rejected")
    func blankMessagesAreRejected() {
        let store = RelationshipStore(repository: FakeRelationshipRepository())

        store.sendMessage("   \n", senderID: "user")

        #expect(store.messages.isEmpty)
    }

    private var relationshipStartDate: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private var validInvitationCode: String {
        String(repeating: "a", count: 40)
            + "."
            + String(repeating: "B", count: 43)
    }

    private func makeUser(id: String) -> AuthenticatedUser {
        AuthenticatedUser(id: id, displayName: id, email: nil)
    }

    private func makeProfile(
        userID: String,
        relationshipType: RelationshipType = .longDistance,
        relationshipStartDate: Date? = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> UserProfile {
        UserProfile(
            userID: userID,
            displayName: userID,
            dateOfBirth: Date(timeIntervalSince1970: 631_152_000),
            countryCode: "GB",
            timeZoneIdentifier: "Europe/London",
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate,
            gender: .female
        )
    }

    private func makeActiveRelationship(
        id: String,
        currentUserID: String
    ) -> RelationshipSummary {
        RelationshipSummary(
            id: id,
            memberIDs: [currentUserID, "partner"],
            partnerName: nil,
            status: .active,
            startDate: relationshipStartDate,
            inviteCode: nil
        )
    }

    private func waitUntil(
        attempts: Int = 200,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<attempts {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }

    private func drainEnqueuedTasks() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private func waitForVaultState(
        _ vault: FakePairingIntentVault,
        kind: StoredPairingState.Kind,
        attempts: Int = 200
    ) async -> StoredPairingState? {
        for _ in 0..<attempts {
            if let state = await vault.snapshot(), state.kind == kind {
                return state
            }
            await Task.yield()
        }
        return await vault.snapshot()
    }
}

@MainActor
private final class FakeRelationshipRepository: RelationshipRepository {
    struct CreateCall: Equatable {
        let relationshipType: RelationshipType
        let relationshipStartDate: Date?
    }

    let invitationResult = PairingInvitation(
        id: String(repeating: "a", count: 40),
        code: String(repeating: "a", count: 40)
            + "."
            + String(repeating: "B", count: 43),
        expiresAt: Date(timeIntervalSince1970: 4_000_000_000)
    )
    let redeemedRelationshipID = "relationship-redeemed"

    private(set) var createCalls: [CreateCall] = []
    private(set) var revokeCalls: [String] = []
    private(set) var redeemCalls: [String] = []
    private(set) var createIdempotencyKeys: [String] = []
    private(set) var revokeIdempotencyKeys: [String] = []
    private(set) var redeemIdempotencyKeys: [String] = []
    private(set) var observedUserIDs: [String] = []
    private(set) var stopObservationCount = 0
    private(set) var observer:
        (@MainActor @Sendable (RelationshipObservation) -> Void)?

    var shouldSuspendCreate = false
    var createFailuresRemaining = 0
    var revokeFailuresRemaining = 0
    var redeemFailuresRemaining = 0
    private var createContinuation:
        CheckedContinuation<PairingInvitation, any Error>?
    var shouldSuspendRedeem = false
    private var redeemContinuation:
        CheckedContinuation<String, any Error>?

    var hasSuspendedCreate: Bool {
        createContinuation != nil
    }

    var hasSuspendedRedeem: Bool {
        redeemContinuation != nil
    }

    func createInvitation(
        relationshipType: RelationshipType,
        relationshipStartDate: Date?,
        idempotencyKey: String
    ) async throws -> PairingInvitation {
        createIdempotencyKeys.append(idempotencyKey)
        createCalls.append(
            CreateCall(
                relationshipType: relationshipType,
                relationshipStartDate: relationshipStartDate
            )
        )
        if createFailuresRemaining > 0 {
            createFailuresRemaining -= 1
            throw AppError.offline
        }
        guard shouldSuspendCreate else {
            return invitationResult
        }
        return try await withCheckedThrowingContinuation { continuation in
            createContinuation = continuation
        }
    }

    func revokeInvitation(id: String, idempotencyKey: String) async throws {
        revokeCalls.append(id)
        revokeIdempotencyKeys.append(idempotencyKey)
        if revokeFailuresRemaining > 0 {
            revokeFailuresRemaining -= 1
            throw AppError.offline
        }
    }

    func redeemInvitation(code: String, idempotencyKey: String) async throws -> String {
        redeemCalls.append(code)
        redeemIdempotencyKeys.append(idempotencyKey)
        if redeemFailuresRemaining > 0 {
            redeemFailuresRemaining -= 1
            throw AppError.offline
        }
        if shouldSuspendRedeem {
            return try await withCheckedThrowingContinuation { continuation in
                redeemContinuation = continuation
            }
        }
        return redeemedRelationshipID
    }

    func startObservingRelationship(
        for userID: String,
        onChange: @escaping @MainActor @Sendable (RelationshipObservation) -> Void
    ) {
        observedUserIDs.append(userID)
        observer = onChange
    }

    func stopObservingRelationship() {
        stopObservationCount += 1
        observer = nil
    }

    @discardableResult
    func emit(_ relationship: RelationshipSummary?) -> Bool {
        guard let observer else { return false }
        if let relationship {
            observer(.relationship(relationship))
        } else {
            observer(.unpaired)
        }
        return true
    }

    @discardableResult
    func emitObservation(_ observation: RelationshipObservation) -> Bool {
        guard let observer else { return false }
        observer(observation)
        return true
    }

    func resumeCreate() {
        let continuation = createContinuation
        createContinuation = nil
        shouldSuspendCreate = false
        continuation?.resume(returning: invitationResult)
    }

    func resumeRedeem(returning relationshipID: String) {
        let continuation = redeemContinuation
        redeemContinuation = nil
        shouldSuspendRedeem = false
        continuation?.resume(returning: relationshipID)
    }

    func resumeRedeem(throwing error: any Error) {
        let continuation = redeemContinuation
        redeemContinuation = nil
        shouldSuspendRedeem = false
        continuation?.resume(throwing: error)
    }
}

private actor FakePairingIntentVault: PairingIntentVault {
    private var state: StoredPairingState?

    func load() async throws -> StoredPairingState? {
        state
    }

    func save(_ state: StoredPairingState) async throws {
        self.state = state
    }

    func delete() async throws {
        state = nil
    }

    func snapshot() -> StoredPairingState? {
        state
    }
}
