import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment
} from "@firebase/rules-unit-testing";
import {
  doc,
  setDoc,
  Timestamp,
  updateDoc
} from "firebase/firestore";
import {
  getBytes,
  ref,
  uploadBytes
} from "firebase/storage";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  it
} from "vitest";

const projectId = "demo-aven-local";
const relationshipId = "relationship_storage";
const messagePath =
  `relationships/${relationshipId}/messages/message1`;
const filePath = `${messagePath}/attachment1`;
const surpriseMemoryPath =
  `relationships/${relationshipId}/memories/surprise1`;
const surpriseFilePath = `${surpriseMemoryPath}/photo1`;

let testEnvironment: RulesTestEnvironment;

async function seedStorageRelationship(): Promise<void> {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const timestamp = Timestamp.fromMillis(1_700_000_000_000);
    await Promise.all([
      setDoc(doc(firestore, "users/alice"), {
        accountState: "active"
      }),
      setDoc(doc(firestore, "users/bob"), {
        accountState: "active"
      }),
      setDoc(doc(firestore, "users/mallory"), {
        accountState: "active"
      }),
      setDoc(doc(firestore, `relationships/${relationshipId}`), {
        status: "active"
      }),
      setDoc(
        doc(
          firestore,
          `relationships/${relationshipId}/members/alice`
        ),
        {userId: "alice"}
      ),
      setDoc(
        doc(
          firestore,
          `relationships/${relationshipId}/members/bob`
        ),
        {userId: "bob"}
      ),
      setDoc(doc(firestore, messagePath), {
        senderId: "alice",
        createdAt: timestamp
      }),
      setDoc(doc(firestore, surpriseMemoryPath), {
        authorId: "alice",
        surpriseUntil: Timestamp.fromMillis(
          Date.now() + 60 * 60 * 1000
        ),
        createdAt: timestamp
      })
    ]);
  });
}

beforeAll(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(
        resolve(process.cwd(), "../firestore.rules"),
        "utf8"
      )
    },
    storage: {
      rules: readFileSync(
        resolve(process.cwd(), "../storage.rules"),
        "utf8"
      )
    }
  });
});

beforeEach(async () => {
  await Promise.all([
    testEnvironment.clearFirestore(),
    testEnvironment.clearStorage()
  ]);
  await seedStorageRelationship();
});

afterAll(async () => {
  await testEnvironment.cleanup();
});

describe("Storage ownership and media validation", () => {
  it("allows the message sender to upload approved media", async () => {
    const aliceStorage = testEnvironment
      .authenticatedContext("alice")
      .storage();

    await assertSucceeds(
      uploadBytes(
        ref(aliceStorage, filePath),
        new Uint8Array([1, 2, 3]),
        {
          contentType: "image/jpeg",
          customMetadata: {ownerId: "alice"}
        }
      )
    );
  });

  it("denies another member from uploading to the sender's message", async () => {
    const bobStorage = testEnvironment
      .authenticatedContext("bob")
      .storage();

    await assertFails(
      uploadBytes(
        ref(bobStorage, filePath),
        new Uint8Array([1, 2, 3]),
        {
          contentType: "image/jpeg",
          customMetadata: {ownerId: "bob"}
        }
      )
    );
  });

  it("denies non-members from reading relationship media", async () => {
    const aliceStorage = testEnvironment
      .authenticatedContext("alice")
      .storage();
    await uploadBytes(
      ref(aliceStorage, filePath),
      new Uint8Array([1, 2, 3]),
      {
        contentType: "image/jpeg",
        customMetadata: {ownerId: "alice"}
      }
    );

    const malloryStorage = testEnvironment
      .authenticatedContext("mallory")
      .storage();
    await assertFails(
      getBytes(ref(malloryStorage, filePath), 1024)
    );
  });

  it("revokes relationship media reads when emergency ending begins", async () => {
    const aliceStorage = testEnvironment
      .authenticatedContext("alice")
      .storage();
    const bobStorage = testEnvironment
      .authenticatedContext("bob")
      .storage();
    await uploadBytes(
      ref(aliceStorage, filePath),
      new Uint8Array([1, 2, 3]),
      {
        contentType: "image/jpeg",
        customMetadata: {ownerId: "alice"}
      }
    );

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), `relationships/${relationshipId}`),
        {status: "endingRequested"}
      );
    });

    await assertFails(getBytes(ref(aliceStorage, filePath), 1024));
    await assertFails(getBytes(ref(bobStorage, filePath), 1024));
  });

  it("rejects disallowed profile content types and oversized files", async () => {
    const aliceStorage = testEnvironment
      .authenticatedContext("alice")
      .storage();

    await assertFails(
      uploadBytes(
        ref(aliceStorage, "users/alice/profile/script"),
        new Uint8Array([1, 2, 3]),
        {contentType: "text/html"}
      )
    );
    await assertFails(
      uploadBytes(
        ref(aliceStorage, "users/alice/profile/too-large"),
        new Uint8Array(10 * 1024 * 1024 + 1),
        {contentType: "image/jpeg"}
      )
    );
  });

  it("reveals surprise media only to its author until the reveal time", async () => {
    const aliceStorage = testEnvironment
      .authenticatedContext("alice")
      .storage();
    const bobStorage = testEnvironment
      .authenticatedContext("bob")
      .storage();

    await assertSucceeds(
      uploadBytes(
        ref(aliceStorage, surpriseFilePath),
        new Uint8Array([1, 2, 3]),
        {
          contentType: "image/jpeg",
          customMetadata: {ownerId: "alice"}
        }
      )
    );
    await assertSucceeds(
      getBytes(ref(aliceStorage, surpriseFilePath), 1024)
    );
    await assertFails(
      getBytes(ref(bobStorage, surpriseFilePath), 1024)
    );

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), surpriseMemoryPath), {
        surpriseUntil: Timestamp.fromMillis(Date.now() - 1_000)
      });
    });
    await assertSucceeds(
      getBytes(ref(bobStorage, surpriseFilePath), 1024)
    );
  });
});
