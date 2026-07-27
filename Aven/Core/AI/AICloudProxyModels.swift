import Foundation

nonisolated enum AICloudRequestScope: String, Codable, Sendable {
    case privateOwner
    case sharedRelationship
}

nonisolated enum AICloudContextVisibility: String, Codable, Sendable {
    case authorizedPrivate
    case authorizedShared
}

nonisolated struct AICloudContextItem: Equatable, Codable, Sendable {
    let category: AIContentCategory
    let source: AIMemorySource
    let visibility: AICloudContextVisibility
    let content: String
    let language: AIOutputLanguage
    let isUserEdited: Bool
}

/// Bounded, minimized payload for an authenticated server-side AI proxy.
///
/// The authenticated user is derived from the transport. Owner IDs, member
/// lists, embedding references, confidence values, local source IDs, and
/// deletion metadata are intentionally not serialized into this payload.
nonisolated struct AICloudProxyRequest: Equatable, Codable, Sendable {
    let requestID: UUID
    let relationshipID: String?
    let scope: AICloudRequestScope
    let requiresMutualConsent: Bool
    let task: AITask
    let language: AIOutputLanguage
    let tone: AITone
    let context: [AICloudContextItem]

    init(validatedRequest request: AIRequest) {
        let cloudScope: AICloudRequestScope
        let cloudVisibility: AICloudContextVisibility
        let requiresMutualConsent: Bool

        switch request.scope {
        case .privateOwner:
            cloudScope = .privateOwner
            cloudVisibility = .authorizedPrivate
            requiresMutualConsent = false
        case .sharedRelationship:
            cloudScope = .sharedRelationship
            cloudVisibility = .authorizedShared
            requiresMutualConsent = true
        }

        requestID = request.id
        relationshipID = request.scope.relationshipID
        scope = cloudScope
        self.requiresMutualConsent = requiresMutualConsent
        task = request.task
        language = request.language
        tone = request.tone
        context = request.context.map { entry in
            AICloudContextItem(
                category: entry.category,
                source: entry.source,
                visibility: cloudVisibility,
                content: entry.value.trimmingCharacters(in: .whitespacesAndNewlines),
                language: entry.localization.language,
                isUserEdited: entry.localization.isUserEdited
            )
        }
    }
}

nonisolated struct AICloudProxyResponse: Equatable, Codable, Sendable {
    let requestID: UUID
    let responseID: String
    let content: String
}
