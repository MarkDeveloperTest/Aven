import Foundation

nonisolated enum AITask: String, CaseIterable, Codable, Sendable {
    case conversationPrompt
    case weeklyActivitySummary
    case sharedActivitySuggestion
    case considerateMessageDraft
    case memoryCaption
    case memorySearchSummary
    case neutralTrendExplanation
    case connectionTimeSuggestion
}

nonisolated enum AIContentCategory: String, CaseIterable, Codable, Sendable {
    case messages
    case photos
    case captions
    case calendar
    case locationMoments
    case moodHistory
    case sharedDay
    case relationshipInsights
    case voiceJournals
    case goals
    case profilePreferences
}

nonisolated enum AIOutputLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case ukrainian = "uk"
}

nonisolated enum AITone: String, CaseIterable, Codable, Sendable {
    case warmAndRomantic
    case calmAndEmotionallyIntelligent
    case playful
    case direct
    case neutral
}

nonisolated enum AIConsentState: String, Codable, Sendable {
    case notRequested
    case granted
    case denied
    case revoked
}

nonisolated struct AIConsentSnapshot: Equatable, Codable, Sendable {
    let masterAI: AIConsentState
    let privateAI: AIConsentState
    let cloudAI: AIConsentState
    let onDeviceOnly: Bool
    let sharedAIConsentingUserIDs: Set<String>
    let allowedCategories: Set<AIContentCategory>

    static let disabled = AIConsentSnapshot(
        masterAI: .notRequested,
        privateAI: .notRequested,
        cloudAI: .notRequested,
        onDeviceOnly: true,
        sharedAIConsentingUserIDs: [],
        allowedCategories: []
    )
}

nonisolated enum AIRequestScope: Equatable, Codable, Sendable {
    case privateOwner(userID: String)
    case sharedRelationship(id: String, memberIDs: Set<String>)

    var relationshipID: String? {
        switch self {
        case .privateOwner:
            nil
        case .sharedRelationship(let id, _):
            id
        }
    }
}

nonisolated enum AIMemoryVisibility: Equatable, Codable, Sendable {
    case privateToOwner
    case sharedWithPartner
    case availableToAIPrivately
    case availableToSharedAI
    case surpriseUntil(Date)
    case excludedFromAI
}

nonisolated enum AIMemorySource: String, Codable, Sendable {
    case userEntry
    case selectedMessage
    case selectedPhoto
    case caption
    case calendarEvent
    case locationMoment
    case moodCheckIn
    case sharedDay
    case relationshipInsight
    case voiceJournal
    case goal
    case profilePreference
}

nonisolated enum AIMemoryDeletionState: String, Codable, Sendable {
    case active
    case deletionRequested
    case deleted
}

nonisolated struct AILocalizationMetadata: Equatable, Codable, Sendable {
    let language: AIOutputLanguage
    let sourceLanguage: AIOutputLanguage?
    var isUserEdited: Bool
}

/// A visibility- and consent-qualified fact or selected content segment.
///
/// Cloud request mapping intentionally omits `ownerID`, `embeddingReference`,
/// confidence, and source IDs. Those fields exist for local authorization and
/// lifecycle management, not for model prompting.
nonisolated struct AIMemoryEntry: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let ownerID: String
    let relationshipID: String?
    let category: AIContentCategory
    let source: AIMemorySource
    var visibility: AIMemoryVisibility
    var consentState: AIConsentState
    var aiUsePermission: AIConsentState
    let createdAt: Date
    var expiresAt: Date?
    var confidence: Double
    var value: String
    var deletionState: AIMemoryDeletionState
    var embeddingReference: String?
    var localization: AILocalizationMetadata
}

nonisolated struct AIRequest: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let requesterID: String
    let task: AITask
    let scope: AIRequestScope
    let language: AIOutputLanguage
    let tone: AITone
    let consent: AIConsentSnapshot
    let context: [AIMemoryEntry]

    init(
        id: UUID = UUID(),
        requesterID: String,
        task: AITask,
        scope: AIRequestScope,
        language: AIOutputLanguage,
        tone: AITone,
        consent: AIConsentSnapshot,
        context: [AIMemoryEntry]
    ) {
        self.id = id
        self.requesterID = requesterID
        self.task = task
        self.scope = scope
        self.language = language
        self.tone = tone
        self.consent = consent
        self.context = context
    }
}

