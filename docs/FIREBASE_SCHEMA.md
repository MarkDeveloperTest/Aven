# Firebase Schema

## Status

This is the version 1 schema contract represented by the current local
Firestore Rules, Storage Rules, indexes, and Cloud Functions scaffold. The
TypeScript build/lint/unit suites, 18 Firestore/Storage Rules tests, and 7
Firestore integration tests pass locally. The development project, default
database, reviewed Firestore Rules, five composite indexes, and iOS Firebase
adapters exist. Firebase Authentication and its Apple provider are live in
development. Storage/Functions deployment, TTL policies, Google Auth, App
Check, staging, and production are not configured live.

Rules are part of the schema. A collection path described here is not usable in
production until its Rules, indexes, trusted operations, retention, and client
mapping are reviewed together.

## Conventions

- Document IDs are opaque and never encode private user content.
- Mutable records include `updatedAt`; created records include `createdAt`.
- Server-authoritative timestamps use the server timestamp where Rules require
  it.
- Current records use `schemaVersion: 1`.
- Unbounded records use subcollections and paginated queries rather than arrays.
- Relationship IDs and membership come from trusted stored documents, not
  client claims.
- Internal operational collections are never client-readable.
- Media objects have a corresponding authorized Firestore owner record.

## Top-level collections

| Path | Purpose | Client access |
| --- | --- | --- |
| `users/{userId}` | profile, locale, account state, active/archive references | owner read/create/update under strict field validation |
| `relationships/{relationshipId}` | two-person relationship and lifecycle state | member read; direct lifecycle/membership mutation denied |
| `userRelationshipIndex/{userId}/relationships/{relationshipId}` | server-maintained lookup/history index | owner read only |
| `invitations/{invitationId}` | expiring, hashed, one-time pairing records | denied; Functions only |
| `AIRequests/{requestId}` | idempotent server AI processing state | denied; Functions only |
| `aiRequests/{requestId}` | reserved lowercase path, denied to avoid accidental exposure | denied |
| `auditEvents/{eventId}` | trusted security/lifecycle audit events | denied |
| `notificationJobs/{jobId}` | server notification fan-out queue | denied |
| `internalRateLimits/{limitId}` | hashed-actor rate-limit windows | denied |

Unknown top-level and nested paths are denied by fallback rules.

## User documents

### `users/{userId}`

Current version 1 fields accepted by Rules include:

- `displayName`
- `dateOfBirth`
- `profileImagePath`
- `countryCode`
- `timeZoneId`
- `locale`
- `activeRelationshipId`
- `archivedRelationshipIds`
- `accountState`
- `createdAt`
- `updatedAt`
- `schemaVersion`

Only the owner may create or update the user document, and sensitive
relationship/account transitions remain constrained. Trusted Functions are
responsible for operations that cannot be safely authorized from one client
write.

### `users/{userId}/privatePreferences/{documentId}`

Owner-private configuration such as AI permissions. The owner is the only
client reader/writer, with a strict owner and version boundary.

### `users/{userId}/privateAIMemories/{memoryId}`

Private AI memory owned by that user. It is not relationship-readable.
Production still needs edit/delete/export use cases and retention cleanup.

All other user subcollections are denied by the nested fallback.

## Relationship document

### `relationships/{relationshipId}`

The server-created relationship record includes:

- exactly two `memberIds`
- `status`
- `relationshipType`
- optional `relationshipStartDate`
- invitation/source metadata where required
- lifecycle timestamps
- `schemaVersion`

The current invitation redemption transaction creates the relationship,
member documents, user active-relationship references, and relationship indexes
atomically. Clients cannot add members or change relationship lifecycle fields
directly.

Archived relationships remain readable to authorized members under the current
Rules, while new shared writes are denied.

### `relationships/{relationshipId}/members/{userId}`

Membership and member-owned settings, including:

- role and joined/updated timestamps
- feature permissions
- sharing settings
- notification settings
- AI settings
- `schemaVersion`

A member may update only their permitted self-owned settings. A partner cannot
enable another member's location, calendar, photo, notification, or AI sharing.
Membership creation/deletion and role escalation are trusted operations.

## Shared feature collections

| Path | Purpose | Important rule boundary |
| --- | --- | --- |
| `messages/{messageId}` | text/media/location message metadata | sender must equal authenticated caller; active relationship required |
| `messages/{messageId}/reactions/{userId}` | one member reaction | document ID/owner must match caller |
| `messages/{messageId}/readReceipts/{userId}` | member read state | caller may write only their own receipt |
| `memories/{memoryId}` | shared media timeline metadata | creator/owner and validated visibility; active relationship for writes |
| `sharedDays/{dateId}` | day container | member-readable; constrained member writes |
| `sharedDays/{dateId}/events/{eventId}` | deliberate day events | owner-controlled shared item |
| `milestones/{milestoneId}` | relationship milestone | owner-controlled shared item |
| `activities/{activityId}` | shared activities/plans | owner-controlled shared item |
| `voiceJournals/{entryId}` | voice journal metadata | creator ownership and relationship scope |
| `locations/{locationId}` | manual/temporary/coarse location records | owner setting, precision, and expiry checks |
| `insights/{insightId}` | trusted derived relationship insight | member read; client writes denied |
| `sharedAIMemories/{memoryId}` | relationship-visible AI memory | member boundary; creation/update remains restricted |

