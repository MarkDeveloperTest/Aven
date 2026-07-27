import Foundation

nonisolated struct AIContextPolicy: Sendable {
    private let now: @Sendable () -> Date
    private let maximumContextItems: Int
    private let maximumItemCharacters: Int
    private let maximumTotalCharacters: Int

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        maximumContextItems: Int = 50,
        maximumItemCharacters: Int = 4_000,
        maximumTotalCharacters: Int = 12_000
    ) {
        self.now = now
        self.maximumContextItems = maximumContextItems
        self.maximumItemCharacters = maximumItemCharacters
        self.maximumTotalCharacters = maximumTotalCharacters
    }

    @discardableResult
    func validate(_ request: AIRequest) throws -> AIRequest {
        guard request.requesterID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              request.context.count <= maximumContextItems
        else {
            throw AIError.invalidRequest
        }

        guard request.consent.masterAI == .granted else {
            throw AIError.masterConsentRequired
        }

        try validateScope(for: request)

        var totalCharacters = 0
        let currentDate = now()

        for entry in request.context {
            guard request.consent.allowedCategories.contains(entry.category) else {
                throw AIError.categoryNotAuthorized(entry.category)
            }
            guard entry.consentState == .granted,
                  entry.aiUsePermission == .granted,
                  entry.deletionState == .active,
                  (0 ... 1).contains(entry.confidence)
            else {
                throw AIError.contextNotAuthorized
            }
            if let expiresAt = entry.expiresAt, expiresAt <= currentDate {
                throw AIError.contextExpired
            }

            let trimmedValue = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedValue.isEmpty == false,
                  trimmedValue.count <= maximumItemCharacters
            else {
                throw AIError.invalidRequest
            }
            totalCharacters += trimmedValue.count
            guard totalCharacters <= maximumTotalCharacters else {
                throw AIError.invalidRequest
            }

            try validate(entry, for: request)
        }

        return request
    }

    private func validateScope(for request: AIRequest) throws {
        switch request.scope {
        case .privateOwner(let userID):
            guard request.consent.privateAI == .granted else {
                throw AIError.privateAIConsentRequired
            }
            guard userID.isEmpty == false, userID == request.requesterID else {
                throw AIError.contextNotAuthorized
            }

        case .sharedRelationship(let relationshipID, let memberIDs):
            guard relationshipID.isEmpty == false,
                  memberIDs.isEmpty == false,
                  memberIDs.contains(request.requesterID)
            else {
                throw AIError.contextNotAuthorized
            }
            guard request.consent.sharedAIConsentingUserIDs.isSuperset(of: memberIDs) else {
                throw AIError.sharedAIConsentRequired
            }
        }
    }

    private func validate(_ entry: AIMemoryEntry, for request: AIRequest) throws {
        switch request.scope {
        case .privateOwner(let userID):
            guard entry.ownerID == userID,
                  entry.visibility == .availableToAIPrivately
            else {
                throw AIError.contextNotAuthorized
            }

        case .sharedRelationship(let relationshipID, let memberIDs):
            guard entry.relationshipID == relationshipID,
                  memberIDs.contains(entry.ownerID),
                  entry.visibility == .availableToSharedAI
            else {
                throw AIError.contextNotAuthorized
            }
        }
    }
}
