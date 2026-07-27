import {Timestamp} from "firebase-admin/firestore";
import {beforeEach, describe, expect, it} from "vitest";
import {requireAIAccess} from "../../src/authorization";
import {db} from "../../src/firebase";

const relationshipId = "relationship_ai_001";

async function clearFirestore(): Promise<void> {
  const collections = await db.listCollections();
  await Promise.all(
    collections.map(async (collection) => db.recursiveDelete(collection))
  );
}

async function seedAIConsent(): Promise<void> {
  const batch = db.batch();
  for (const userId of ["alice", "bob"]) {
    batch.set(db.doc(`users/${userId}`), {
      accountState: "active",
      activeRelationshipId: relationshipId,
      schemaVersion: 1
    });
    batch.set(
      db.doc(`relationships/${relationshipId}/members/${userId}`),
      {
        userId,
        aiSettings: {
          sharedAIEnabled: true,
          selectedMessageAnalysisEnabled: true,
          consentVersion: 1
        },
        updatedAt: Timestamp.now(),
        schemaVersion: 1
      }
    );
  }
  batch.set(db.doc(`relationships/${relationshipId}`), {
    memberIds: ["alice", "bob"],
    status: "active",
    schemaVersion: 1
  });
  batch.set(db.doc("users/alice/privatePreferences/ai"), {
    ownerId: "alice",
    values: {
      cloudAIEnabled: true,
      cloudAIConsentVersion: 1
    },
    updatedAt: Timestamp.now(),
    schemaVersion: 1
  });
  await batch.commit();
}

beforeEach(async () => {
  await clearFirestore();
  await seedAIConsent();
});

describe("AI category authorization", () => {
  it("permits consented private text and mutual selected-message use", async () => {
    await expect(
      requireAIAccess(
        "alice",
        "private",
        null,
        "userAuthoredText",
        1
      )
    ).resolves.toBeUndefined();
    await expect(
      requireAIAccess(
        "alice",
        "shared",
        relationshipId,
        "selectedMessages",
        1
      )
    ).resolves.toBeUndefined();
  });

  it("denies shared selected messages when either member revokes category consent", async () => {
    await db.doc(
      `relationships/${relationshipId}/members/bob`
    ).update({
      "aiSettings.selectedMessageAnalysisEnabled": false
    });

    await expect(
      requireAIAccess(
        "alice",
        "shared",
        relationshipId,
        "selectedMessages",
        1
      )
    ).rejects.toMatchObject({code: "permission-denied"});
  });

  it("denies raw user text in shared scope", async () => {
    await expect(
      requireAIAccess(
        "alice",
        "shared",
        relationshipId,
        "userAuthoredText",
        1
      )
    ).rejects.toMatchObject({code: "permission-denied"});
  });
});
