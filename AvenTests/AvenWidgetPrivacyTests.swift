import Testing
@testable import Aven

struct AvenWidgetPrivacyTests {
    @Test
    func lockedSnapshotNeverPresentsRelationshipDetails() {
        let snapshot = AvenWidgetSnapshot(
            pairingState: .paired,
            isPrivacyLocked: true,
            partnerDisplayName: "Private Partner",
            daysTogether: 100,
            updatedAt: .now
        )

        #expect(snapshot.presentation(allowsSensitiveContent: true) == .private)
    }

    @Test
    func systemPrivacyRedactionOverridesUnlockedSnapshot() {
        let snapshot = AvenWidgetSnapshot(
            pairingState: .paired,
            isPrivacyLocked: false,
            partnerDisplayName: "Private Partner",
            daysTogether: 100,
            updatedAt: .now
        )

        #expect(snapshot.presentation(allowsSensitiveContent: false) == .private)
    }

    @Test
    func defaultSnapshotIsLockedAndContainsNoRelationshipDetails() {
        #expect(AvenWidgetSnapshot.locked.isPrivacyLocked)
        #expect(AvenWidgetSnapshot.locked.partnerDisplayName == nil)
        #expect(AvenWidgetSnapshot.locked.daysTogether == nil)
    }
}
