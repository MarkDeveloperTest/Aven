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
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc
} from "firebase/firestore";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  it
} from "vitest";

const projectId = "demo-aven-local";
const relationshipId = "relationship_alpha";

let testEnvironment: RulesTestEnvironment;

function memberData(
  userId: string,
  locationEnabled = false
): Record<string, unknown> {
  return {
    userId,
    role: "member",
    joinedAt: Timestamp.fromMillis(1_700_000_000_000),
    updatedAt: Timestamp.fromMillis(1_700_000_000_000),
    permissions: {
      canMessage: true,
      canAddMemories: true,
      canManageRelationship: false
    },
    sharingSettings: {
      locationEnabled,
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
  };
}

function userData(accountState = "active"): Record<string, unknown> {
  return {
    displayName: "Test User",
    dateOfBirth: Timestamp.fromMillis(946_684_800_000),
    profileImagePath: null,
    countryCode: "GB",
    timeZoneId: "Europe/London",
    locale: "en",
    activeRelationshipId:
      accountState === "active" ? relationshipId : null,
    archivedRelationshipIds: [],
    accountState,
    createdAt: Timestamp.fromMillis(1_700_000_000_000),
    updatedAt: Timestamp.fromMillis(1_700_000_000_000),
    schemaVersion: 1
  };
}

async function seedRelationship(
  status: "active" | "archived" | "endingRequested" = "active",
  bobLocationEnabled = false,
  aliceAccountState = "active"
): Promise<void> {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await Promise.all([
      setDoc(doc(firestore, "users/alice"), userData(aliceAccountState)),
      setDoc(doc(firestore, "users/bob"), userData()),
      setDoc(doc(firestore, "users/mallory"), userData()),
      setDoc(doc(firestore, `relationships/${relationshipId}`), {
        memberIds: ["alice", "bob"],
        status,
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1
      }),
      setDoc(
        doc(
          firestore,
          `relationships/${relationshipId}/members/alice`
        ),
        memberData("alice")
      ),
      setDoc(
        doc(
          firestore,
          `relationships/${relationshipId}/members/bob`
        ),
        memberData("bob", bobLocationEnabled)
      )
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
    }
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

afterAll(async () => {
  await testEnvironment.cleanup();
});

describe("Firestore relationship boundaries", () => {
  it("allows a signed-in user to bootstrap only their own missing profile", async () => {
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();

    await assertSucceeds(getDoc(doc(alice, "users/alice")));
    await assertFails(getDoc(doc(alice, "users/bob")));
  });

  it("allows a valid member and denies a non-member", async () => {
    await seedRelationship();
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const mallory = testEnvironment
      .authenticatedContext("mallory")
      .firestore();
    const relationshipPath = `relationships/${relationshipId}`;

    await assertSucceeds(getDoc(doc(alice, relationshipPath)));
    await assertFails(getDoc(doc(mallory, relationshipPath)));
  });

  it("denies cross-user private data", async () => {
    await seedRelationship();
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "users/alice/privatePreferences/ai"
        ),
        {
          ownerId: "alice",
          values: {cloudAIEnabled: true},
          updatedAt: Timestamp.fromMillis(1_700_000_000_000),
          schemaVersion: 1
        }
      );
    });

    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const bob = testEnvironment.authenticatedContext("bob").firestore();
    const preferencePath = "users/alice/privatePreferences/ai";

    await assertSucceeds(getDoc(doc(alice, preferencePath)));
    await assertFails(getDoc(doc(bob, preferencePath)));
  });

  it("prevents a forged message sender", async () => {
    await seedRelationship();
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const baseMessage = {
      type: "text",
      body: "Hello",
      mediaPath: null,
      locationId: null,
      replyToMessageId: null,
      clientMessageId: "client-message-0001",
      createdAt: serverTimestamp(),
      schemaVersion: 1
    };

    await assertSucceeds(
      setDoc(
        doc(
          alice,
          `relationships/${relationshipId}/messages/valid`
        ),
        {...baseMessage, senderId: "alice"}
      )
    );
    await assertFails(
      setDoc(
        doc(
          alice,
          `relationships/${relationshipId}/messages/forged`
        ),
        {...baseMessage, senderId: "bob"}
      )
    );
  });

  it("denies relationship and membership escalation", async () => {
    await seedRelationship();
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();

    await assertFails(
      updateDoc(doc(alice, `relationships/${relationshipId}`), {
        memberIds: ["alice", "bob", "mallory"]
      })
    );
    await assertFails(
      setDoc(
        doc(
          alice,
          `relationships/${relationshipId}/members/mallory`
        ),
        memberData("mallory")
      )
    );
  });

  it("denies direct invitation and manual-code lookup access", async () => {
    await seedRelationship();
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "invitations/invite1"), {
        creatorId: "alice",
        status: "redeemed",
        redeemedBy: "bob",
        createdAt: Timestamp.fromMillis(1_700_000_000_000)
      });
      await setDoc(doc(context.firestore(), "pairingCodeLookups/lookup1"), {
        invitationId: "invite1",
        expiresAt: Timestamp.fromMillis(1_700_003_600_000)
      });
    });
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const invitation = doc(alice, "invitations/invite1");
    const lookup = doc(alice, "pairingCodeLookups/lookup1");

    await assertFails(getDoc(invitation));
    await assertFails(updateDoc(invitation, {status: "pending"}));
    await assertFails(getDoc(lookup));
    await assertFails(updateDoc(lookup, {invitationId: "other"}));
  });

  it("allows archived reads but denies archived writes", async () => {
    await seedRelationship("archived");
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();

    await assertSucceeds(
      getDoc(doc(alice, `relationships/${relationshipId}`))
    );
    await assertFails(
      setDoc(
        doc(
          alice,
          `relationships/${relationshipId}/messages/new`
        ),
        {
          senderId: "alice",
          type: "text",
          body: "Archived write",
          mediaPath: null,
          locationId: null,
          replyToMessageId: null,
          clientMessageId: "client-message-0002",
          createdAt: serverTimestamp(),
          schemaVersion: 1
        }
      )
    );
  });

  it("revokes both members' reads as soon as ending is requested", async () => {
    await seedRelationship("endingRequested");
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const bob = testEnvironment.authenticatedContext("bob").firestore();

    await assertFails(
      getDoc(doc(alice, `relationships/${relationshipId}`))
    );
    await assertFails(
      getDoc(doc(bob, `relationships/${relationshipId}`))
    );
  });

  it("removes access when the caller account is deleted", async () => {
    await seedRelationship("active", false, "deleted");
    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();

    await assertFails(
      getDoc(doc(alice, `relationships/${relationshipId}`))
    );
    await assertFails(getDoc(doc(alice, "users/alice")));
  });

  it("keeps private AI memory private and shared AI memory member-only", async () => {
    await seedRelationship();
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await Promise.all([
        setDoc(
          doc(
            firestore,
            "users/alice/privateAIMemories/private1"
          ),
          {
            ownerId: "alice",
            fact: "Private fact",
            source: "user",
            createdAt: Timestamp.fromMillis(1_700_000_000_000),
            updatedAt: Timestamp.fromMillis(1_700_000_000_000),
            schemaVersion: 1
          }
        ),
        setDoc(
          doc(
            firestore,
            `relationships/${relationshipId}/sharedAIMemories/shared1`
          ),
          {
            fact: "Shared fact",
            createdAt: Timestamp.fromMillis(1_700_000_000_000)
          }
        )
      ]);
    });

    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const bob = testEnvironment.authenticatedContext("bob").firestore();
    const mallory = testEnvironment
      .authenticatedContext("mallory")
      .firestore();
    const privateMemoryPath =
      "users/alice/privateAIMemories/private1";
    const sharedMemoryPath =
      `relationships/${relationshipId}/sharedAIMemories/shared1`;

    await assertSucceeds(getDoc(doc(alice, privateMemoryPath)));
    await assertFails(getDoc(doc(bob, privateMemoryPath)));
    await assertSucceeds(getDoc(doc(bob, sharedMemoryPath)));
    await assertFails(getDoc(doc(mallory, sharedMemoryPath)));
    await assertFails(
      setDoc(
        doc(
          alice,
          `relationships/${relationshipId}/sharedAIMemories/clientWrite`
        ),
        {fact: "Client-generated"}
      )
    );
  });

  it("honors the location owner's sharing boundary", async () => {
    await seedRelationship("active", false);
    const now = Date.now();
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `relationships/${relationshipId}/locations/bob-location`
        ),
        {
          ownerId: "bob",
          latitude: 50.45,
          longitude: 30.52,
          horizontalAccuracy: 20,
          recordedAt: Timestamp.fromMillis(1_700_000_000_000),
          expiresAt: Timestamp.fromMillis(now + 60 * 60 * 1000),
          createdAt: Timestamp.fromMillis(1_700_000_000_000),
          schemaVersion: 1
        }
      );
    });

    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const locationPath =
      `relationships/${relationshipId}/locations/bob-location`;
    await assertFails(getDoc(doc(alice, locationPath)));

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `relationships/${relationshipId}/members/bob`
        ),
        {"sharingSettings.locationEnabled": true}
      );
    });

    await assertSucceeds(getDoc(doc(alice, locationPath)));
    await assertFails(
      setDoc(doc(alice, locationPath), {
        ownerId: "bob",
        latitude: 51,
        longitude: 31
      })
    );
  });

  it("denies reads after a shared location has expired", async () => {
    await seedRelationship("active", true);
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `relationships/${relationshipId}/locations/expired-location`
        ),
        {
          ownerId: "bob",
          latitude: 50.45,
          longitude: 30.52,
          horizontalAccuracy: 20,
          recordedAt: Timestamp.fromMillis(Date.now() - 2_000),
          expiresAt: Timestamp.fromMillis(Date.now() - 1_000),
          createdAt: Timestamp.fromMillis(Date.now() - 2_000),
          schemaVersion: 1
        }
      );
    });

    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    await assertFails(
      getDoc(
        doc(
          alice,
          `relationships/${relationshipId}/locations/expired-location`
        )
      )
    );
  });

  it("reveals a surprise memory only to its author until the reveal time", async () => {
    await seedRelationship();
    const futureReveal = Timestamp.fromMillis(
      Date.now() + 60 * 60 * 1000
    );
    const memoryPath =
      `relationships/${relationshipId}/memories/surprise`;
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), memoryPath), {
        authorId: "alice",
        caption: "A surprise",
        mediaPaths: [
          `${memoryPath}/photo1`
        ],
        occurredAt: Timestamp.fromMillis(Date.now()),
        locationId: null,
        category: "gift",
        visibility: "shared",
        surpriseUntil: futureReveal,
        createdAt: Timestamp.fromMillis(Date.now()),
        updatedAt: Timestamp.fromMillis(Date.now()),
        schemaVersion: 1
      });
    });

    const alice = testEnvironment
      .authenticatedContext("alice")
      .firestore();
    const bob = testEnvironment.authenticatedContext("bob").firestore();

    await assertSucceeds(getDoc(doc(alice, memoryPath)));
    await assertFails(getDoc(doc(bob, memoryPath)));

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), memoryPath), {
        surpriseUntil: Timestamp.fromMillis(Date.now() - 1_000)
      });
    });
    await assertSucceeds(getDoc(doc(bob, memoryPath)));
  });
});
