import {createHash, createHmac} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import type {CallableRequest} from "firebase-functions/v2/https";
import {afterAll, beforeEach, describe, expect, it} from "vitest";
import {db} from "../../src/firebase";
import {
  createInvitation,
  INVITATION_LIFETIME_MILLIS,
  redeemInvitation,
  revokeInvitation
} from "../../src/invitations";

const invitationId = "a".repeat(40);
const invitationSecret = "B".repeat(43);
const invitationCode = `${invitationId}.${invitationSecret}`;
const manualCode = "ABC7K9";
const signingSecret = "test-invitation-signing-secret-with-32-bytes";
const idempotencyKey = "018f6f7e-9999-7abc-8def-123456789abc";
const secondIdempotencyKey = "018f6f7e-9999-7abc-8def-123456789abd";
const manualCodeAlphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

process.env["INVITATION_SIGNING_SECRET"] = signingSecret;

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function manualCodeLookupId(value: string): string {
  return createHmac("sha256", signingSecret)
    .update(`aven-invitation-code-lookup-v1\u0000${value}`)
    .digest("hex");
}

function derivedManualCode(userId: string, key: string): string {
  const derivedInvitationId = sha256(
    `aven-invitation-id-v1\u0000${userId}\u0000${key}`
  ).slice(0, 40);
  const bytes = createHmac("sha256", signingSecret)
    .update(
      `aven-invitation-manual-code-v1\u0000${userId}\u0000${derivedInvitationId}`
    )
    .digest();
  return Array.from(
    bytes.subarray(0, 6),
    (byte) => manualCodeAlphabet[byte & 31] ?? "2"
  ).join("");
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
      linkTokenHash: sha256(invitationSecret),
      manualCode,
      manualCodeLookupId: manualCodeLookupId(manualCode),
      relationshipType: "dating",
      relationshipStartDate: null,
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      ),
      createdAt: now,
      updatedAt: now,
      schemaVersion: 2
    }),
    db.doc(`pairingCodeLookups/${manualCodeLookupId(manualCode)}`).set({
      invitationId,
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 60 * 1000
      ),
      createdAt: now,
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
  it("creates one atomically reserved code with an exact 24-hour lifetime", async () => {
    const result = await createInvitation.run(
      callableRequest("charlie", {
        relationshipType: "longDistance",
        relationshipStartDate: null,
        idempotencyKey
      })
    );

    expect(result.reused).toBe(false);
    expect(result.linkToken).toMatch(
      new RegExp(`^${result.invitationId}\\.[A-Za-z0-9_-]{43}$`, "u")
    );
    expect(result.manualCode).toMatch(/^[2-9A-HJ-NP-Z]{6}$/u);

    const invitation = await db.doc(
      `invitations/${result.invitationId}`
    ).get();
    const createdAt = invitation.get("createdAt") as Timestamp;
    const expiresAt = invitation.get("expiresAt") as Timestamp;
    expect(expiresAt.toMillis() - createdAt.toMillis()).toBe(
      INVITATION_LIFETIME_MILLIS
    );
    expect(expiresAt.toDate().toISOString()).toBe(result.expiresAt);

    const lookup = await db.doc(
      `pairingCodeLookups/${manualCodeLookupId(result.manualCode)}`
    ).get();
    expect(lookup.data()).toMatchObject({
      invitationId: result.invitationId,
      schemaVersion: 1
    });

    const retry = await createInvitation.run(
      callableRequest("charlie", {
        relationshipType: "longDistance",
        relationshipStartDate: null,
        idempotencyKey
      })
    );
    expect(retry).toEqual({...result, reused: true});
  });

  it("fails atomically when a generated manual code is already reserved", async () => {
    const collisionCode = derivedManualCode("charlie", secondIdempotencyKey);
    await db.doc(
      `pairingCodeLookups/${manualCodeLookupId(collisionCode)}`
    ).set({
      invitationId: "e".repeat(40),
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
      schemaVersion: 1
    });

    await expect(
      createInvitation.run(
        callableRequest("charlie", {
          relationshipType: "dating",
          relationshipStartDate: null,
          idempotencyKey: secondIdempotencyKey
        })
      )
    ).rejects.toThrow("collision");

    const expectedInvitationId = sha256(
      `aven-invitation-id-v1\u0000charlie\u0000${secondIdempotencyKey}`
    ).slice(0, 40);
    expect((await db.doc(`invitations/${expectedInvitationId}`).get()).exists)
      .toBe(false);
  });

  it("redeems once and atomically revokes both members' other invitations", async () => {
    const result = await redeemInvitation.run(
      callableRequest("bob", {
        kind: "code",
        value: "abc-7k9",
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
        kind: "token",
        value: invitationCode,
        idempotencyKey
      })
    );
    expect(replay).toEqual({
      relationshipId,
      alreadyRedeemed: true
    });
  });

  it("rejects an invitation at its expiry boundary without changing either user", async () => {
    await db.doc(`invitations/${invitationId}`).update({
      expiresAt: Timestamp.now()
    });

    await expect(
      redeemInvitation.run(
        callableRequest("bob", {
          kind: "token",
          value: invitationCode,
          idempotencyKey
        })
      )
    ).rejects.toThrow("expired");

    const [invitation, alice, bob] = await Promise.all([
      db.doc(`invitations/${invitationId}`).get(),
      db.doc("users/alice").get(),
      db.doc("users/bob").get()
    ]);
    expect(invitation.get("status")).toBe("pending");
    expect(alice.get("activeRelationshipId")).toBeNull();
    expect(bob.get("activeRelationshipId")).toBeNull();
  });

  it("rejects self-pairing and legacy invitations without writes", async () => {
    await expect(
      redeemInvitation.run(
        callableRequest("alice", {
          kind: "code",
          value: manualCode,
          idempotencyKey
        })
      )
    ).rejects.toThrow("cannot be redeemed");

    await db.doc(`invitations/${invitationId}`).update({schemaVersion: 1});
    await expect(
      redeemInvitation.run(
        callableRequest("bob", {
          kind: "token",
          value: invitationCode,
          idempotencyKey
        })
      )
    ).rejects.toThrow("no longer supported");
    expect((await db.doc(`invitations/${invitationId}`).get()).get("status"))
      .toBe("pending");
  });

  it("allows only one winner when two accounts redeem concurrently", async () => {
    const attempts = await Promise.allSettled([
      redeemInvitation.run(
        callableRequest("bob", {
          kind: "token",
          value: invitationCode,
          idempotencyKey
        })
      ),
      redeemInvitation.run(
        callableRequest("charlie", {
          kind: "code",
          value: manualCode,
          idempotencyKey: secondIdempotencyKey
        })
      )
    ]);

    expect(attempts.filter((attempt) => attempt.status === "fulfilled"))
      .toHaveLength(1);
    expect(attempts.filter((attempt) => attempt.status === "rejected"))
      .toHaveLength(1);
    const invitation = await db.doc(`invitations/${invitationId}`).get();
    expect(invitation.get("status")).toBe("redeemed");
    expect(["bob", "charlie"]).toContain(invitation.get("redeemedBy"));
  });

  it("does not replace an existing relationship", async () => {
    await db.doc("users/bob").update({
      activeRelationshipId: "existing-relationship"
    });

    await expect(
      redeemInvitation.run(
        callableRequest("bob", {
          kind: "code",
          value: manualCode,
          idempotencyKey
        })
      )
    ).rejects.toThrow("already in an active relationship");

    expect((await db.doc("users/bob").get()).get("activeRelationshipId"))
      .toBe("existing-relationship");
    expect((await db.doc(`invitations/${invitationId}`).get()).get("status"))
      .toBe("pending");
  });

  it("revokes the invitation and removes its direct code lookup", async () => {
    const result = await revokeInvitation.run(
      callableRequest("alice", {
        invitationId,
        idempotencyKey
      })
    );
    expect(result).toEqual({revoked: true, reused: false});
    expect((await db.doc(`invitations/${invitationId}`).get()).get("status"))
      .toBe("revoked");
    expect((await db.doc(
      `pairingCodeLookups/${manualCodeLookupId(manualCode)}`
    ).get()).exists).toBe(false);

    const retry = await revokeInvitation.run(
      callableRequest("alice", {
        invitationId,
        idempotencyKey
      })
    );
    expect(retry).toEqual({revoked: true, reused: true});
  });
});
