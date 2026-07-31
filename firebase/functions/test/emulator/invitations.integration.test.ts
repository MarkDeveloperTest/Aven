import {createHash} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import type {CallableRequest} from "firebase-functions/v2/https";
import {afterAll, beforeEach, describe, expect, it} from "vitest";
import {db} from "../../src/firebase";
import {redeemInvitation} from "../../src/invitations";

const invitationId = "a".repeat(40);
const invitationSecret = "B".repeat(43);
const invitationCode = `${invitationId}.${invitationSecret}`;
const idempotencyKey = "018f6f7e-9999-7abc-8def-123456789abc";

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function callableRequest(
  userId: string,
  data: unknown
): CallableRequest<unknown> {
  return {
    data,
    auth: {
      uid: userId,
      token: {}
    },
    app: {
      appId: "test-app",
      token: {}
    },
    rawRequest: {}
  } as unknown as CallableRequest<unknown>;
}

async function clearFirestore(): Promise<void> {
  const collections = await db.listCollections();
  await Promise.all(
    collections.map(async (collection) => db.recursiveDelete(collection))
  );
}

async function seedUser(userId: string): Promise<void> {
  const displayNames: Record<string, string> = {
    alice: "Alice",
    bob: "Bob",
    charlie: "Charlie"
  };
  await db.doc(`users/${userId}`).set({
    displayName: displayNames[userId],
    accountState: "active",
    activeRelationshipId: null,
    archivedRelationshipIds: [],
    updatedAt: Timestamp.now(),
    schemaVersion: 1
  });
}

beforeEach(async () => {
  await clearFirestore();
  await Promise.all([
    seedUser("alice"),
    seedUser("bob"),
    seedUser("charlie")
  ]);
  const now = Timestamp.now();
  await Promise.all([
    db.doc(`invitations/${invitationId}`).set({
      creatorId: "alice",
      codeHash: sha256(invitationSecret),
      relationshipType: "dating",
      relationshipStartDate: null,
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      ),
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1
    }),
    db.doc(`invitations/${"b".repeat(40)}`).set({
      creatorId: "alice",
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      )
    }),
    db.doc(`invitations/${"c".repeat(40)}`).set({
      creatorId: "bob",
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      )
    }),
    db.doc(`invitations/${"d".repeat(40)}`).set({
      creatorId: "charlie",
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      )
    })
  ]);
});

afterAll(async () => {
  await clearFirestore();
});

describe("invitation redemption transaction", () => {
  it("redeems once and atomically revokes both members' other invitations", async () => {
    const result = await redeemInvitation.run(
      callableRequest("bob", {
        invitationCode,
        idempotencyKey
      })
    );
    expect(result).toMatchObject({
      alreadyRedeemed: false
    });
    const relationshipId = (
      result as {relationshipId: string}
    ).relationshipId;

    const [
      redeemed,
      creatorPending,
      redeemerPending,
      unrelated,
      relationship,
      creatorMember,
      redeemerMember,
      creatorUser,
      redeemerUser,
      unrelatedUser,
      creatorIndex,
      redeemerIndex
    ] =
      await Promise.all([
        db.doc(`invitations/${invitationId}`).get(),
        db.doc(`invitations/${"b".repeat(40)}`).get(),
        db.doc(`invitations/${"c".repeat(40)}`).get(),
        db.doc(`invitations/${"d".repeat(40)}`).get(),
        db.doc(`relationships/${relationshipId}`).get(),
        db.doc(`relationships/${relationshipId}/members/alice`).get(),
        db.doc(`relationships/${relationshipId}/members/bob`).get(),
        db.doc("users/alice").get(),
        db.doc("users/bob").get(),
        db.doc("users/charlie").get(),
        db.doc(
          `userRelationshipIndex/alice/relationships/${relationshipId}`
        ).get(),
        db.doc(
          `userRelationshipIndex/bob/relationships/${relationshipId}`
        ).get()
      ]);
    expect(redeemed.get("status")).toBe("redeemed");
    expect(redeemed.get("relationshipId")).toBe(relationshipId);
    expect(creatorPending.get("status")).toBe("revoked");
    expect(redeemerPending.get("status")).toBe("revoked");
    expect(unrelated.get("status")).toBe("pending");
    expect(relationship.data()).toMatchObject({
      memberIds: ["alice", "bob"],
      memberDisplayNames: {
        alice: "Alice",
        bob: "Bob"
      },
      status: "active",
      sourceInvitationId: invitationId,
      schemaVersion: 1
    });
    expect(creatorMember.data()).toMatchObject({
      userId: "alice",
      role: "member",
      schemaVersion: 1
    });
    expect(redeemerMember.data()).toMatchObject({
      userId: "bob",
      role: "member",
      schemaVersion: 1
    });
    expect(creatorUser.get("activeRelationshipId")).toBe(relationshipId);
    expect(redeemerUser.get("activeRelationshipId")).toBe(relationshipId);
    expect(unrelatedUser.get("activeRelationshipId")).toBeNull();
    expect(creatorIndex.data()).toMatchObject({
      relationshipId,
      status: "active",
      schemaVersion: 1
    });
    expect(redeemerIndex.data()).toMatchObject({
      relationshipId,
      status: "active",
      schemaVersion: 1
    });

    const replay = await redeemInvitation.run(
      callableRequest("bob", {
        invitationCode,
        idempotencyKey
      })
    );
    expect(replay).toEqual({
      relationshipId,
      alreadyRedeemed: true
    });
  });
});
