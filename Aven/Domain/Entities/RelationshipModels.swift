import Foundation

nonisolated enum RelationshipStatus: String, Codable, Sendable {
    case unpaired
    case invitationPending
    case active
    case paused
    case endingRequested
    case ended
    case archived
    case deletionPending
}

nonisolated struct RelationshipSummary: Identifiable, Equatable, Codable, Sendable {
    let id: String
    var memberIDs: [String]
    var partnerName: String?
    var status: RelationshipStatus
    var startDate: Date?
    var inviteCode: String?
}

nonisolated struct Message: Identifiable, Equatable, Sendable {
    nonisolated enum DeliveryState: Sendable {
        case sending
        case sent
        case failed
    }

    let id: UUID
    let senderID: String
    var text: String
    let sentAt: Date
    var deliveryState: DeliveryState
}

nonisolated struct MemoryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let creatorID: String
    var caption: String
    let createdAt: Date
    var imageData: Data?
}

nonisolated struct SharedDayEvent: Identifiable, Equatable, Sendable {
    nonisolated enum Category: String, CaseIterable, Identifiable, Sendable {
        case note
        case mood
        case activity
        case photo

        var id: String { rawValue }

        var localizedResource: LocalizedStringResource {
            switch self {
            case .note: "shared_day.category.note"
            case .mood: "shared_day.category.mood"
            case .activity: "shared_day.category.activity"
            case .photo: "shared_day.category.photo"
            }
        }
    }

    let id: UUID
    let creatorID: String
    var title: String
    let occurredAt: Date
    var category: Category
}

nonisolated struct RelationshipInsight: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let generatedAt: Date
}
