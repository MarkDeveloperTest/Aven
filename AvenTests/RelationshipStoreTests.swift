import Testing
@testable import Aven

@Suite("Relationship store")
@MainActor
struct RelationshipStoreTests {
    @Test("Invitation can be created and revoked")
    func invitationLifecycle() {
        let store = RelationshipStore()

        store.createInvitation()

        #expect(store.relationship.status == .invitationPending)
        #expect(store.relationship.inviteCode?.count == 6)

        store.revokeInvitation()

        #expect(store.relationship.status == .unpaired)
        #expect(store.relationship.inviteCode == nil)
    }

    @Test("Blank messages are rejected")
    func blankMessagesAreRejected() {
        let store = RelationshipStore()

        store.sendMessage("   \n", senderID: "user")

        #expect(store.messages.isEmpty)
    }

    @Test("Changing accounts clears relationship-scoped content")
    func changingAccountsClearsContent() {
        let store = RelationshipStore()
        let firstUser = AuthenticatedUser(
            id: "user-a",
            displayName: "A",
            email: nil
        )
        let secondUser = AuthenticatedUser(
            id: "user-b",
            displayName: "B",
            email: nil
        )

        store.prepare(for: firstUser, profile: nil)
        store.sendMessage("Private to A", senderID: firstUser.id)
        store.prepare(for: secondUser, profile: nil)

        #expect(store.ownerUserID == secondUser.id)
        #expect(store.relationship.memberIDs == [secondUser.id])
        #expect(store.messages.isEmpty)
        #expect(store.memories.isEmpty)
        #expect(store.sharedDayEvents.isEmpty)
    }
}
