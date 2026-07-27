import Foundation

nonisolated struct AIService: Sendable {
    private let router: any AIProviderRouter
    private let contextPolicy: AIContextPolicy
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let maximumResponseCharacters: Int

    init(
        router: any AIProviderRouter,
        contextPolicy: AIContextPolicy = AIContextPolicy(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        maximumResponseCharacters: Int = 4_000
    ) {
        self.router = router
        self.contextPolicy = contextPolicy
        self.now = now
        self.makeID = makeID
        self.maximumResponseCharacters = maximumResponseCharacters
    }

    func generateDraft(for request: AIRequest) async throws -> AIResponse {
        try Task.checkCancellation()
        let validatedRequest = try contextPolicy.validate(request)

        let provider: any RelationshipLanguageModel
        do {
            provider = try await router.provider(for: validatedRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AIError {
            throw error
        } catch {
            AILogger.generationFailed(
                request: request,
                provider: .providerRouter,
                code: AIError.providerFailure.sanitizedCode
            )
            throw AIError.providerFailure
        }

        guard provider.capabilities.supports(validatedRequest) else {
            throw AIError.providerUnavailable(
                provider.capabilities.unsupportedReason(for: validatedRequest)
            )
        }

        switch await provider.availability(for: validatedRequest) {
        case .available:
            break
        case .unavailable(let reason):
            throw AIError.providerUnavailable(reason)
        }

        let providerDraft: AIProviderDraft
        do {
            providerDraft = try await provider.generateDraft(for: validatedRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AIError {
            throw error
        } catch {
            AILogger.generationFailed(
                request: request,
                provider: provider.identifier,
                code: AIError.providerFailure.sanitizedCode
            )
            throw AIError.providerFailure
        }

        try Task.checkCancellation()
        let content = providerDraft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.isEmpty == false, content.count <= maximumResponseCharacters else {
            throw AIError.invalidProviderResponse
        }

        return AIResponse(
            id: makeID(),
            requestID: request.id,
            task: request.task,
            providerIdentifier: provider.identifier,
            generatedAt: now(),
            draftText: content
        )
    }
}
