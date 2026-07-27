import FirebaseFirestore
import Foundation

actor FirebaseProfileRepository: ProfileRepository {
    private enum Field {
        static let displayName = "displayName"
        static let dateOfBirth = "dateOfBirth"
        static let countryCode = "countryCode"
        static let timeZoneID = "timeZoneId"
        static let accountState = "accountState"
        static let schemaVersion = "schemaVersion"
        static let values = "values"
        static let relationshipType = "relationshipType"
        static let relationshipStartDate = "relationshipStartDate"
    }

    private let firestore: Firestore

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    func loadProfile(for userID: String) async -> UserProfile? {
        do {
            let userSnapshot = try await userReference(for: userID).getDocument()
            guard
                let data = userSnapshot.data(),
                data[Field.accountState] as? String == "active",
                data[Field.schemaVersion] as? Int == 1,
                let displayName = data[Field.displayName] as? String,
                let dateOfBirth = data[Field.dateOfBirth] as? Timestamp,
                let countryCode = data[Field.countryCode] as? String,
                let timeZoneID = data[Field.timeZoneID] as? String
            else {
                return nil
            }

            let preferenceSnapshot = try? await onboardingPreferenceReference(
                for: userID
            ).getDocument()
            let values = preferenceSnapshot?.data()?[Field.values]
                as? [String: Any]
            let relationshipType = (values?[Field.relationshipType] as? String)
                .flatMap(RelationshipType.init(rawValue:))
                ?? .unspecified
            let relationshipStartDate = (
                values?[Field.relationshipStartDate] as? Timestamp
            )?.dateValue()

            return UserProfile(
                userID: userID,
                displayName: displayName,
                dateOfBirth: dateOfBirth.dateValue(),
                countryCode: countryCode,
                timeZoneIdentifier: timeZoneID,
                relationshipType: relationshipType,
                relationshipStartDate: relationshipStartDate
            )
        } catch {
            AppLogger.persistence.error("Firebase profile load failed")
            return nil
        }
    }

    func saveProfile(_ profile: UserProfile) async throws {
        let userReference = userReference(for: profile.userID)
        do {
            let existingUser = try await userReference.getDocument()
            if existingUser.exists {
                try await userReference.updateData([
                    Field.displayName: profile.displayName,
                    Field.countryCode: profile.countryCode,
                    Field.timeZoneID: profile.timeZoneIdentifier,
                    "locale": supportedLocaleIdentifier(),
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            } else {
                try await userReference.setData([
                    Field.displayName: profile.displayName,
                    Field.dateOfBirth: Timestamp(date: profile.dateOfBirth),
                    "profileImagePath": NSNull(),
                    Field.countryCode: profile.countryCode,
                    Field.timeZoneID: profile.timeZoneIdentifier,
                    "locale": supportedLocaleIdentifier(),
                    "activeRelationshipId": NSNull(),
                    "archivedRelationshipIds": [],
                    Field.accountState: "active",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    Field.schemaVersion: 1,
                ])
            }

            let preferenceReference = onboardingPreferenceReference(
                for: profile.userID
            )
            let preferenceExists = try await preferenceReference
                .getDocument()
                .exists
            var relationshipValues: [String: Any] = [
                Field.relationshipType: profile.relationshipType.rawValue,
            ]
            relationshipValues[Field.relationshipStartDate] =
                profile.relationshipStartDate.map(Timestamp.init(date:))
                ?? NSNull()

            if preferenceExists {
                try await preferenceReference.updateData([
                    Field.values: relationshipValues,
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            } else {
                try await preferenceReference.setData([
                    "ownerId": profile.userID,
                    Field.values: relationshipValues,
                    "updatedAt": FieldValue.serverTimestamp(),
                    Field.schemaVersion: 1,
                ])
            }
        } catch let appError as AppError {
            throw appError
        } catch {
            AppLogger.persistence.error("Firebase profile save failed")
            throw Self.mapPersistenceError(error)
        }
    }

    func deleteProfile(for userID: String) async throws {
        _ = userID
        // User records are intentionally server-owned during deletion. The
        // deleteAccountData callable is still a fail-closed backend stub, so
        // do not create a partially deleted or orphaned Firebase account.
        throw AppError.externalConfigurationRequired
    }

    private func userReference(for userID: String) -> DocumentReference {
        firestore.collection("users").document(userID)
    }

    private func onboardingPreferenceReference(
        for userID: String
    ) -> DocumentReference {
        userReference(for: userID)
            .collection("privatePreferences")
            .document("onboarding")
    }

    private nonisolated func supportedLocaleIdentifier() -> String {
        Locale.current.language.languageCode?.identifier == "uk" ? "uk" : "en"
    }

    private nonisolated static func mapPersistenceError(
        _ error: any Error
    ) -> AppError {
        let error = error as NSError
        if error.domain == NSURLErrorDomain {
            return .offline
        }
        return .unknown
    }
}
