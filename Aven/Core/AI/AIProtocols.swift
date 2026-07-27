import Foundation

nonisolated protocol RelationshipLanguageModel: Sendable {
    var identifier: AIProviderIdentifier { get }
    var capabilities: ModelCapabilities { get }

    func availability(for request: AIRequest) async -> AIProviderAvailability
    func generateDraft(for request: AIRequest) async throws -> AIProviderDraft
}

nonisolated protocol AIProviderRouter: Sendable {
    func provider(for request: AIRequest) async throws -> any RelationshipLanguageModel
}

/// Integration boundary for an authenticated callable HTTPS function.
///
/// Implementations must obtain the user from the authenticated transport,
/// include App Check, and leave provider credentials on the server. The server
/// remains responsible for relationship membership, current consent, rate
/// limits, bounded context, typed response validation, and safe cost tracking.
nonisolated protocol AICloudProxyClient: Sendable {
    func availability() async -> AIProviderAvailability
    func generate(request: AICloudProxyRequest) async throws -> AICloudProxyResponse
}
