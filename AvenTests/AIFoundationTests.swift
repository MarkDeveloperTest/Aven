import Foundation
import Testing
@testable import Aven

@Suite("AI consent and visibility policy")
struct AIConsentPolicyTests {
    @Test("Master consent stops a request before routing")
    func masterConsentStopsBeforeRouting() async {
        let model = RecordingLanguageModel()
        let router = RecordingRouter(model: model)
        let service = AIService(router: router)
        let request = makeRequest(
            consent: AIConsentSnapshot(
                masterAI: .revoked,
                privateAI: .granted,
                cloudAI: .granted,
                onDeviceOnly: false,
                sharedAIConsentingUserIDs: [],
                allowedCategories: []
            )
        )

        await #expect(throws: AIError.masterConsentRequired) {
            try await service.generateDraft(for: request)
        }
        #expect(await router.invocationCount() == 0)
        #expect(await model.generationCount() == 0)
    }

    @Test("Shared analysis requires consent from every relationship member")
    func sharedAnalysisRequiresMutualConsent() async {
        let consent = AIConsentSnapshot(
            masterAI: .granted,
            privateAI: .granted,
            cloudAI: .notRequested,
            onDeviceOnly: true,
            sharedAIConsentingUserIDs: ["user-a"],
            allowedCategories: []
        )
        let request = makeRequest(
            requesterID: "user-a",
            scope: .sharedRelationship(
                id: "relationship-1",
                memberIDs: ["user-a", "user-b"]
            ),
            consent: consent
        )

        #expect(throws: AIError.sharedAIConsentRequired) {
            try AIContextPolicy().validate(request)
        }
    }

    @Test("Private AI memory cannot enter a shared relationship request")
    func privateMemoryCannotEnterSharedRequest() {
        let consent = AIConsentSnapshot(
            masterAI: .granted,
            privateAI: .granted,
            cloudAI: .notRequested,
            onDeviceOnly: true,
            sharedAIConsentingUserIDs: ["user-a", "user-b"],
            allowedCategories: [.messages]
        )
        let privateEntry = makeMemory(
            ownerID: "user-a",
            relationshipID: "relationship-1",
            visibility: .availableToAIPrivately
        )
        let request = makeRequest(
            requesterID: "user-a",
            scope: .sharedRelationship(
                id: "relationship-1",
                memberIDs: ["user-a", "user-b"]
            ),
            consent: consent,
            context: [privateEntry]
        )

        #expect(throws: AIError.contextNotAuthorized) {
            try AIContextPolicy().validate(request)
        }
    }

    @Test("Expired memory is rejected even when its category and visibility are allowed")
    func expiredMemoryIsRejected() {
        let now = Date(timeIntervalSince1970: 2_000)
        let entry = makeMemory(
            expiresAt: Date(timeIntervalSince1970: 1_999)
        )
        let request = makeRequest(
            consent: privateConsent(),
            context: [entry]
        )

        #expect(throws: AIError.contextExpired) {
            try AIContextPolicy(now: { now }).validate(request)
        }
    }
}

@Suite("AI provider routing")
struct AIProviderRoutingTests {
    @Test("Available on-device provider is preferred")
    func onDeviceProviderIsPreferred() async throws {
        let onDevice = RecordingLanguageModel(
            identifier: .appleFoundationModels,
            executionEnvironment: .onDevice
        )
        let cloud = RecordingLanguageModel(
            identifier: .secureCloudProxy,
            executionEnvironment: .secureCloudProxy
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .granted, onDeviceOnly: false)
        )
        let router = DefaultAIProviderRouter(
            onDeviceProvider: onDevice,
            cloudProvider: cloud
        )

        let selected = try await router.provider(for: request)

        #expect(selected.identifier == .appleFoundationModels)
        #expect(await cloud.availabilityCount() == 0)
    }

    @Test("On-device-only mode never falls back to cloud")
    func onDeviceOnlyNeverFallsBackToCloud() async {
        let unavailable = UnavailableOnDeviceLanguageModel(reason: .deviceUnsupported)
        let cloud = RecordingLanguageModel(
            identifier: .secureCloudProxy,
            executionEnvironment: .secureCloudProxy
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .granted, onDeviceOnly: true)
        )
        let router = DefaultAIProviderRouter(
            onDeviceProvider: unavailable,
            cloudProvider: cloud
        )

        await #expect(throws: AIError.providerUnavailable(.deviceUnsupported)) {
            try await router.provider(for: request)
        }
        #expect(await cloud.availabilityCount() == 0)
    }

    @Test("Authorized cloud provider is used when on-device generation is unavailable")
    func authorizedCloudFallback() async throws {
        let unavailable = UnavailableOnDeviceLanguageModel(reason: .deviceUnsupported)
        let cloud = RecordingLanguageModel(
            identifier: .secureCloudProxy,
            executionEnvironment: .secureCloudProxy
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .granted, onDeviceOnly: false)
        )
        let router = DefaultAIProviderRouter(
            onDeviceProvider: unavailable,
            cloudProvider: cloud
        )

        let selected = try await router.provider(for: request)

        #expect(selected.identifier == .secureCloudProxy)
        #expect(await cloud.availabilityCount() == 1)
    }

    @Test("Cloud fallback requires explicit cloud consent")
    func cloudFallbackRequiresConsent() async {
        let unavailable = UnavailableOnDeviceLanguageModel(reason: .deviceUnsupported)
        let cloud = RecordingLanguageModel(
            identifier: .secureCloudProxy,
            executionEnvironment: .secureCloudProxy
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .denied, onDeviceOnly: false)
        )
        let router = DefaultAIProviderRouter(
            onDeviceProvider: unavailable,
            cloudProvider: cloud
        )

        await #expect(throws: AIError.cloudAIConsentRequired) {
            try await router.provider(for: request)
        }
        #expect(await cloud.availabilityCount() == 0)
    }
}

