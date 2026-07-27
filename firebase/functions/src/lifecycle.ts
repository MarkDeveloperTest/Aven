import {createHash} from "node:crypto";
import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
  type Transaction
} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {requireVerifiedCaller} from "./auth";
import {sensitiveCallableOptions} from "./config";
import {runCallable} from "./errors";
import {db} from "./firebase";
import {logSecurityEvent} from "./logging";
import {enforceRateLimit} from "./rateLimit";
import {
  archiveRelationshipInputSchema,
  emergencyUnlinkInputSchema,
  parseInput,
  type ArchiveRelationshipInput,
  type EmergencyUnlinkInput
} from "./validation";

type LifecycleAction = "archive" | "emergencyUnlink";
type ResultingStatus = "archived" | "endingRequested";

interface LifecycleTransition {
  readonly action: LifecycleAction;
  readonly status: ResultingStatus;
}

interface LifecycleResult {
  readonly relationshipId: string;
  readonly status: ResultingStatus;
  readonly reused: boolean;
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function requireRelationshipMemberIds(
  relationship: DocumentSnapshot<DocumentData>,
  callerId: string
): readonly [string, string] {
  const memberIds: unknown = relationship.get("memberIds");
  if (
    !Array.isArray(memberIds)
    || memberIds.length !== 2
    || memberIds.some((memberId) => typeof memberId !== "string")
    || new Set(memberIds).size !== 2
    || !memberIds.includes(callerId)
  ) {
    throw new HttpsError(
      "permission-denied",
      "Active relationship membership is required."
    );
  }
  return [memberIds[0] as string, memberIds[1] as string];
}

function isIdempotentReplay(
  relationship: DocumentSnapshot<DocumentData>,
  transition: LifecycleTransition,
  callerId: string,
  idempotencyKeyHash: string
): boolean {
  return relationship.get("status") === transition.status
    && relationship.get("currentLifecycleRequest.action")
      === transition.action
    && relationship.get("currentLifecycleRequest.actorId") === callerId
    && relationship.get("currentLifecycleRequest.idempotencyKeyHash")
      === idempotencyKeyHash;
}

function writeAuditEvent(
  transaction: Transaction,
  eventType: string,
  actorId: string,
  relationshipId: string,
  at: Timestamp
): void {
  transaction.create(db.collection("auditEvents").doc(), {
    eventType,
    actorId,
    details: {relationshipId},
    createdAt: at,
    schemaVersion: 1
  });
}

function disableMemberSharing(
  transaction: Transaction,
  relationshipId: string,
  memberId: string,
  now: Timestamp
): void {
  transaction.update(
    db.doc(`relationships/${relationshipId}/members/${memberId}`),
    {
      "sharingSettings.locationEnabled": false,
      "sharingSettings.historicalLocationIncluded": false,
      "sharingSettings.calendarEnabled": false,
      "sharingSettings.photosEnabled": false,
      "notificationSettings.messagesEnabled": false,
      "notificationSettings.previewMode": "none",
      "aiSettings.sharedAIEnabled": false,
      "aiSettings.selectedMessageAnalysisEnabled": false,
      "updatedAt": now
    }
  );
}

function updateUserLifecycleIndex(
  transaction: Transaction,
  user: DocumentSnapshot<DocumentData>,
  relationshipId: string,
  status: ResultingStatus,
  now: Timestamp
): void {
  if (!user.exists) {
    throw new HttpsError(
      "failed-precondition",
      "A relationship member account is unavailable."
    );
  }

  const activeRelationshipId: unknown = user.get("activeRelationshipId");
  if (
    activeRelationshipId !== null
    && activeRelationshipId !== relationshipId
  ) {
    throw new HttpsError(
      "failed-precondition",
      "A relationship member has conflicting active state."
    );
  }

  const userUpdate: Record<string, unknown> = {
    activeRelationshipId: null,
    updatedAt: now
  };
  if (status === "archived") {
    userUpdate["archivedRelationshipIds"] =
      FieldValue.arrayUnion(relationshipId);
  }
  transaction.update(user.ref, userUpdate);
  transaction.set(
    db.doc(
      `userRelationshipIndex/${user.id}/relationships/${relationshipId}`
    ),
    {
      relationshipId,
      status,
      updatedAt: now,
      schemaVersion: 1
    },
    {merge: true}
  );
}

async function transitionRelationshipLifecycle(
  callerId: string,
  relationshipId: string,
  idempotencyKey: string,
  transition: LifecycleTransition
): Promise<LifecycleResult> {
  const relationshipReference = db.doc(
    `relationships/${relationshipId}`
  );
  const idempotencyKeyHash = sha256(idempotencyKey);

  return db.runTransaction(async (transaction) => {
    const relationship = await transaction.get(relationshipReference);
    if (!relationship.exists) {
      throw new HttpsError(
        "not-found",
        "The relationship was not found."
      );
    }

    const memberIds = requireRelationshipMemberIds(
      relationship,
      callerId
    );
    const memberReferences = memberIds.map(
      (memberId) => db.doc(
        `relationships/${relationshipId}/members/${memberId}`
      )
    );
    const userReferences = memberIds.map(
      (memberId) => db.doc(`users/${memberId}`)
    );
    const [members, users] = await Promise.all([
      Promise.all(
        memberReferences.map(
          async (reference) => transaction.get(reference)
        )
      ),
      Promise.all(
        userReferences.map(
          async (reference) => transaction.get(reference)
        )
      )
    ]);

    if (
      members.some(
        (member, index) =>
          !member.exists
          || member.get("userId") !== memberIds[index]
      )
      || users.find(
        (user) =>
          user.id === callerId
          && user.get("accountState") !== "active"
      ) !== undefined
    ) {
      throw new HttpsError(
        "permission-denied",
        "Active relationship membership is required."
      );
    }

    if (
      isIdempotentReplay(
        relationship,
        transition,
        callerId,
        idempotencyKeyHash
      )
    ) {
      return {
        relationshipId,
        status: transition.status,
        reused: true
      };
    }

    if (relationship.get("status") !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Only an active relationship can change lifecycle state."
      );
    }

    const now = Timestamp.now();
    transaction.update(relationshipReference, {
      status: transition.status,
      activeSharingEndedAt: now,
      updatedAt: now,
      currentLifecycleRequest: {
        action: transition.action,
        actorId: callerId,
        idempotencyKeyHash,
        requestedAt: now,
        completedAt:
          transition.status === "archived" ? now : null,
        status:
          transition.status === "archived"
            ? "completed"
            : "resolutionPending",
        schemaVersion: 1
      },
      ...(transition.status === "archived"
        ? {
          archivedAt: now,
          archivedBy: callerId
        }
        : {
          endingRequestedAt: now,
          endingRequestedBy: callerId
        })
    });

    for (const memberId of memberIds) {
      disableMemberSharing(
        transaction,
        relationshipId,
        memberId,
        now
      );
    }
    for (const user of users) {
      updateUserLifecycleIndex(
        transaction,
        user,
        relationshipId,
        transition.status,
        now
      );
    }
    writeAuditEvent(
      transaction,
      transition.status === "archived"
        ? "relationship.archived"
        : "relationship.emergency_unlinked",
      callerId,
      relationshipId,
      now
    );

    return {
      relationshipId,
      status: transition.status,
      reused: false
    };
  });
}