The concrete Rules file is authoritative for accepted fields and size/range
limits. Clients should use typed DTOs and repository adapters rather than
constructing collection paths in SwiftUI.

## Storage schema

| Object path | Intended content | Write rule |
| --- | --- | --- |
| `users/{userId}/profile/{fileId}` | profile image | owner only; approved image type; maximum 10 MiB |
| `relationships/{relationshipId}/messages/{messageId}/{fileId}` | message media | active member who owns the message; owner metadata required |
| `relationships/{relationshipId}/memories/{memoryId}/{fileId}` | memory media | active member who owns the memory; owner metadata required |
| `relationships/{relationshipId}/voice/{entryId}/{fileId}` | voice attachment | active member who owns the voice entry; validated audio type/size |
| `relationships/{relationshipId}/covers/{fileId}` | relationship cover image | active relationship member; validated image type/size |

Relationship media reads require authorized relationship access. Unknown
Storage paths are denied. Replacing an object must preserve the trusted owner
boundary. Production upload code must validate content independently, generate
derivatives safely, remove orphaned objects, and avoid treating content type
alone as proof of file safety.

## Callable Functions

### Implemented foundations

| Callable | Role | Current safeguards |
| --- | --- | --- |
| `createInvitation` | create a seven-day pairing invitation | Auth, App Check, active/unpaired user, strict input, secret-derived code, rate limit, idempotency, transaction, audit |
| `revokeInvitation` | revoke a pending invitation | Auth, App Check, creator check, strict input, rate limit, idempotent result, transaction, audit |
| `redeemInvitation` | atomically create a two-person relationship | Auth, App Check, secret hash check, expiry/replay checks, both users active/unpaired, transaction, indexes, audit |
| `secureAIProxy` | guarded private/shared AI request | Auth, App Check, consent/membership, strict task/input, rate limit, idempotency lease, Secret Manager key, HTTPS, validated output |

The callable configuration currently selects `europe-west2`. Production region
approval remains open; changing a deployed Functions region requires an
operations/migration plan rather than an unnoticed source edit.

### Deliberate fail-closed stubs

These exported callables authenticate and require App Check, then return
`unimplemented`:

- `createRelationship`
- `archiveRelationship`
- `resolveUnlinkingChoices`
- `exportAccountData`
- `deleteAccountData`
- `generateRelationshipInsight`

They are explicit contract placeholders, not completed features.

## Indexes

`firestore.indexes.json` is the source-controlled index declaration. Add an
index only for a reviewed query with a bounded/paginated access pattern. Index
deployment and query performance are not verified against a live project.

## Retention and TTL

Production must define and deploy retention behavior for:

- expired/revoked/redeemed invitations
- internal rate-limit windows
- AI request state and output
- notification jobs
- audit events
- deleted accounts and relationship tombstones
- orphaned Storage objects and derivatives
- local/offline caches

The current functions write expiry metadata for invitations, rate limits, and
AI requests, but no live Firestore TTL policy is configured.

## Environment isolation

Development, staging, and production must use distinct Firebase projects,
bundle identifiers, client configuration, App Check policies, budgets, and
operator access. The current `com.example.aven` namespace and Firebase project
names are placeholders.

Real `GoogleService-Info.plist`, service-account credentials, APNs keys,
invitation signing secrets, and AI provider keys stay outside Git. The local
test project ID `demo-aven-local` is emulator-only and cannot access
non-emulated services.

## Local validation

From `firebase/functions`:

```sh
npm run build
npm run lint
npm test
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  npm run test:rules
```

Verified locally on 2026-07-26:

- TypeScript production build: pass
- ESLint: pass
- test typecheck: pass
- unit tests: 4 pass
- Firestore/Storage emulator tests: 13 pass

The Rules suite requires Java 21 or newer. This validation does not replace a
staging deployment, App Check enforcement test, Functions integration test, or
load/security review.

## Schema change process

1. Document the new field/path, owner, visibility, and retention.
2. Update typed domain/DTO mappings without exposing paths to views.
3. Update Rules before or with the write path; preserve default deny.
4. Add emulator tests for owner, partner, non-member, archived, deleted, and
   malformed cases as relevant.
5. Add indexes and backfill/migration code when required.
6. Deploy to development, verify, then staging.
7. Observe rejects, performance, and cleanup before production rollout.
8. Increment `schemaVersion` only with a documented compatibility plan.
