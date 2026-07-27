import {
  createHash,
  createHmac,
  timingSafeEqual
} from "node:crypto";
import {
  Timestamp,
  type DocumentData,
  type Transaction
} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {requireVerifiedCaller} from "./auth";
import {requireActiveUser} from "./authorization";
import {sensitiveCallableOptions, invitationSigningSecret} from "./config";
import {requireConfiguredSecret, runCallable} from "./errors";
import {db} from "./firebase";
import {logSecurityEvent} from "./logging";
import {enforceRateLimit} from "./rateLimit";
import {
  createInvitationInputSchema,
  parseInput,
  redeemInvitationInputSchema,
  revokeInvitationInputSchema,
  splitInvitationCode,
  type CreateInvitationInput
} from "./validation";

const INVITATION_LIFETIME_MILLIS = 7 * 24 * 60 * 60 * 1000;
const MAX_ATOMIC_INVITATION_REVOCATIONS = 400;

interface DerivedInvitation {
  readonly invitationId: string;
  readonly secret: string;
  readonly code: string;
  readonly codeHash: string;
  readonly idempotencyKeyHash: string;
}

interface RedemptionResult {
  readonly relationshipId: string;
  readonly alreadyRedeemed: boolean;
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function deriveInvitation(
  userId: string,
  idempotencyKey: string,
  signingSecret: string
): DerivedInvitation {
  const invitationId = sha256(
    `aven-invitation-id-v1\u0000${userId}\u0000${idempotencyKey}`
  ).slice(0, 40);
  const secret = createHmac("sha256", signingSecret)
    .update(`aven-invitation-secret-v1\u0000${userId}\u0000${invitationId}`)
    .digest("base64url");

  return {
    invitationId,
    secret,
    code: `${invitationId}.${secret}`,
    codeHash: sha256(secret),
    idempotencyKeyHash: sha256(idempotencyKey)
  };
}

function invitationSecretMatches(
  suppliedSecret: string,
  storedHash: unknown
): boolean {
  if (
    typeof storedHash !== "string"
    || !/^[a-f0-9]{64}$/u.test(storedHash)
  ) {
    return false;
  }

  const supplied = Buffer.from(sha256(suppliedSecret), "hex");
  const stored = Buffer.from(storedHash, "hex");
  return supplied.length === stored.length && timingSafeEqual(supplied, stored);
}

function requireActiveUnpairedUser(
  user: DocumentData | undefined
): void {
  if (user?.["accountState"] !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "The account is not active."
    );
  }
  if (user["activeRelationshipId"] !== null) {
    throw new HttpsError(
      "failed-precondition",
      "The account is already in an active relationship."
    );
  }
}

function relationshipStartTimestamp(
  input: CreateInvitationInput
): Timestamp | null {
  if (input.relationshipStartDate === null) {
    return null;
  }
  return Timestamp.fromDate(new Date(input.relationshipStartDate));
}

function writeAuditEvent(
  transaction: Transaction,
  eventType: string,
  actorId: string,
  details: Readonly<Record<string, string>>,
  at: Timestamp
): void {
  transaction.create(db.collection("auditEvents").doc(), {
    eventType,
    actorId,
    details,
    createdAt: at,
    schemaVersion: 1
  });
}

export const createInvitation = onCall(
  {
    ...sensitiveCallableOptions,
    secrets: [invitationSigningSecret]
  },
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable("createInvitation", caller.uid, async () => {
      const input = parseInput(
        createInvitationInputSchema,
        request.data
      );
      await requireActiveUser(caller.uid);
      await enforceRateLimit({
        userId: caller.uid,
        operation: "createInvitation",
        limit: 5,
        windowSeconds: 60 * 60
      });

      const signingSecret = requireConfiguredSecret(
        invitationSigningSecret.value(),
        "Invitation signing secret"
      );
      const derived = deriveInvitation(
        caller.uid,
        input.idempotencyKey,
        signingSecret
      );
      const invitationReference = db.doc(
        `invitations/${derived.invitationId}`
      );
      const userReference = db.doc(`users/${caller.uid}`);

      const result = await db.runTransaction(async (transaction) => {
        const [userSnapshot, invitationSnapshot] = await Promise.all([
          transaction.get(userReference),
          transaction.get(invitationReference)
        ]);
        requireActiveUnpairedUser(userSnapshot.data());

        if (invitationSnapshot.exists) {
          if (
            invitationSnapshot.get("creatorId") !== caller.uid
            || invitationSnapshot.get("idempotencyKeyHash")
              !== derived.idempotencyKeyHash
            || invitationSnapshot.get("codeHash") !== derived.codeHash
          ) {
            throw new HttpsError(
              "already-exists",
              "The idempotency key has already been used."
            );
          }
          if (invitationSnapshot.get("status") !== "pending") {
            throw new HttpsError(
              "failed-precondition",
              "The invitation is no longer pending."
            );
          }

          const expiresAt: unknown = invitationSnapshot.get("expiresAt");
          if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
            throw new HttpsError(
              "failed-precondition",
              "The invitation has expired."
            );
          }

          return {
            invitationCode: derived.code,
            invitationId: derived.invitationId,
            expiresAt: expiresAt.toDate().toISOString(),
            reused: true
          };
        }

        const now = Timestamp.now();
        const expiresAt = Timestamp.fromMillis(
          now.toMillis() + INVITATION_LIFETIME_MILLIS
        );
        transaction.create(invitationReference, {
          creatorId: caller.uid,
          codeHash: derived.codeHash,
          idempotencyKeyHash: derived.idempotencyKeyHash,
          relationshipType: input.relationshipType,
          relationshipStartDate: relationshipStartTimestamp(input),
          status: "pending",
          expiresAt,
          createdAt: now,
          updatedAt: now,
          schemaVersion: 1
        });
        writeAuditEvent(
          transaction,
          "invitation.created",
          caller.uid,
          {invitationId: derived.invitationId},
          now
        );

        return {
          invitationCode: derived.code,
          invitationId: derived.invitationId,
          expiresAt: expiresAt.toDate().toISOString(),
          reused: false
        };
      });

      logSecurityEvent({
        operation: "createInvitation",
        actorId: caller.uid,
        outcome: "completed"
      });
      return result;
    });
  }
);

