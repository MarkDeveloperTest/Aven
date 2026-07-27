import Foundation
import OSLog

nonisolated enum AILogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.aven",
        category: "ai"
    )

    /// Records only bounded operational metadata. Never pass prompts, memory
    /// values, owner identifiers, relationship identifiers, or raw errors.
    static func generationFailed(
        request: AIRequest,
        provider: AIProviderIdentifier,
        code: String
    ) {
        let providerIdentifier = sanitizedProviderIdentifier(provider)
        logger.error(
            "AI generation failed request=\(redactedRequestID(request.id), privacy: .public) task=\(request.task.rawValue, privacy: .public) provider=\(providerIdentifier, privacy: .public) code=\(code, privacy: .public)"
        )
    }

    private static func redactedRequestID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private static func sanitizedProviderIdentifier(
        _ identifier: AIProviderIdentifier
    ) -> String {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        guard identifier.rawValue.isEmpty == false,
              identifier.rawValue.count <= 64,
              identifier.rawValue.unicodeScalars.allSatisfy(allowed.contains)
        else {
            return "custom-provider"
        }
        return identifier.rawValue
    }
}
