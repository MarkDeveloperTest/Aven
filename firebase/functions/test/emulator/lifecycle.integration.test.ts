import {Timestamp} from "firebase-admin/firestore";
import {afterAll, beforeEach, describe, expect, it} from "vitest";
import {db} from "../../src/firebase";
import {
  archiveRelationshipForCaller,
  emergencyUnlinkForCaller
} from "../../src/lifecycle";

const archiveRelationshipId = "relationship_archive_001";
const emergencyRelationshipId = "relationship_emergency_001";
const archiveIdempotencyKey =
  "018f6f7e-1234-7abc-8def-123456789abc";
const emergencyIdempotencyKey =
  "018f6f7e-5678-7abc-8def-123456789abc";

function memberData(userId: string): Record<string, unknown> {
  return {
    userId,
    role: "member",
    joinedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    permissions: {
      canMessage: true,
      canAddMemories: true,
      canManageRelationship: false
    },
    sharingSettings: {
      locationEnabled: true,
      historicalLocationIncluded: true,
      calendarEnabled: true,
      photosEnabled: true
    },
    notificationSettings: {
      messagesEnabled: true,
      previewMode: "full"
    },
    aiSettings: {
      sharedAIEnabled: true,
      selectedMessageAnalysisEnabled: true,
      consentVersion: 1
    },
    schemaVersion: 1
  };
}

async function seedRelationship(relationshipId: string): Promise<void> {
  const batch = db.batch();
  for (const userId of ["alice", "bob"]) {
    batch.set(db.doc(`users/${userId}`), {
      accountState: "active",
      activeRelationshipId: relationshipId,
      archivedRelationshipIds: [],
      updatedAt: Timestamp.now(),
      schemaVersion: 1
    });
    batch.set(
      db.doc(`relationships/${relationshipId}/members/${userId}`),
      memberData(userId)
    );
  }
  batch.set(db.doc(`users/mallory`), {
    accountState: "active",
    activeRelationshipId: null,
    archivedRelationshipIds: [],
    updatedAt: Timestamp.now(),
    schemaVersion: 1
  });
  batch.set(db.doc(`relationships/${relationshipId}`), {
    memberIds: ["alice", "bob"],
    status: "active",
    currentLifecycleRequest: null,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    schemaVersion: 1
  });
  await batch.commit();
}

async function clearFirestore(): Promise<void> {
  const collections = await db.listCollections();
  await Promise.all(
    collections.map(async (collection) => db.recursiveDelete(collection))
  );
}

beforeEach(async () => {
  await clearFirestore();
});

afterAll(async () => {
  await clearFirestore();
});

describe("relationship lifecycle transactions", () => {
  it("archives for both members, disables sharing, and is idempotent", async () => {
    await seedRelationship(archiveRelationshipId);

    const result = await archiveRelationshipForCaller("alice", {
      relationshipId: archiveRelationshipId,
      idempotencyKey: archiveIdempotencyKey
    });
    expect(result).toEqual({
      relationshipId: archiveRelationshipId,
      status: "archived",
      reused: false
    });

    const [relationship, alice, bob, aliceMember, auditEvents] =
      await Promise.all([
        db.doc(`relationships/${archiveRelationshipId}`).get(),
        db.doc("users/alice").get(),
        db.doc("users/bob").get(),
        db.doc(
          `relationships/${archiveRelationshipId}/members/alice`
        ).get(),
        db.collection("auditEvents")
          .where("eventType", "==", "relationship.archived")
          .get()
      ]);
    expect(relationship.get("status")).toBe("archived");
    expect(alice.get("activeRelationshipId")).toBeNull();
    expect(bob.get("activeRelationshipId")).toBeNull();
    expect(alice.get("archivedRelationshipIds")).toContain(
      archiveRelationshipId
    );
    expect(bob.get("archivedRelationshipIds")).toContain(
      archiveRelationshipId
    );
    expect(
      aliceMember.get("sharingSettings.locationEnabled")
    ).toBe(false);
    expect(
      aliceMember.get("notificationSettings.messagesEnabled")
    ).toBe(false);
    expect(auditEvents.size).toBe(1);

    const replay = await archiveRelationshipForCaller("alice", {
      relationshipId: archiveRelationshipId,
      idempotencyKey: archiveIdempotencyKey
    });
    expect(replay.reused).toBe(true);
    const auditEventsAfterReplay = await db
      .collection("auditEvents")
      .where("eventType", "==", "relationship.archived")
      .get();
    expect(auditEventsAfterReplay.size).toBe(1);
  });

  it("immediately ends access without partner approval", async () => {
    await seedRelationship(emergencyRelationshipId);

    const result = await emergencyUnlinkForCaller("alice", {
      relationshipId: emergencyRelationshipId,
      idempotencyKey: emergencyIdempotencyKey,
      confirmation: "STOP_SHARING_NOW"
    });
    expect(result.status).toBe("endingRequested");

    const [relationship, aliceIndex, bobIndex] = await Promise.all([
      db.doc(`relationships/${emergencyRelationshipId}`).get(),
      db.doc(
        `userRelationshipIndex/alice/relationships/${emergencyRelationshipId}`
      ).get(),
      db.doc(
        `userRelationshipIndex/bob/relationships/${emergencyRelationshipId}`
      ).get()
    ]);
    expect(relationship.get("status")).toBe("endingRequested");
    expect(
      relationship.get("currentLifecycleRequest.status")
    ).toBe("resolutionPending");
    expect(aliceIndex.get("status")).toBe("endingRequested");
    expect(bobIndex.get("status")).toBe("endingRequested");
  });

  it("denies a non-member lifecycle transition", async () => {
    await seedRelationship(archiveRelationshipId);

    await expect(
      archiveRelationshipForCaller("mallory", {
        relationshipId: archiveRelationshipId,
        idempotencyKey: archiveIdempotencyKey
      })
    ).rejects.toMatchObject({code: "permission-denied"});
  });
});
