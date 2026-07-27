import Foundation
import Observation

@MainActor
@Observable
final class RelationshipStore {
    private(set) var ownerUserID: String?

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

    func prepare(
        for user: AuthenticatedUser,
        profile: UserProfile?,
        locale: Locale? = nil
    ) {
        if ownerUserID != user.id {
            reset()
            ownerUserID = user.id
            relationship.memberIDs = [user.id]
            relationship.startDate = profile?.relationshipStartDate
        }

        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") else {
            return
        }
        activateDemoRelationship(currentUserID: user.id, locale: locale)
    }

    func createInvitation() {
        guard relationship.status == .unpaired else { return }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        relationship.inviteCode = String((0..<6).compactMap { _ in alphabet.randomElement() })
        relationship.status = .invitationPending
    }

    func revokeInvitation() {
        relationship.inviteCode = nil
        relationship.status = .unpaired
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

    func endRelationship() {
        relationship.status = .ended
        relationship.inviteCode = nil
    }

    func reset() {
        ownerUserID = nil
        relationship = RelationshipSummary(
            id: "local-unpaired",
            memberIDs: [],
            partnerName: nil,
            status: .unpaired,
            startDate: nil,
            inviteCode: nil
        )
        messages.removeAll(keepingCapacity: false)
        memories.removeAll(keepingCapacity: false)
        sharedDayEvents.removeAll(keepingCapacity: false)
    }
}
