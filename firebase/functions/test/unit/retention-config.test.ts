import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, expect, it} from "vitest";

interface FieldOverride {
  readonly collectionGroup: string;
  readonly fieldPath: string;
  readonly ttl?: boolean;
}

interface FirestoreIndexConfig {
  readonly fieldOverrides: readonly FieldOverride[];
}

describe("Firestore retention configuration", () => {
  it("enables TTL for every server collection that writes expiresAt", () => {
    const configuration = JSON.parse(
      readFileSync(
        resolve(process.cwd(), "../firestore.indexes.json"),
        "utf8"
      )
    ) as FirestoreIndexConfig;
    const enabledTTLGroups = configuration.fieldOverrides
      .filter(
        (override) =>
          override.fieldPath === "expiresAt"
          && override.ttl === true
      )
      .map((override) => override.collectionGroup)
      .sort();

    expect(enabledTTLGroups).toEqual([
      "AIRequests",
      "internalRateLimits",
      "invitations",
      "pairingCodeLookups"
    ]);
  });
});