@Suite("AI service and cloud proxy")
struct AIServiceTests {
    @Test("Responses remain labeled private drafts requiring explicit confirmation")
    func responseIsAlwaysAReviewableDraft() async throws {
        let responseDate = Date(timeIntervalSince1970: 10_000)
        let responseID = UUID()
        let model = RecordingLanguageModel(content: "  A considerate draft.  ")
        let service = AIService(
            router: RecordingRouter(model: model),
            now: { responseDate },
            makeID: { responseID }
        )
        let request = makeRequest(consent: privateConsent())

        let response = try await service.generateDraft(for: request)

        #expect(response.id == responseID)
        #expect(response.requestID == request.id)
        #expect(response.generatedAt == responseDate)
        #expect(response.draftText == "A considerate draft.")
        #expect(response.outputKind == .aiGeneratedDraft)
        #expect(response.visibility == .privateToRequesterUntilExplicitlyShared)
        #expect(response.deliveryRequirement == .explicitUserConfirmation)
        #expect(response.availableActions == [.edit, .dismiss, .regenerate, .report])
    }

    @Test("Cloud payload removes local owner and embedding identifiers")
    func cloudPayloadMinimizesIdentifiers() async throws {
        let client = RecordingCloudProxyClient()
        let cloud = CloudProxyLanguageModel(client: client)
        let service = AIService(
            router: DefaultAIProviderRouter(
                onDeviceProvider: nil,
                cloudProvider: cloud
            )
        )
        let memory = makeMemory(
            ownerID: "owner-secret-identifier",
            embeddingReference: "embedding-secret-reference"
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .granted, onDeviceOnly: false),
            context: [memory]
        )

        _ = try await service.generateDraft(for: request)
        let cloudRequest = try #require(await client.lastRequest())
        let encoded = try JSONEncoder().encode(cloudRequest)
        let payload = String(decoding: encoded, as: UTF8.self)

        #expect(payload.contains("owner-secret-identifier") == false)
        #expect(payload.contains("embedding-secret-reference") == false)
        #expect(cloudRequest.relationshipID == nil)
        #expect(cloudRequest.scope == .privateOwner)
        #expect(cloudRequest.requiresMutualConsent == false)
    }

    @Test("Unexpected provider errors become a sanitized domain error")
    func providerErrorsAreSanitized() async {
        let client = RecordingCloudProxyClient(mode: .sensitiveFailure)
        let cloud = CloudProxyLanguageModel(client: client)
        let service = AIService(
            router: DefaultAIProviderRouter(
                onDeviceProvider: nil,
                cloudProvider: cloud
            )
        )
        let request = makeRequest(
            consent: privateConsent(cloudAI: .granted, onDeviceOnly: false)
        )

        await #expect(throws: AIError.providerFailure) {
            try await service.generateDraft(for: request)
        }
    }

    @Test("Cancellation remains cooperative and is not rewritten as a provider failure")
    func cancellationIsPreserved() async {
        let model = RecordingLanguageModel(mode: .cancel)
        let service = AIService(router: RecordingRouter(model: model))

        await #expect(throws: CancellationError.self) {
            try await service.generateDraft(
                for: makeRequest(consent: privateConsent())
            )
        }
    }

    @Test("Deterministic provider produces a Ukrainian draft without cloud access")
    func deterministicUkrainianDraft() async throws {
        let model = DeterministicMockLanguageModel()
        let service = AIService(router: RecordingRouter(model: model))
        let request = makeRequest(
            task: .neutralTrendExplanation,
            language: .ukrainian,
            consent: privateConsent()
        )

        let response = try await service.generateDraft(for: request)

        #expect(response.providerIdentifier == .deterministicMock)
        #expect(response.draftText.contains("Контекст обмежений"))
    }
}

