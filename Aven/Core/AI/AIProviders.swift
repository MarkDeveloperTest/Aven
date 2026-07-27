import Foundation

nonisolated struct UnavailableOnDeviceLanguageModel: RelationshipLanguageModel {
    let identifier: AIProviderIdentifier
    let capabilities: ModelCapabilities
    private let reason: AIProviderUnavailabilityReason

    init(
        identifier: AIProviderIdentifier = .appleFoundationModels,
        reason: AIProviderUnavailabilityReason = .integrationNotConfigured
    ) {
        self.identifier = identifier
        self.reason = reason
        capabilities = ModelCapabilities(
            supportedTasks: Set(AITask.allCases),
            supportedLanguages: Set(AIOutputLanguage.allCases),
            maximumContextItems: 24,
            supportsStructuredOutput: true,
            executionEnvironment: .onDevice
        )
    }

    func availability(for request: AIRequest) async -> AIProviderAvailability {
        guard capabilities.supports(request) else {
            return .unavailable(capabilities.unsupportedReason(for: request))
        }
        return .unavailable(reason)
    }

    func generateDraft(for request: AIRequest) async throws -> AIProviderDraft {
        throw AIError.providerUnavailable(reason)
    }
}

/// Deterministic local provider for previews, tests, and explicit development
/// environments. It performs the same consent checks as production adapters
/// and never sends context off device.
nonisolated struct DeterministicMockLanguageModel: RelationshipLanguageModel {
    let identifier: AIProviderIdentifier = .deterministicMock
    let capabilities: ModelCapabilities
    private let contextPolicy: AIContextPolicy

    init(contextPolicy: AIContextPolicy = AIContextPolicy()) {
        self.contextPolicy = contextPolicy
        capabilities = ModelCapabilities(
            supportedTasks: Set(AITask.allCases),
            supportedLanguages: Set(AIOutputLanguage.allCases),
            maximumContextItems: 50,
            supportsStructuredOutput: true,
            executionEnvironment: .onDevice
        )
    }

    func availability(for request: AIRequest) async -> AIProviderAvailability {
        guard capabilities.supports(request) else {
            return .unavailable(capabilities.unsupportedReason(for: request))
        }
        return .available
    }

    func generateDraft(for request: AIRequest) async throws -> AIProviderDraft {
        try Task.checkCancellation()
        try contextPolicy.validate(request)
        guard capabilities.supports(request) else {
            throw AIError.providerUnavailable(capabilities.unsupportedReason(for: request))
        }
        return AIProviderDraft(content: content(for: request))
    }

    private func content(for request: AIRequest) -> String {
        switch (request.language, request.task) {
        case (.english, .conversationPrompt):
            "A possible prompt: What is one small moment from this week that you would enjoy repeating?"
        case (.english, .weeklyActivitySummary):
            "Based only on the items you chose to include, this week shows several moments of shared participation. This is a descriptive summary, not a judgment."
        case (.english, .sharedActivitySuggestion):
            "One option is to choose a short, low-pressure activity you both enjoy and agree on a time together."
        case (.english, .considerateMessageDraft):
            "One possible draft: “Could we choose a calm time to talk? I would like to understand your perspective and share mine.”"
        case (.english, .memoryCaption):
            "A possible caption: A moment we chose to remember together."
        case (.english, .memorySearchSummary):
            "The selected memories include moments you explicitly made available for this private summary."
        case (.english, .neutralTrendExplanation):
            "One possible pattern is a change in shared participation. The context is limited, so this may not reflect either person’s intent."
        case (.english, .connectionTimeSuggestion):
            "A possible next step is to compare the time windows you both chose to share and confirm a convenient time together."

        case (.ukrainian, .conversationPrompt):
            "Можливе запитання: який невеликий момент цього тижня вам хотілося б повторити?"
        case (.ukrainian, .weeklyActivitySummary):
            "Лише на основі вибраних вами даних цього тижня помітно кілька моментів спільної участі. Це описовий підсумок, а не оцінка."
        case (.ukrainian, .sharedActivitySuggestion):
            "Один із варіантів — обрати коротку й невимушену справу, яка подобається вам обом, і разом погодити час."
        case (.ukrainian, .considerateMessageDraft):
            "Один із можливих варіантів: «Чи можемо ми обрати спокійний час для розмови? Я хочу зрозуміти твою думку й поділитися своєю»."
        case (.ukrainian, .memoryCaption):
            "Можливий підпис: момент, який ми вирішили зберегти разом."
        case (.ukrainian, .memorySearchSummary):
            "Вибрані спогади містять моменти, які ви явно дозволили використати для цього приватного підсумку."
        case (.ukrainian, .neutralTrendExplanation):
            "Однією з можливих тенденцій є зміна спільної участі. Контекст обмежений, тому це може не відображати намірів жодної людини."
        case (.ukrainian, .connectionTimeSuggestion):
            "Можливий наступний крок — порівняти проміжки часу, якими ви обоє вирішили поділитися, і разом підтвердити зручний час."
        }
    }
}

nonisolated struct CloudProxyLanguageModel: RelationshipLanguageModel {
    let identifier: AIProviderIdentifier
    let capabilities: ModelCapabilities
    private let client: any AICloudProxyClient
    private let contextPolicy: AIContextPolicy
    private let maximumResponseCharacters: Int

    init(
        identifier: AIProviderIdentifier = .secureCloudProxy,
        client: any AICloudProxyClient,
        contextPolicy: AIContextPolicy = AIContextPolicy(),
        maximumResponseCharacters: Int = 4_000
    ) {
        self.identifier = identifier
        self.client = client
        self.contextPolicy = contextPolicy
        self.maximumResponseCharacters = maximumResponseCharacters
        capabilities = ModelCapabilities(
            supportedTasks: Set(AITask.allCases),
            supportedLanguages: Set(AIOutputLanguage.allCases),
            maximumContextItems: 50,
            supportsStructuredOutput: true,
            executionEnvironment: .secureCloudProxy
        )
    }

    func availability(for request: AIRequest) async -> AIProviderAvailability {
        guard capabilities.supports(request) else {
            return .unavailable(capabilities.unsupportedReason(for: request))
        }
        guard request.consent.onDeviceOnly == false,
              request.consent.cloudAI == .granted
        else {
            return .unavailable(.cloudUseNotAuthorized)
        }
        return await client.availability()
    }

    func generateDraft(for request: AIRequest) async throws -> AIProviderDraft {
        try Task.checkCancellation()
        let validatedRequest = try contextPolicy.validate(request)
        guard request.consent.onDeviceOnly == false,
              request.consent.cloudAI == .granted
        else {
            throw AIError.cloudAIConsentRequired
        }
        guard capabilities.supports(validatedRequest) else {
            throw AIError.providerUnavailable(capabilities.unsupportedReason(for: validatedRequest))
        }

        let availability = await client.availability()
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw AIError.providerUnavailable(reason)
            }
            throw AIError.providerUnavailable(.modelNotReady)
        }

        let response: AICloudProxyResponse
        do {
            response = try await client.generate(
                request: AICloudProxyRequest(validatedRequest: validatedRequest)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AIError {
            throw error
        } catch {
            AILogger.generationFailed(
                request: request,
                provider: identifier,
                code: AIError.providerFailure.sanitizedCode
            )
            throw AIError.providerFailure
        }

        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard response.requestID == request.id,
              response.responseID.isEmpty == false,
              content.isEmpty == false,
              content.count <= maximumResponseCharacters
        else {
            throw AIError.invalidProviderResponse
        }

        return AIProviderDraft(content: content, providerResponseID: response.responseID)
    }
}