nonisolated struct AIProviderIdentifier: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let appleFoundationModels = AIProviderIdentifier(rawValue: "apple-foundation-models")
    static let secureCloudProxy = AIProviderIdentifier(rawValue: "secure-cloud-proxy")
    static let firebaseAILogic = AIProviderIdentifier(rawValue: "firebase-ai-logic")
    static let deterministicMock = AIProviderIdentifier(rawValue: "deterministic-mock")
    static let providerRouter = AIProviderIdentifier(rawValue: "provider-router")
}

nonisolated enum AIExecutionEnvironment: String, Codable, Sendable {
    case onDevice
    case privateCloudCompute
    case secureCloudProxy
}

nonisolated struct ModelCapabilities: Equatable, Sendable {
    let supportedTasks: Set<AITask>
    let supportedLanguages: Set<AIOutputLanguage>
    let maximumContextItems: Int
    let supportsStructuredOutput: Bool
    let executionEnvironment: AIExecutionEnvironment

    func supports(_ request: AIRequest) -> Bool {
        supportedTasks.contains(request.task)
            && supportedLanguages.contains(request.language)
            && request.context.count <= maximumContextItems
    }

    func unsupportedReason(for request: AIRequest) -> AIProviderUnavailabilityReason {
        if supportedTasks.contains(request.task) == false {
            return .taskUnsupported
        }
        if supportedLanguages.contains(request.language) == false {
            return .languageUnsupported
        }
        return .contextLimitExceeded
    }
}

nonisolated enum AIProviderUnavailabilityReason: String, Codable, Sendable {
    case integrationNotConfigured
    case deviceUnsupported
    case modelNotReady
    case languageUnsupported
    case taskUnsupported
    case contextLimitExceeded
    case networkUnavailable
    case cloudUseNotAuthorized
}

nonisolated enum AIProviderAvailability: Equatable, Sendable {
    case available
    case unavailable(AIProviderUnavailabilityReason)
}

nonisolated struct AIProviderDraft: Equatable, Sendable {
    let content: String
    let providerResponseID: String?

    init(content: String, providerResponseID: String? = nil) {
        self.content = content
        self.providerResponseID = providerResponseID
    }
}

nonisolated enum AIDraftAction: String, CaseIterable, Codable, Sendable {
    case edit
    case dismiss
    case regenerate
    case report
}

nonisolated enum AIOutputKind: String, Codable, Sendable {
    case aiGeneratedDraft
}

nonisolated enum AIDeliveryRequirement: String, Codable, Sendable {
    case explicitUserConfirmation
}

nonisolated enum AIOutputVisibility: String, Codable, Sendable {
    case privateToRequesterUntilExplicitlyShared
}

/// The only user-facing AI output type.
///
/// It deliberately has no send operation or `Message` conversion. Feature code
/// may copy `draftText` into an editor, but sending remains a separate,
/// explicit user action owned by the messaging feature.
nonisolated struct AIResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let requestID: UUID
    let task: AITask
    let providerIdentifier: AIProviderIdentifier
    let generatedAt: Date
    var draftText: String

    var outputKind: AIOutputKind { .aiGeneratedDraft }
    var deliveryRequirement: AIDeliveryRequirement { .explicitUserConfirmation }
    var visibility: AIOutputVisibility { .privateToRequesterUntilExplicitlyShared }
    var availableActions: Set<AIDraftAction> { Set(AIDraftAction.allCases) }
}

nonisolated enum AIError: Error, Equatable, Sendable {
    case masterConsentRequired
    case privateAIConsentRequired
    case sharedAIConsentRequired
    case cloudAIConsentRequired
    case categoryNotAuthorized(AIContentCategory)
    case contextNotAuthorized
    case contextExpired
    case invalidRequest
    case providerUnavailable(AIProviderUnavailabilityReason)
    case providerFailure
    case invalidProviderResponse

    var sanitizedCode: String {
        switch self {
        case .masterConsentRequired: "master_consent_required"
        case .privateAIConsentRequired: "private_ai_consent_required"
        case .sharedAIConsentRequired: "shared_ai_consent_required"
        case .cloudAIConsentRequired: "cloud_ai_consent_required"
        case .categoryNotAuthorized: "category_not_authorized"
        case .contextNotAuthorized: "context_not_authorized"
        case .contextExpired: "context_expired"
        case .invalidRequest: "invalid_request"
        case .providerUnavailable: "provider_unavailable"
        case .providerFailure: "provider_failure"
        case .invalidProviderResponse: "invalid_provider_response"
        }
    }
}
