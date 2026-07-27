# Aven Privacy Model

## Status

This document defines Aven's privacy contract and identifies what the current
repository actually enforces. A local iOS shell, privacy manifest, permission
copy, Firestore/Storage Rules, and guarded callable foundations exist. No live
Firebase project, real account-provider integration, production data flow, or
completed export/deletion/unlink workflow has been verified.

Aven does not currently claim end-to-end encryption. Firebase transport and
storage protections are not equivalent to E2EE.

## Core rules

1. A person may access their own private data.
2. Shared relationship data is available only to current authorized members.
3. A partner cannot grant a permission or enable sharing on another person's
   behalf.
4. New sensitive categories are off until their purpose is explained and the
   relevant person opts in.
5. Sharing state must show what is shared, with whom, when it started, whether
   history is included, and how to stop.
6. Revocation stops new collection and sharing immediately.
7. Private data does not become shared through inference, caching, AI, export,
   notification content, or relationship membership.
8. Archived access and unlinking outcomes are explicit and read-only where
   applicable.
9. Remote configuration may reduce or disable behavior, but must not grant data
   access or silently broaden consent.

## Data visibility classes

| Class | Examples | Authorized readers | Current repository state |
| --- | --- | --- | --- |
| Device-local | onboarding draft, UI language, experiment toggle | the local app user | Implemented with local development storage; production protection and cleanup need review |
| User-private | private preferences, private AI memory | owner and trusted backend | Firestore path and Rules scaffold exist; no iOS Firebase adapter |
| Relationship-shared | messages, memories, Shared Day, milestones | active members; archived reads only where defined | Rules scaffold exists; iOS features currently use in-memory demo data |
| Sensitive derived | insights, availability windows, coarse location moments | only the scope and consent that produced them | Target contract; production generation not implemented |
| Trusted internal | invitations, AI request state, rate limits, audit and notification jobs | trusted server/operators only | Client reads/writes denied by Rules |
| Operational telemetry | redacted security events, crash/analytics metadata | least-privileged operators | Logging foundation exists; production services and retention are not configured |

## Category model

| Category | Collection or use rule | Sharing rule | Deletion/revocation expectation |
| --- | --- | --- | --- |
| Account/profile | collect only fields required for eligibility and service | display name/profile details only in an authorized relationship | editable; deleted with account subject to approved legal holds |
| Date of birth | used only for profile personalization | never shown to a partner by default | minimize precision/retention where policy allows |
| Authentication | Firebase is the canonical identity target | provider/token details are never partner-visible | revoke sessions and provider linkage during deletion |
| Messages/reactions | user-created shared content | current relationship members | user actions and unlink policy must define deletion outcome |
| Memories/media | only explicitly selected items | chosen relationship scope | remove metadata, Storage objects, derivatives, and local cache |
| Shared Day | deliberate shared events | current relationship members | removable; remote deletion must not be resurrected offline |
| Location | off by default; prefer coarse/derived events | independently enabled by the owner with precision and expiry | stop immediately, expire automatically, remove unnecessary history |
| Calendar | read only selected calendars/data needed for a purpose | share derived availability rather than raw event titles | revoke access and delete uploaded/derived data |
| Photos | use explicit selection; no broad analysis by default | share only selected media | remove original, derivatives, cache, and references |
| Microphone/speech | purpose-specific recording only | share only after explicit user action | stop capture and remove local/cloud artifacts |
| Notifications | generic/private preview defaults | device owner controls category and preview | token removal and preference cleanup on sign-out/deletion |
| Private AI | explicit per-user permission and context selection | never partner-visible | view, edit, remove, export, and delete |
| Shared AI | both members opt in and source categories are shared | current members only | either member can revoke future use; unlink policy resolves memory |
| Analytics/crash | minimal diagnostics without private payloads | never partner-visible | retention and deletion behavior documented by legal/operations |

## Consent lifecycle

Each sensitive permission should move through explicit states:

```text
not requested -> explained -> enabled
                       |          |
                       v          v
                    declined <- revoked
```

OS authorization and Aven sharing consent are separate. An OS permission does
not automatically permit cloud upload or partner sharing. Aven must record the
purpose, category, scope, precision, historical-data choice, start/expiry, and
current state needed to explain behavior. Avoid storing consent prose or
unbounded audit history in client-readable documents.

The current settings UI exposes early permission summaries, but complete
category workflows, OS settings reconciliation, sharing audits, and backend
consent records remain to be built.

