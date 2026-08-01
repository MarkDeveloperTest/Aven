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
import {requireAuthenticatedCaller} from "./auth";
import {pairingCallableOptions, invitationSigningSecret} from "./config";
import {requireConfiguredSecret, runCallable} from "./errors";
import {db} from "./firebase";
import {logSecurityEvent} from "./logging";
import {
  applyRateLimit,
  rateLimitBucket,
  type RateLimitOptions
} from "./rateLimit";
import {
  createInvitationInputSchema,
  type RedeemInvitationInput,
  parseInput,
  redeemInvitationInputSchema,
  revokeInvitationInputSchema,
  splitLinkToken,
  type CreateInvitationInput
} from "./validation";

export const INVITATION_LIFETIME_MILLIS = 24 * 60 * 60 * 1000;
const INVITATION_SCHEMA_VERSION = 2;
const MAX_ATOMIC_INVITATION_REVOCATIONS = 400;
const MANUAL_CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

interface DerivedInvitation {
  readonly invitationId: string;
  readonly secret: string;
  readonly linkToken: string;
  readonly linkTokenHash: string;
  readonly manualCode: string;
  readonly manualCodeLookupId: string;
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
  const manualCodeBytes = createHmac("sha256", signingSecret)
    .update(`aven-invitation-manual-code-v1\u0000${userId}\u0000${invitationId}`)
    .digest();
  const manualCode = Array.from(
    manualCodeBytes.subarray(0, 6),
    (byte) => MANUAL_CODE_ALPHABET[byte & 31] ?? "2"
  ).join("");

  return {
    invitationId,
    secret,
    linkToken: `${invitationId}.${secret}`,
    linkTokenHash: sha256(secret),
    manualCode,
    manualCodeLookupId: manualCodeLookupId(manualCode, signingSecret),
    idempotencyKeyHash: sha256(idempotencyKey)
  };
}

function manualCodeLookupId(
  manualCode: string,
  signingSecret: string
): string {
  return createHmac("sha256", signingSecret)
    .update(`aven-invitation-code-lookup-v1\u0000${manualCode}`)
    .digest("hex");
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

function requireCurrentInvitation(invitation: DocumentData | undefined): void {
  if (invitation?.["schemaVersion"] !== INVITATION_SCHEMA_VERSION) {
    throw new HttpsError(
      "failed-precondition",
      "The invitation is no longer supported."
    );
  }
}

function requireManualCodeLookupId(value: unknown): string {
  if (typeof value !== "string" || !/^[a-f0-9]{64}$/u.test(value)) {
    throw new HttpsError("internal", "The invitation lookup is invalid.");
  }
  return value;
}

function requireActiveUnpairedUser(
  user: DocumentData | undefined
): void {
  requireActiveAccount(user);
  if (user?.["activeRelationshipId"] !== null) {
    throw new HttpsError(
      "failed-precondition",
      "The account is already in an active relationship."
    );
  }
}

function requireActiveAccount(
  user: DocumentData | undefined
): void {
  if (user?.["accountState"] !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "The account is not active."
    );
  }
}