export const revokeInvitation = onCall(
  sensitiveCallableOptions,
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable("revokeInvitation", caller.uid, async () => {
      const input = parseInput(
        revokeInvitationInputSchema,
        request.data
      );
      await requireActiveUser(caller.uid);
      await enforceRateLimit({
        userId: caller.uid,
        operation: "revokeInvitation",
        limit: 20,
        windowSeconds: 60 * 60
      });

      const invitationReference = db.doc(
        `invitations/${input.invitationId}`
      );
      const idempotencyKeyHash = sha256(input.idempotencyKey);
      const result = await db.runTransaction(async (transaction) => {
        const invitation = await transaction.get(invitationReference);
        if (
          !invitation.exists
          || invitation.get("creatorId") !== caller.uid
        ) {
          throw new HttpsError(
            "not-found",
            "The invitation was not found."
          );
        }

        const status: unknown = invitation.get("status");
        if (status === "revoked") {
          return {revoked: true, reused: true};
        }
        if (status !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "Only a pending invitation can be revoked."
          );
        }

        const now = Timestamp.now();
        transaction.update(invitationReference, {
          status: "revoked",
          revokedAt: now,
          revocationIdempotencyKeyHash: idempotencyKeyHash,
          updatedAt: now
        });
        writeAuditEvent(
          transaction,
          "invitation.revoked",
          caller.uid,
          {invitationId: input.invitationId},
          now
        );
        return {revoked: true, reused: false};
      });

      logSecurityEvent({
        operation: "revokeInvitation",
        actorId: caller.uid,
        outcome: "completed"
      });
      return result;
    });
  }
);