## Relationship lifecycle

A user may have one active relationship and archived relationship history.
Pairing, membership, archive, unlink, and emergency unlink are privileged state
transitions.

The current backend implements transactional invitation create, revoke, and
redeem foundations. Direct client access to invitation records and direct
relationship/membership escalation are denied. Archive, unlinking-choice
resolution, export, and deletion callables deliberately return
`unimplemented`; local UI actions do not constitute server-side completion.

Before unlinking, both people must receive a clear explanation of:

- when shared access stops
- which items remain in a private or archived copy
- which items are deleted
- how joint items with different choices are resolved
- whether media derivatives, notifications, AI memory, and caches are included

Emergency unlink prioritizes immediate access removal. It must not notify the
other person in a way that creates a safety risk without an explicit reviewed
product policy.

## Authorization and server trust

Firestore and Storage Rules derive identity from Firebase Auth and trusted
stored membership. Clients must not be trusted to assert owner IDs, sender IDs,
roles, membership, timestamps, consent, or lifecycle state.

Trusted callable operations additionally require:

- Firebase Authentication
- App Check
- active-account validation
- strict input schemas
- relationship membership and permission checks where relevant
- replay/idempotency handling
- rate limits
- redacted logs

Local emulator tests currently verify representative member/non-member,
cross-user private-data, forged-sender, membership-escalation, invitation,
archive, AI-memory, location, and media boundaries. Production enforcement is
not proven until reviewed rules/functions are deployed and valid/invalid App
Check traffic is tested.

## Local cache and offline privacy

Firebase is the intended shared source of truth. Local storage may cache only
the data needed for useful offline behavior. Every cached record needs scope,
server version, pending/deleted state, and cleanup behavior.

Required safeguards include:

- encrypt/protect sensitive local files using appropriate platform protection
- exclude private content from app-switcher snapshots where configured
- stop listeners and clear relationship-scoped state on sign-out or unlink
- honor remote tombstones so deleted cloud data is not re-uploaded
- bound media caches and remove derivatives with their source
- avoid placing auth tokens in custom persistence when Firebase Auth owns them

The current demo stores are not a production offline implementation.

## AI privacy

On-device processing is preferred when capability, quality, language, and user
settings allow it. Cloud AI requires separate opt-in for each relevant context
category. A provider key never belongs in the app.

Cloud requests use the smallest authorized context. Raw prompts and generated
relationship content are excluded from logs by default. Shared AI requires
both membership and mutual shared-AI enablement. See
[AI_ARCHITECTURE.md](AI_ARCHITECTURE.md).

## Telemetry and notifications

Analytics, Crashlytics, security logs, and notification payloads must not
contain messages, journals, photo data, AI prompts/outputs, exact coordinates,
invitation secrets, auth tokens, or direct identifiers by default.

Use typed event names, opaque identifiers or aggregates, explicit preview
controls, quiet hours, and generic notification modes. Production event
schemas, retention, and access reviews remain open.

## Age and regional behavior

The current product floor is age 16. The app has local date-of-birth validation
and localized messaging. Region-specific legal text, remotely configurable age
policy, and production enforcement are not complete. A remote minimum-age
change must fail safely and must not encourage falsified data.

## User rights

The production product must provide:

- access to and correction of profile/settings data
- portable export of private and shared data the user is entitled to receive
- account deletion with reauthentication
- relationship archive and unlink controls
- media and AI-memory removal
- permission and sharing revocation
- a comprehensible record of active sharing

The current settings surface includes placeholders/actions, but end-to-end
export, deletion, cleanup, and legal response workflows are not implemented.

## Release gates

- [ ] Data inventory and retention schedule approved for each launch region
- [ ] Privacy policy, terms, support identity, and legal entity finalized
- [ ] App Store privacy answers match observed production behavior
- [ ] Privacy manifest and required-reason APIs reviewed against final binaries
- [ ] Every OS permission has accurate English and Ukrainian purpose text
- [ ] Sharing consent, expiry, history, and revocation work end to end
- [ ] Export, delete, archive, unlink, and emergency unlink are verified
- [ ] Local cache and notification-preview cleanup are tested
- [ ] Firebase Rules, Storage Rules, Functions, and App Check are deployed and
      tested against valid and invalid traffic
- [ ] AI provider terms, context controls, memory lifecycle, and logging are
      reviewed
- [ ] No unsupported E2EE, clinical, safety, or predictive claim appears