export async function archiveRelationshipForCaller(
  callerId: string,
  input: ArchiveRelationshipInput
): Promise<LifecycleResult> {
  return transitionRelationshipLifecycle(
    callerId,
    input.relationshipId,
    input.idempotencyKey,
    {action: "archive", status: "archived"}
  );
}

export async function emergencyUnlinkForCaller(
  callerId: string,
  input: EmergencyUnlinkInput
): Promise<LifecycleResult> {
  return transitionRelationshipLifecycle(
    callerId,
    input.relationshipId,
    input.idempotencyKey,
    {action: "emergencyUnlink", status: "endingRequested"}
  );
}

export const archiveRelationship = onCall(
  sensitiveCallableOptions,
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable("archiveRelationship", caller.uid, async () => {
      const input = parseInput(
        archiveRelationshipInputSchema,
        request.data
      );
      await enforceRateLimit({
        userId: caller.uid,
        operation: "archiveRelationship",
        limit: 6,
        windowSeconds: 60 * 60
      });
      const result = await archiveRelationshipForCaller(
        caller.uid,
        input
      );
      logSecurityEvent({
        operation: "archiveRelationship",
        actorId: caller.uid,
        relationshipId: input.relationshipId,
        outcome: "completed"
      });
      return result;
    });
  }
);

export const emergencyUnlinkRelationship = onCall(
  sensitiveCallableOptions,
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable(
      "emergencyUnlinkRelationship",
      caller.uid,
      async () => {
        const input = parseInput(
          emergencyUnlinkInputSchema,
          request.data
        );
        await enforceRateLimit({
          userId: caller.uid,
          operation: "emergencyUnlinkRelationship",
          limit: 6,
          windowSeconds: 60 * 60
        });
        const result = await emergencyUnlinkForCaller(
          caller.uid,
          input
        );
        logSecurityEvent({
          operation: "emergencyUnlinkRelationship",
          actorId: caller.uid,
          relationshipId: input.relationshipId,
          outcome: "completed"
        });
        return result;
      }
    );
  }
);