private func privateConsent(
    cloudAI: AIConsentState = .notRequested,
    onDeviceOnly: Bool = true,
    allowedCategories: Set<AIContentCategory> = [.messages]
) -> AIConsentSnapshot {
    AIConsentSnapshot(
        masterAI: .granted,
        privateAI: .granted,
        cloudAI: cloudAI,
        onDeviceOnly: onDeviceOnly,
        sharedAIConsentingUserIDs: [],
        allowedCategories: allowedCategories
    )
}

private func makeRequest(
    requesterID: String = "user-a",
    task: AITask = .conversationPrompt,
    scope: AIRequestScope = .privateOwner(userID: "user-a"),
    language: AIOutputLanguage = .english,
    consent: AIConsentSnapshot,
    context: [AIMemoryEntry] = []
) -> AIRequest {
    AIRequest(
        id: UUID(),
        requesterID: requesterID,
        task: task,
        scope: scope,
        language: language,
        tone: .neutral,
        consent: consent,
        context: context
    )
}

private func makeMemory(
    ownerID: String = "user-a",
    relationshipID: String? = nil,
    visibility: AIMemoryVisibility = .availableToAIPrivately,
    expiresAt: Date? = nil,
    embeddingReference: String? = nil
) -> AIMemoryEntry {
    AIMemoryEntry(
        id: UUID(),
        ownerID: ownerID,
        relationshipID: relationshipID,
        category: .messages,
        source: .selectedMessage,
        visibility: visibility,
        consentState: .granted,
        aiUsePermission: .granted,
        createdAt: Date(timeIntervalSince1970: 1_000),
        expiresAt: expiresAt,
        confidence: 1,
        value: "Content explicitly selected for this request.",
        deletionState: .active,
        embeddingReference: embeddingReference,
        localization: AILocalizationMetadata(
            language: .english,
            sourceLanguage: nil,
            isUserEdited: true
        )
    )
}

private actor RecordingRouter: AIProviderRouter {
    private let model: any RelationshipLanguageModel
    private var count = 0

    init(model: any RelationshipLanguageModel) {
        self.model = model
    }

    func provider(for request: AIRequest) async throws -> any RelationshipLanguageModel {
        count += 1
        return model
    }

    func invocationCount() -> Int {
        count
    }
}

private actor RecordingLanguageModel: RelationshipLanguageModel {
    enum Mode: Sendable {
        case success
        case cancel
    }

    nonisolated let identifier: AIProviderIdentifier
    nonisolated let capabilities: ModelCapabilities
    private let availabilityValue: AIProviderAvailability
    private let content: String
    private let mode: Mode
    private var availabilityCalls = 0
    private var generationCalls = 0

    init(
        identifier: AIProviderIdentifier = .deterministicMock,
        executionEnvironment: AIExecutionEnvironment = .onDevice,
        availability: AIProviderAvailability = .available,
        content: String = "A draft.",
        mode: Mode = .success
    ) {
        self.identifier = identifier
        self.availabilityValue = availability
        self.content = content
        self.mode = mode
        capabilities = ModelCapabilities(
            supportedTasks: Set(AITask.allCases),
            supportedLanguages: Set(AIOutputLanguage.allCases),
            maximumContextItems: 50,
            supportsStructuredOutput: true,
            executionEnvironment: executionEnvironment
        )
    }

    func availability(for request: AIRequest) async -> AIProviderAvailability {
        availabilityCalls += 1
        return availabilityValue
    }

    func generateDraft(for request: AIRequest) async throws -> AIProviderDraft {
        generationCalls += 1
        switch mode {
        case .success:
            return AIProviderDraft(content: content)
        case .cancel:
            throw CancellationError()
        }
    }

    func availabilityCount() -> Int {
        availabilityCalls
    }

    func generationCount() -> Int {
        generationCalls
    }
}

private actor RecordingCloudProxyClient: AICloudProxyClient {
    enum Mode: Sendable {
        case success
        case sensitiveFailure
    }

    private let mode: Mode
    private var recordedRequest: AICloudProxyRequest?

    init(mode: Mode = .success) {
        self.mode = mode
    }

    func availability() async -> AIProviderAvailability {
        .available
    }

    func generate(request: AICloudProxyRequest) async throws -> AICloudProxyResponse {
        recordedRequest = request
        switch mode {
        case .success:
            return AICloudProxyResponse(
                requestID: request.requestID,
                responseID: "server-response",
                content: "A server-generated draft."
            )
        case .sensitiveFailure:
            throw SensitiveCloudFailure(
                debugDescription: "provider key and private prompt must not escape"
            )
        }
    }

    func lastRequest() -> AICloudProxyRequest? {
        recordedRequest
    }
}

private struct SensitiveCloudFailure: Error, Sendable {
    let debugDescription: String
}
