import {HttpsError} from "firebase-functions/v2/https";
import {
  logInternalFailure,
  logSecurityEvent
} from "./logging";

export async function runCallable<T>(
  operation: string,
  actorId: string,
  work: () => Promise<T>
): Promise<T> {
  try {
    return await work();
  } catch (error: unknown) {
    if (error instanceof HttpsError) {
      logSecurityEvent({
        operation,
        actorId,
        outcome: "denied",
        reasonCode: error.code
      });
      throw error;
    }

    logInternalFailure(operation, actorId, error);
    throw new HttpsError(
      "internal",
      "The operation could not be completed."
    );
  }
}

export function requireConfiguredSecret(
  value: unknown,
  configurationName: string
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "failed-precondition",
      `${configurationName} is not configured.`
    );
  }
  const normalized = value.trim();
  if (normalized.length < 32) {
    throw new HttpsError(
      "failed-precondition",
      `${configurationName} is not configured.`
    );
  }
  return normalized;
}
