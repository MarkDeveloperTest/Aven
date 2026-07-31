import {HttpsError} from "firebase-functions/v2/https";
import type {CallableRequest} from "firebase-functions/v2/https";

export interface VerifiedCaller {
  readonly uid: string;
  readonly appId: string;
}

export function requireVerifiedCaller(
  request: CallableRequest<unknown>
): VerifiedCaller {
  if (request.auth === undefined) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  if (request.app === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "App attestation is required."
    );
  }

  if (request.app.alreadyConsumed === true) {
    throw new HttpsError(
      "permission-denied",
      "A fresh app attestation is required."
    );
  }

  return {
    uid: request.auth.uid,
    appId: request.app.appId
  };
}