function requireDisplayName(user: DocumentData | undefined): string {
  const displayName: unknown = user?.["displayName"];
  if (
    typeof displayName !== "string"
    || displayName.trim().length === 0
    || displayName.length > 80
  ) {
    throw new HttpsError(
      "internal",
      "The user profile is incomplete."
    );
  }
  return displayName;
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
    ...pairingCallableOptions,
    secrets: [invitationSigningSecret]
  },
  async (request) => {
    const caller = requireAuthenticatedCaller(request);

    return runCallable("createInvitation", caller.uid, async () => {
      const input = parseInput(
        createInvitationInputSchema,
        request.data
      );
      const rateLimitOptions: RateLimitOptions = {
        userId: caller.uid,
        operation: "createInvitation",
        limit: 5,
        windowSeconds: 60 * 60
      };
      const rateLimit = rateLimitBucket(rateLimitOptions);

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
      const manualCodeLookupReference = db.doc(
        `pairingCodeLookups/${derived.manualCodeLookupId}`
      );
      const userReference = db.doc(`users/${caller.uid}`);

      const result = await db.runTransaction(async (transaction) => {
        const [
          userSnapshot,
          invitationSnapshot,
          manualCodeLookupSnapshot,
          rateLimitSnapshot
        ] = await Promise.all([
          transaction.get(userReference),
          transaction.get(invitationReference),
          transaction.get(manualCodeLookupReference),
          transaction.get(rateLimit.reference)
        ]);
        requireActiveUnpairedUser(userSnapshot.data());
        applyRateLimit(
          transaction,
          rateLimitSnapshot,
          rateLimit,
          rateLimitOptions
        );

        if (invitationSnapshot.exists) {
          requireCurrentInvitation(invitationSnapshot.data());
          if (
            invitationSnapshot.get("creatorId") !== caller.uid
            || invitationSnapshot.get("idempotencyKeyHash")
              !== derived.idempotencyKeyHash
            || invitationSnapshot.get("linkTokenHash")
              !== derived.linkTokenHash
            || invitationSnapshot.get("manualCode")
              !== derived.manualCode
            || invitationSnapshot.get("manualCodeLookupId")
              !== derived.manualCodeLookupId
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
          if (
            !(expiresAt instanceof Timestamp)
            || expiresAt.toMillis() <= Timestamp.now().toMillis()
          ) {
            throw new HttpsError(
              "failed-precondition",
              "The invitation has expired."
            );
          }
          if (
            !manualCodeLookupSnapshot.exists
            || manualCodeLookupSnapshot.get("invitationId")
              !== derived.invitationId
          ) {
            throw new HttpsError(
              "failed-precondition",
              "The invitation lookup is unavailable."
            );
          }

          return {
            linkToken: derived.linkToken,
            manualCode: derived.manualCode,
            invitationId: derived.invitationId,
            expiresAt: expiresAt.toDate().toISOString(),
            reused: true
          };
        }

        if (manualCodeLookupSnapshot.exists) {
          throw new HttpsError(
            "resource-exhausted",
            "A manual invitation code collision occurred. Retry with a new request."
          );
        }

        const now = Timestamp.now();
        const expiresAt = Timestamp.fromMillis(
          now.toMillis() + INVITATION_LIFETIME_MILLIS
        );
        transaction.create(invitationReference, {
          creatorId: caller.uid,
          linkTokenHash: derived.linkTokenHash,
          manualCode: derived.manualCode,
          manualCodeLookupId: derived.manualCodeLookupId,
          idempotencyKeyHash: derived.idempotencyKeyHash,
          relationshipType: input.relationshipType,
          relationshipStartDate: relationshipStartTimestamp(input),
          status: "pending",
          expiresAt,
          createdAt: now,
          updatedAt: now,
          schemaVersion: INVITATION_SCHEMA_VERSION
        });
        transaction.create(manualCodeLookupReference, {
          invitationId: derived.invitationId,
          expiresAt,
          createdAt: now,
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
          linkToken: derived.linkToken,
          manualCode: derived.manualCode,
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
  pairingCallableOptions,
  async (request) => {
    const caller = requireAuthenticatedCaller(request);

    return runCallable("revokeInvitation", caller.uid, async () => {
      const input = parseInput(
        revokeInvitationInputSchema,
        request.data
      );
      const rateLimitOptions: RateLimitOptions = {
        userId: caller.uid,
        operation: "revokeInvitation",
        limit: 20,
        windowSeconds: 60 * 60
      };
      const rateLimit = rateLimitBucket(rateLimitOptions);

      const invitationReference = db.doc(
        `invitations/${input.invitationId}`
      );
      const userReference = db.doc(`users/${caller.uid}`);
      const idempotencyKeyHash = sha256(input.idempotencyKey);
      const result = await db.runTransaction(async (transaction) => {
        const [invitation, user, rateLimitSnapshot] = await Promise.all([
          transaction.get(invitationReference),
          transaction.get(userReference),
          transaction.get(rateLimit.reference)
        ]);
        requireActiveAccount(user.data());
        if (
          !invitation.exists
          || invitation.get("creatorId") !== caller.uid
        ) {
          throw new HttpsError(
            "not-found",
            "The invitation was not found."
          );
        }
        requireCurrentInvitation(invitation.data());
        applyRateLimit(
          transaction,
          rateLimitSnapshot,
          rateLimit,
          rateLimitOptions
        );

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
        const lookupId = requireManualCodeLookupId(
          invitation.get("manualCodeLookupId")
        );
        transaction.update(invitationReference, {
          status: "revoked",
          revokedAt: now,
          revocationIdempotencyKeyHash: idempotencyKeyHash,
          updatedAt: now
        });
        transaction.delete(db.doc(`pairingCodeLookups/${lookupId}`));
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
  {
    ...pairingCallableOptions,
    secrets: [invitationSigningSecret]
  },
  async (request) => {
    const caller = requireAuthenticatedCaller(request);

    return runCallable("redeemInvitation", caller.uid, async () => {
      const input: RedeemInvitationInput = parseInput(
        redeemInvitationInputSchema,
        request.data
      );
      const rateLimitOptions: RateLimitOptions = {
        userId: caller.uid,
        operation: "redeemInvitation",
        limit: 10,
        windowSeconds: 60 * 60
      };
      const rateLimit = rateLimitBucket(rateLimitOptions);

      const signingSecret = requireConfiguredSecret(
        invitationSigningSecret.value(),
        "Invitation signing secret"
      );
      const redeemerReference = db.doc(`users/${caller.uid}`);
      const relationshipReference = db.collection("relationships").doc();
      const redeemIdempotencyKeyHash = sha256(input.idempotencyKey);

      const result = await db.runTransaction<RedemptionResult>(
        async (transaction) => {
          let invitationId: string;
          let suppliedSecret: string | undefined;

          if (input.kind === "token") {
            const token = splitLinkToken(input.value);
            invitationId = token.invitationId;
            suppliedSecret = token.secret;
          } else {
            const lookupId = manualCodeLookupId(
              input.value,
              signingSecret
            );
            const lookup = await transaction.get(
              db.doc(`pairingCodeLookups/${lookupId}`)
            );
            const resolvedInvitationId: unknown = lookup.get("invitationId");
            if (
              !lookup.exists
              || typeof resolvedInvitationId !== "string"
              || !/^[a-f0-9]{40}$/u.test(resolvedInvitationId)
            ) {
              throw new HttpsError(
                "not-found",
                "The invitation was not found."
              );
            }
            invitationId = resolvedInvitationId;
          }

          const invitationReference = db.doc(
            `invitations/${invitationId}`
          );
          const invitation = await transaction.get(invitationReference);
          if (!invitation.exists) {
            throw new HttpsError(
              "not-found",
              "The invitation was not found."
            );
          }
          requireCurrentInvitation(invitation.data());

          const credentialMatches = suppliedSecret === undefined
            ? invitation.get("manualCode") === input.value
              && invitation.get("manualCodeLookupId")
                === manualCodeLookupId(input.value, signingSecret)
            : invitationSecretMatches(
              suppliedSecret,
              invitation.get("linkTokenHash")
            );
          if (!credentialMatches) {
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

          const now = Timestamp.now();
          const expiresAt: unknown = invitation.get("expiresAt");
          if (
            !(expiresAt instanceof Timestamp)
            || expiresAt.toMillis() <= now.toMillis()
          ) {
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
          const [creator, redeemer, rateLimitSnapshot] = await Promise.all([
            transaction.get(creatorReference),
            transaction.get(redeemerReference),
            transaction.get(rateLimit.reference)
          ]);
          requireActiveUnpairedUser(creator.data());
          requireActiveUnpairedUser(redeemer.data());
          const creatorDisplayName = requireDisplayName(creator.data());
          const redeemerDisplayName = requireDisplayName(redeemer.data());

          const pendingInvitations = await transaction.get(
            db
              .collection("invitations")
              .where("creatorId", "in", [creatorId, caller.uid])
              .where("status", "==", "pending")
              .limit(MAX_ATOMIC_INVITATION_REVOCATIONS + 2)
          );
          const otherPendingInvitations = pendingInvitations.docs.filter(
            (candidate) => candidate.id !== invitationId
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

          applyRateLimit(
            transaction,
            rateLimitSnapshot,
            rateLimit,
            rateLimitOptions
          );

          const relationshipId = relationshipReference.id;
          const memberIds = [creatorId, caller.uid];
          transaction.create(relationshipReference, {
            memberIds,
            memberDisplayNames: {
              [creatorId]: creatorDisplayName,
              [caller.uid]: redeemerDisplayName
            },
            status: "active",
            createdAt: now,
            updatedAt: now,
            relationshipStartDate,
            relationshipType,
            theme: "default",
            settings: {},
            currentLifecycleRequest: null,
            sourceInvitationId: invitationId,
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
            const lookupId: unknown = pendingInvitation.get(
              "manualCodeLookupId"
            );
            if (typeof lookupId === "string" && /^[a-f0-9]{64}$/u.test(lookupId)) {
              transaction.delete(db.doc(`pairingCodeLookups/${lookupId}`));
            }
          }
          writeAuditEvent(
            transaction,
            "invitation.redeemed",
            caller.uid,
            {
              invitationId,
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
