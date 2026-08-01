import {createHash} from "node:crypto";
import {
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "./firebase";

export interface RateLimitOptions {
  readonly userId: string;
  readonly operation: string;
  readonly limit: number;
  readonly windowSeconds: number;
}

export interface RateLimitBucket {
  readonly reference: DocumentReference;
  readonly windowNumber: number;
  readonly nowMillis: number;
}

export function rateLimitBucket(
  options: RateLimitOptions,
  nowMillis = Date.now()
): RateLimitBucket {
  const windowNumber = Math.floor(
    nowMillis / (options.windowSeconds * 1000)
  );
  const opaqueActor = createHash("sha256")
    .update(options.userId)
    .digest("hex");
  const documentId = `${opaqueActor}_${options.operation}_${windowNumber}`;
  return {
    reference: db.doc(`internalRateLimits/${documentId}`),
    windowNumber,
    nowMillis
  };
}

export function applyRateLimit(
  transaction: Transaction,
  snapshot: DocumentSnapshot,
  bucket: RateLimitBucket,
  options: RateLimitOptions
): void {
  const count = snapshot.exists
    ? (snapshot.get("count") as number)
    : 0;

  if (count >= options.limit) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many requests. Try again later."
    );
  }

  transaction.set(
    bucket.reference,
    {
      count: count + 1,
      operation: options.operation,
      windowNumber: bucket.windowNumber,
      expiresAt: Timestamp.fromMillis(
        (bucket.windowNumber + 2) * options.windowSeconds * 1000
      ),
      updatedAt: Timestamp.fromMillis(bucket.nowMillis)
    },
    {merge: true}
  );
}

export async function enforceRateLimit(
  options: RateLimitOptions
): Promise<void> {
  const bucket = rateLimitBucket(options);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(bucket.reference);
    applyRateLimit(transaction, snapshot, bucket, options);
  });
}
