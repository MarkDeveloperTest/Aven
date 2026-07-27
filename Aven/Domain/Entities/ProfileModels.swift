import Foundation

nonisolated enum RelationshipType: String, CaseIterable, Identifiable, Codable, Sendable {
    case dating
    case longDistance
    case engaged
    case married
    case unspecified

    var id: String { rawValue }

    var localizedResource: LocalizedStringResource {
        switch self {
        case .dating: "relationship.type.dating"
        case .longDistance: "relationship.type.long_distance"
        case .engaged: "relationship.type.engaged"
        case .married: "relationship.type.married"
        case .unspecified: "relationship.type.unspecified"
        }
    }
}

nonisolated struct UserProfile: Equatable, Codable, Sendable {
    let userID: String
    var displayName: String
    var dateOfBirth: Date
    var countryCode: String
    var timeZoneIdentifier: String
    var relationshipType: RelationshipType
    var relationshipStartDate: Date?
}
