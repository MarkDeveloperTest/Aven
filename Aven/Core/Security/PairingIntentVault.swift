import Foundation
import Security

nonisolated struct StoredPairingState: Codable, Equatable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case createInvitation
        case redeemInvitation
        case invitation
    }

    let kind: Kind
    let ownerUserID: String?
    let idempotencyKey: String?
    let invitationID: String?
    let invitationCode: String?
    let invitationExpiresAt: Date?
    let revocationIdempotencyKey: String?

    static func createInvitation(
        ownerUserID: String?,
        idempotencyKey: String
    ) -> Self {
        Self(
            kind: .createInvitation,
            ownerUserID: ownerUserID,
            idempotencyKey: idempotencyKey,
            invitationID: nil,
            invitationCode: nil,
            invitationExpiresAt: nil,
            revocationIdempotencyKey: nil
        )
    }

    static func redeemInvitation(
        ownerUserID: String?,
        idempotencyKey: String,
        invitationCode: String
    ) -> Self {
        Self(
            kind: .redeemInvitation,
            ownerUserID: ownerUserID,
            idempotencyKey: idempotencyKey,
            invitationID: nil,
            invitationCode: invitationCode,
            invitationExpiresAt: nil,
            revocationIdempotencyKey: nil
        )
    }

    static func invitation(
        ownerUserID: String,
        invitation: PairingInvitation,
        revocationIdempotencyKey: String?
    ) -> Self {
        Self(
            kind: .invitation,
            ownerUserID: ownerUserID,
            idempotencyKey: nil,
            invitationID: invitation.id,
            invitationCode: invitation.code,
            invitationExpiresAt: invitation.expiresAt,
            revocationIdempotencyKey: revocationIdempotencyKey
        )
    }

    func isValid(now: Date = .now) -> Bool {
        guard
            ownerUserID.map(Self.isValidUserID) ?? true,
            idempotencyKey.map(Self.isValidIdempotencyKey) ?? true,
            revocationIdempotencyKey.map(Self.isValidIdempotencyKey) ?? true
        else {
            return false
        }

        switch kind {
        case .createInvitation:
            return idempotencyKey != nil
                && invitationID == nil
                && invitationCode == nil
                && invitationExpiresAt == nil
                && revocationIdempotencyKey == nil
        case .redeemInvitation:
            return idempotencyKey != nil
                && invitationID == nil
                && invitationCode.map(PairingInvitation.isValidCode) == true
                && invitationExpiresAt == nil
                && revocationIdempotencyKey == nil
        case .invitation:
            guard
                ownerUserID != nil,
                idempotencyKey == nil,
                let invitationID,
                invitationID.range(
                    of: #"^[a-f0-9]{40}$"#,
                    options: .regularExpression
                ) != nil,
                let invitationCode,
                PairingInvitation.isValidCode(invitationCode),
                invitationCode.hasPrefix(invitationID + "."),
                let invitationExpiresAt,
                invitationExpiresAt > now
            else {
                return false
            }
            return true
        }
    }

    private static func isValidIdempotencyKey(_ value: String) -> Bool {
        value.count == 36 && UUID(uuidString: value) != nil
    }

    private static func isValidUserID(_ value: String) -> Bool {
        value.isEmpty == false && value.utf8.count <= 128
    }
}

protocol PairingIntentVault: Sendable {
    func load() async throws -> StoredPairingState?
    func save(_ state: StoredPairingState) async throws
    func delete() async throws
}

actor NoOpPairingIntentVault: PairingIntentVault {
    func load() async throws -> StoredPairingState? { nil }
    func save(_ state: StoredPairingState) async throws { _ = state }
    func delete() async throws {}
}

nonisolated enum PairingIntentVaultError: Error, Equatable, Sendable {
    case invalidData
    case keychain(status: OSStatus)
}

actor KeychainPairingIntentVault: PairingIntentVault {
    private let service: String
    private let account = "pending-firebase-pairing-v1"
    private let defaults: UserDefaults

    init(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.example.aven",
        defaults: UserDefaults = .standard
    ) {
        service = bundleIdentifier + ".pairing-intent"
        self.defaults = defaults
    }

    func load() async throws -> StoredPairingState? {
        guard defaults.bool(forKey: installationMarker) else {
            try await delete()
            defaults.set(true, forKey: installationMarker)
            return nil
        }

        let query = identity.merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = result as? Data else {
                throw PairingIntentVaultError.invalidData
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let state = try decoder.decode(StoredPairingState.self, from: data)
                guard state.isValid() else {
                    try await delete()
                    return nil
                }
                return state
            } catch let error as PairingIntentVaultError {
                throw error
            } catch {
                try await delete()
                throw PairingIntentVaultError.invalidData
            }
        default:
            throw PairingIntentVaultError.keychain(status: status)
        }
    }

    func save(_ state: StoredPairingState) async throws {
        guard state.isValid() else {
            throw PairingIntentVaultError.invalidData
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        defaults.set(true, forKey: installationMarker)
        var add = identity
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        switch SecItemAdd(add as CFDictionary, nil) {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let status = SecItemUpdate(
                identity as CFDictionary,
                [kSecValueData: data] as CFDictionary
            )
            guard status == errSecSuccess else {
                throw PairingIntentVaultError.keychain(status: status)
            }
        case let status:
            throw PairingIntentVaultError.keychain(status: status)
        }
    }

    func delete() async throws {
        let status = SecItemDelete(identity as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PairingIntentVaultError.keychain(status: status)
        }
    }

    private var identity: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }

    private var installationMarker: String {
        service + ".has-launched-v1"
    }
}

actor PairingIntentPersistenceCoordinator {
    private let vault: any PairingIntentVault
    private var latestRevision = 0

    init(vault: any PairingIntentVault) {
        self.vault = vault
    }

    func load() async throws -> StoredPairingState? {
        try await vault.load()
    }

    func apply(_ state: StoredPairingState?, revision: Int) async throws {
        guard revision > latestRevision else { return }
        latestRevision = revision
        if let state {
            try await vault.save(state)
        } else {
            try await vault.delete()
        }
    }
}
