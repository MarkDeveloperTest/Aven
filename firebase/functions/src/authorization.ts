import type {DocumentData, DocumentSnapshot} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "./firebase";

export async function requireActiveUser(
  userId: string
): Promise<DocumentSnapshot<DocumentData>> {
  const snapshot = await db.doc(`users/${userId}`).get();
  if (!snapshot.exists || snapshot.get("accountState") !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "The account is not active."
    );
  }
  return snapshot;
}

export async function requireActiveRelationshipMember(
  userId: string,
  relationshipId: string
): Promise<void> {
  const [relationship, member] = await Promise.all([
    db.doc(`relationships/${relationshipId}`),
    db.doc(`relationships/${relationshipId}/members/${userId}`)
  ].map(async (reference) => reference.get())) as [
    DocumentSnapshot<DocumentData>,
    DocumentSnapshot<DocumentData>
  ];

  if (
    !relationship.exists
    || relationship.get("status") !== "active"
    || !member.exists
    || member.get("userId") !== userId
  ) {
    throw new HttpsError(
      "permission-denied",
      "Active relationship membership is required."
    );
  }
}

export async function requireAIAccess(
  userId: string,
  scope: "private" | "shared",
  relationshipId: string | null,
  contextCategory: "userAuthoredText" | "selectedMessages",
  consentVersion: 1
): Promise<void> {
  await requireActiveUser(userId);

  const preference = await db
    .doc(`users/${userId}/privatePreferences/ai`)
    .get();
  if (
    !preference.exists
    || preference.get("values.cloudAIEnabled") !== true
    || preference.get("values.cloudAIConsentVersion") !== consentVersion
  ) {
    throw new HttpsError(
      "permission-denied",
      "Cloud AI is not enabled for this account."
    );
  }

  if (scope === "private") {
    if (contextCategory !== "userAuthoredText") {
      throw new HttpsError(
        "permission-denied",
        "The requested AI context is not permitted for private scope."
      );
    }
    return;
  }

  if (relationshipId === null) {
    throw new HttpsError(
      "invalid-argument",
      "A relationship is required for shared AI."
    );
  }

  await requireActiveRelationshipMember(userId, relationshipId);
  const members = await db
    .collection(`relationships/${relationshipId}/members`)
    .get();

  if (
    members.size !== 2
    || members.docs.some(
      (member) =>
        member.get("aiSettings.sharedAIEnabled") !== true
        || member.get("aiSettings.selectedMessageAnalysisEnabled") !== true
        || member.get("aiSettings.consentVersion") !== consentVersion
    )
  ) {
    throw new HttpsError(
      "permission-denied",
      "Both members must enable shared selected-message AI."
    );
  }

  if (contextCategory !== "selectedMessages") {
    throw new HttpsError(
      "permission-denied",
      "Shared AI requires selected-message consent."
    );
  }
}