export const redeemInvitation = onCall(
  sensitiveCallableOptions,
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable("redeemInvitation", caller.uid, async () => {
      const input = parseInput(
        redeemInvitationInputSchema,
        request.data
      );
      const code = splitInvitationCode(input.invitationCode);
      await requireActiveUser(caller.uid);
      await enforceRateLimit({
        userId: caller.uid,
        operation: "redeemInvitation",
        limit: 10,
        windowSeconds: 60 * 60
      });

      const invitationReference = db.doc(
        `invitations/${code.invitationId}`
      );
      const redeemerReference = db.doc(`users/${caller.uid}`);
      const relationshipReference = db.collection("relationships").doc();
      const redeemIdempotencyKeyHash = sha256(input.idempotencyKey);

      const result = await db.runTransaction<RedemptionResult>(
        async (transaction) => {
          const invitation = await transaction.get(invitationReference);
          if (
            !invitation.exists
            || !invitationSecretMatches(
              code.secret,
              invitation.get("codeHash")
            )
          ) {
            throw new HttpsError(
              "not-found",
              "The invitation was not found."
            );
          }

          const invitationStatus: unknown = invitation.get("status");
          if (invitationStatus === "redeemed") {
            if (
              invitation.get("redeemedBy") === caller.uid
              && invitation.get("redeemIdempotencyKeyHash")
                === redeemIdempotencyKeyHash
              && typeof invitation.get("relationshipId") === "string"
            ) {
              return {
                relationshipId: invitation.get("relationshipId") as string,
                alreadyRedeemed: true
              };
            }
            throw new HttpsError(
              "already-exists",
              "The invitation has already been redeemed."
            );
          }
          if (invitationStatus !== "pending") {
            throw new HttpsError(
              "failed-precondition",
              "The invitation is not redeemable."
            );
          }

          const expiresAt: unknown = invitation.get("expiresAt");
          if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
            throw new HttpsError(
              "failed-precondition",
              "The invitation has expired."
            );
          }

          const creatorId: unknown = invitation.get("creatorId");
          if (typeof creatorId !== "string" || creatorId === caller.uid) {
            throw new HttpsError(
              "failed-precondition",
              "This invitation cannot be redeemed by this account."
            );
          }

          const creatorReference = db.doc(`users/${creatorId}`);
          const [creator, redeemer] = await Promise.all([
            transaction.get(creatorReference),
            transaction.get(redeemerReference)
          ]);
          requireActiveUnpairedUser(creator.data());
          requireActiveUnpairedUser(redeemer.data());

          const pendingInvitations = await transaction.get(
            db
              .collection("invitations")
              .where("creatorId", "in", [creatorId, caller.uid])
              .where("status", "==", "pending")
              .limit(MAX_ATOMIC_INVITATION_REVOCATIONS + 2)
          );
          const otherPendingInvitations = pendingInvitations.docs.filter(
            (candidate) => candidate.id !== code.invitationId
          );
          if (
            otherPendingInvitations.length
            > MAX_ATOMIC_INVITATION_REVOCATIONS
          ) {
            throw new HttpsError(
              "resource-exhausted",
              "Too many pending invitations must be resolved before pairing."
            );
          }

          const relationshipStartDate: unknown =
            invitation.get("relationshipStartDate");
          const relationshipType: unknown =
            invitation.get("relationshipType");
          if (
            relationshipStartDate !== null
            && !(relationshipStartDate instanceof Timestamp)
          ) {
            throw new HttpsError(
              "internal",
              "The invitation start date is invalid."
            );
          }
          if (
            typeof relationshipType !== "string"
            || ![
              "dating",
              "longDistance",
              "engaged",
              "married",
              "unspecified"
            ].includes(relationshipType)
          ) {
            throw new HttpsError(
              "internal",
              "The invitation relationship type is invalid."
            );
          }

          const now = Timestamp.now();
          const relationshipId = relationshipReference.id;
          const memberIds = [creatorId, caller.uid];
          transaction.create(relationshipReference, {
            memberIds,
            status: "active",
            createdAt: now,
            updatedAt: now,
            relationshipStartDate,
            relationshipType,
            theme: "default",
            settings: {},
            currentLifecycleRequest: null,
            sourceInvitationId: code.invitationId,
            schemaVersion: 1
          });

          for (const memberId of memberIds) {
            transaction.create(
              relationshipReference.collection("members").doc(memberId),
              {
                userId: memberId,
                role: "member",
                joinedAt: now,
                updatedAt: now,
                permissions: {
                  canMessage: true,
                  canAddMemories: true,
                  canManageRelationship: false
                },
                sharingSettings: {
                  locationEnabled: false,
                  historicalLocationIncluded: false,
                  calendarEnabled: false,
                  photosEnabled: false
                },
                notificationSettings: {
                  messagesEnabled: true,
                  previewMode: "sender"
                },
                aiSettings: {
                  sharedAIEnabled: false,
                  selectedMessageAnalysisEnabled: false,
                  consentVersion: 1
                },
                schemaVersion: 1
              }
            );
            transaction.set(
              db.doc(
                `userRelationshipIndex/${memberId}/relationships/${relationshipId}`
              ),
              {
                relationshipId,
                status: "active",
                joinedAt: now,
                schemaVersion: 1
              }
            );
          }

          transaction.update(creatorReference, {
            activeRelationshipId: relationshipId,
            updatedAt: now
          });
          transaction.update(redeemerReference, {
            activeRelationshipId: relationshipId,
            updatedAt: now
          });
          transaction.update(invitationReference, {
            status: "redeemed",
            redeemedBy: caller.uid,
            redeemedAt: now,
            relationshipId,
            redeemIdempotencyKeyHash,
            updatedAt: now
          });
          for (const pendingInvitation of otherPendingInvitations) {
            transaction.update(pendingInvitation.ref, {
              status: "revoked",
              revokedAt: now,
              revocationReason: "relationship_created",
              updatedAt: now
            });
          }
          writeAuditEvent(
            transaction,
            "invitation.redeemed",
            caller.uid,
            {
              invitationId: code.invitationId,
              relationshipId,
              revokedInvitationCount:
                String(otherPendingInvitations.length)
            },
            now
          );

          return {relationshipId, alreadyRedeemed: false};
        }
      );

      logSecurityEvent({
        operation: "redeemInvitation",
        actorId: caller.uid,
        relationshipId: result.relationshipId,
        outcome: "completed"
      });
      return result;
    });
  }
);
