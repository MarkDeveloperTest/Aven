import {createRequire} from "node:module";
import {mkdtempSync, rmSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {applicationDefault, getApps, initializeApp} from "firebase-admin/app";
import {
  FieldPath,
  Timestamp,
  getFirestore
} from "firebase-admin/firestore";

const currentSchemaVersion = 2;
const maximumLifetimeMillis = 24 * 60 * 60 * 1000;
const pageSize = 200;
const projectFlagIndex = process.argv.indexOf("--project");
const projectId = projectFlagIndex >= 0
  ? process.argv[projectFlagIndex + 1]
  : undefined;
const dryRun = process.argv.includes("--dry-run");
const useFirebaseCLIAuth = process.argv.includes("--firebase-cli-auth");

if (!projectId || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/u.test(projectId)) {
  throw new Error("Pass the exact Firebase project with --project <project-id>.");
}

let temporaryCredentialDirectory;

function prepareFirebaseCLIApplicationDefault() {
  const require = createRequire(import.meta.url);
  const auth = require("firebase-tools/lib/auth");
  const api = require("firebase-tools/lib/api");
  const account = auth.getGlobalDefaultAccount();
  const refreshToken = account?.tokens?.refresh_token;
  if (typeof refreshToken !== "string" || refreshToken.length === 0) {
    throw new Error("Firebase CLI authentication is unavailable. Run firebase login.");
  }

  temporaryCredentialDirectory = mkdtempSync(
    join(tmpdir(), "aven-firebase-auth-")
  );
  const credentialPath = join(
    temporaryCredentialDirectory,
    "application-default.json"
  );
  writeFileSync(
    credentialPath,
    JSON.stringify({
      type: "authorized_user",
      client_id: api.clientId(),
      client_secret: api.clientSecret(),
      refresh_token: refreshToken
    }),
    {encoding: "utf8", mode: 0o600}
  );
  process.env["GOOGLE_APPLICATION_CREDENTIALS"] = credentialPath;
}

function removeTemporaryCredential() {
  if (!temporaryCredentialDirectory) {
    return;
  }
  rmSync(temporaryCredentialDirectory, {recursive: true, force: true});
  temporaryCredentialDirectory = undefined;
}

process.once("exit", removeTemporaryCredential);

if (useFirebaseCLIAuth) {
  prepareFirebaseCLIApplicationDefault();
}

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId
  });
}

const firestore = getFirestore();
let cursor;
let invalidatedCount = 0;

while (true) {
  let query = firestore
    .collection("invitations")
    .where("status", "==", "pending")
    .orderBy(FieldPath.documentId())
    .limit(pageSize);
  if (cursor) {
    query = query.startAfter(cursor);
  }

  const snapshot = await query.get();
  if (snapshot.empty) {
    break;
  }

  const batch = firestore.batch();
  let writeCount = 0;
  for (const invitation of snapshot.docs) {
    const data = invitation.data();
    const createdAt = data.createdAt;
    const expiresAt = data.expiresAt;
    const hasCurrentLifetime = data.schemaVersion === currentSchemaVersion
      && createdAt instanceof Timestamp
      && expiresAt instanceof Timestamp
      && expiresAt.toMillis() - createdAt.toMillis() <= maximumLifetimeMillis;

    if (hasCurrentLifetime) {
      continue;
    }

    invalidatedCount += 1;
    if (dryRun) {
      continue;
    }

    const now = Timestamp.now();
    batch.update(invitation.ref, {
      status: "revoked",
      revokedAt: now,
      revocationReason: "pairing_v2_cutover",
      updatedAt: now
    });
    writeCount += 1;

    if (
      typeof data.manualCodeLookupId === "string"
      && /^[a-f0-9]{64}$/u.test(data.manualCodeLookupId)
    ) {
      batch.delete(
        firestore.doc(`pairingCodeLookups/${data.manualCodeLookupId}`)
      );
      writeCount += 1;
    }
  }

  if (writeCount > 0) {
    await batch.commit();
  }
  cursor = snapshot.docs.at(-1);
  if (snapshot.size < pageSize) {
    break;
  }
}

const action = dryRun ? "Would invalidate" : "Invalidated";
process.stdout.write(`${action} ${invalidatedCount} legacy invitation(s).\n`);
removeTemporaryCredential();
