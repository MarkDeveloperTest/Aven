import Foundation

nonisolated struct DefaultAIProviderRouter: AIProviderRouter {
    private let onDeviceProvider: (any RelationshipLanguageModel)?
    private let cloudProvider: (any RelationshipLanguageModel)?
    private let contextPolicy: AIContextPolicy

    init(
        onDeviceProvider: (any RelationshipLanguageModel)?,
        cloudProvider: (any RelationshipLanguageModel)?,
        contextPolicy: AIContextPolicy = AIContextPolicy()
    ) {
        self.onDeviceProvider = onDeviceProvider
        self.cloudProvider = cloudProvider
        self.contextPolicy = contextPolicy
    }

    func provider(for request: AIRequest) async throws -> any RelationshipLanguageModel {
        let validatedRequest = try contextPolicy.validate(request)
        var onDeviceFailure: AIProviderUnavailabilityReason = .integrationNotConfigured

        if let onDeviceProvider {
            if onDeviceProvider.capabilities.supports(validatedRequest) {
                switch await onDeviceProvider.availability(for: validatedRequest) {
                case .available:
                    return onDeviceProvider
                case .unavailable(let reason):
                    onDeviceFailure = reason
                }
            } else {
                onDeviceFailure = onDeviceProvider.capabilities.unsupportedReason(
                    for: validatedRequest
                )
            }
        }

        if validatedRequest.consent.onDeviceOnly {
            throw AIError.providerUnavailable(onDeviceFailure)
        }

        guard validatedRequest.consent.cloudAI == .granted else {
            throw AIError.cloudAIConsentRequired
        }
        guard let cloudProvider else {
            throw AIError.providerUnavailable(.integrationNotConfigured)
        }
        guard cloudProvider.capabilities.supports(validatedRequest) else {
            throw AIError.providerUnavailable(
                cloudProvider.capabilities.unsupportedReason(for: validatedRequest)
            )
        }

        switch await cloudProvider.availability(for: validatedRequest) {
        case .available:
            return cloudProvider
        case .unavailable(let reason):
            throw AIError.providerUnavailable(reason)
        }
    }
}
