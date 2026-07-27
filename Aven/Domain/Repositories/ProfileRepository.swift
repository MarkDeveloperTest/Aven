import Foundation

protocol ProfileRepository: Sendable {
    func loadProfile(for userID: String) async -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func deleteProfile(for userID: String) async throws
}
