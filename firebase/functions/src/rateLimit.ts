import {createHash} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "./firebase";

interface RateLimitOptions {
  readonly userId: string;
  readonly operation: string;
  readonly limit: number;
  readonly windowSeconds: number;
}

export async function enforceRateLimit(
  options: RateLimitOptions
): Promise<void> {
  const nowMillis = Date.now();
  const windowNumber = Math.floor(
    nowMillis / (options.windowSeconds * 1000)
  );
  const opaqueActor = createHash("sha256")
    .update(options.userId)
    .digest("hex");
  const documentId = `${opaqueActor}_${options.operation}_${windowNumber}`;
  const reference = db.doc(`internalRateLimits/${documentId}`);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
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
      reference,
      {
        count: count + 1,
        operation: options.operation,
        windowNumber,
        expiresAt: Timestamp.fromMillis(
          (windowNumber + 2) * options.windowSeconds * 1000
        ),
        updatedAt: Timestamp.fromMillis(nowMillis)
      },
      {merge: true}
    );
  });
}
