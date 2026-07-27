import Foundation

struct AvenWidgetSnapshot: Codable, Equatable, Sendable {
    enum PairingState: String, Codable, Sendable {
        case paired
        case unpaired
    }

    let pairingState: PairingState
    let isPrivacyLocked: Bool
    let partnerDisplayName: String?
    let daysTogether: Int?
    let updatedAt: Date

    static let locked = AvenWidgetSnapshot(
        pairingState: .unpaired,
        isPrivacyLocked: true,
        partnerDisplayName: nil,
        daysTogether: nil,
        updatedAt: .now
    )

    func presentation(allowsSensitiveContent: Bool) -> AvenWidgetPresentation {
        guard allowsSensitiveContent, !isPrivacyLocked else {
            return .private
        }

        guard pairingState == .paired else {
            return .unpaired
        }

        let sanitizedName = partnerDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(40)

        return .shared(
            partnerDisplayName: sanitizedName.map(String.init),
            daysTogether: daysTogether.map { max(0, $0) }
        )
    }
}

enum AvenWidgetPresentation: Equatable, Sendable {
    case `private`
    case unpaired
    case shared(partnerDisplayName: String?, daysTogether: Int?)
}

enum AvenWidgetStateStore {
    static let widgetKind = "AvenPrivacyWidget"

    private static let snapshotKey = "widget.snapshot.v1"

    static var appGroupIdentifier: String? {
        guard var bundleIdentifier = Bundle.main.bundleIdentifier else {
            return nil
        }

        if bundleIdentifier.hasSuffix(".widgets") {
            bundleIdentifier.removeLast(".widgets".count)
        }

        return "group.\(bundleIdentifier)"
    }

    static func load() -> AvenWidgetSnapshot {
        guard
            let appGroupIdentifier,
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(AvenWidgetSnapshot.self, from: data)
        else {
            return .locked
        }

        return snapshot
    }

    static func save(_ snapshot: AvenWidgetSnapshot) throws {
        guard
            let appGroupIdentifier,
            let defaults = UserDefaults(suiteName: appGroupIdentifier)
        else {
            throw AvenWidgetStateError.appGroupUnavailable
        }

        defaults.set(try JSONEncoder().encode(snapshot), forKey: snapshotKey)
    }

    static func lock() throws {
        let current = load()
        let locked = AvenWidgetSnapshot(
            pairingState: current.pairingState,
            isPrivacyLocked: true,
            partnerDisplayName: nil,
            daysTogether: nil,
            updatedAt: .now
        )
        try save(locked)
    }
}

enum AvenWidgetStateError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "Aven’s private widget storage is unavailable."
        }
    }
}
