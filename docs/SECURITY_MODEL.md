# Aven Security Model

## Overview

Aven is a two-user, privacy-sensitive iPhone application backed by Firebase.
It handles identity, relationship membership, private communications, media,
location-derived moments, calendar-derived availability, mood/reflection data,
and optional AI context. Harm can arise from an external attacker, a malicious
or formerly authorized partner, a compromised device/account, a forged client,
misconfigured backend rules, or an over-privileged operator.

This is a repository-wide design threat model, not a completed security audit.
At the foundation stage, controls below remain requirements until their app,
Rules, Functions, and test evidence are reviewed; scaffold files alone do not
close them.

## Threat Model, Trust Boundaries, and Assumptions

### Assets and security objectives

Protect:

- authentication sessions and account recovery paths
- relationship membership and lifecycle authority
- private versus shared content boundaries
- messages, journals, photos, video, voice, and AI memory
- exact location, location history, and calendar detail
- invitations and deep links
- export, deletion, archive, and unlinking choices
- backend secrets, service credentials, signing material, and push keys
- notification privacy, analytics, logs, and audit integrity

The primary objectives are confidentiality between unrelated users and between
private partner scopes, integrity of membership/content ownership, immediate
revocability of sharing, availability of account/export/delete operations, and
honest communication about protection limits.

### Actors and inputs

### Attacker-controlled

- all iOS client requests, including modified or replayed requests
- invitation codes, universal links, QR payloads, and email parameters
- profile fields, messages, filenames, content types, captions, reactions, and
  timestamps proposed by clients
- uploaded media and metadata
- pagination cursors, document IDs, relationship IDs, and Storage paths
- AI prompts, selected context, generated provider output, and tool payloads
- push/deep-link payloads received by the device

### User-controlled but sensitive

- permission choices, visibility, sharing precision and expiry
- unlink/archive/delete/export selections
- private and shared AI-memory consent
- user-selected calendars, photos, microphone recordings, and location modes

### Operator/developer-controlled

- Firebase projects, Rules, indexes, Functions, IAM, Secret Manager, App Check,
  Remote Config, analytics schemas, retention, and region
- Apple signing, entitlements, APNs, Associated Domains, and App Groups
- localization, legal URLs, provider configuration, and release flags

Operator-controlled configuration is trusted only after least-privilege review
and deployment verification. Remote Config is not an authorization boundary.

### Trust boundaries and assumptions

1. **Device to Firebase:** TLS protects transport, but the client is untrusted.
   Authentication, App Check, Rules, validation, and server-side authorization
   are independently required.
2. **User to partner:** Authentication does not imply access to the partner's
   private documents, settings, AI memory, raw calendar, or unshared location.
3. **Relationship tenant boundary:** Every relationship-scoped read/write must
   prove current authorized membership and applicable lifecycle/archive state.
4. **Client to privileged Functions:** Invitations, membership, role changes,
   lifecycle resolution, export/delete, cloud AI, counters, and rate-sensitive
   actions are server-mediated and idempotent.
5. **Firestore to Storage:** A valid media path does not by itself prove content
   ownership or relationship access. Storage authorization and metadata must
   agree.
6. **App to external AI:** On-device processing stays on device; cloud context
   crosses into trusted backend and provider boundaries only with explicit
   consent and minimization.
7. **Local cache and OS surfaces:** SwiftData, Keychain, notifications, widgets,
   app-switcher snapshots, pasteboard, and backups can expose content outside
   the main UI and require separate privacy controls.
8. **Admin boundary:** Firebase/Google Cloud operators can access backend data
   according to IAM. Aven does not claim E2EE, and backend compromise remains in
   scope.

### Required invariants

- A user cannot read another user's private data by knowing an ID.
- A partner cannot change the other partner's permissions or consent.
- Clients cannot add themselves to a relationship or forge a sender/creator.
- A relationship has at most two valid members; a user has at most one active
  relationship.
- Invite redemption is one-time, expiring, revocable, rate-limited, and atomic.
- Stopping sharing or emergency unlinking never requires partner approval.
- Exact location is never enabled remotely or by default and expires as shown.
- Private AI context never enters shared output without item-level permission.
- Cloud provider keys and service credentials never ship in the app or Git.
- Audit records and privileged server fields are server-write-only.
- Deleted or revoked data is not silently restored from an offline cache.
- AI-generated text is labeled and never sent as the user without confirmation.
- Analytics, crash reports, and logs exclude private content and exact location.

## Attack Surface, Mitigations, and Attacker Stories

### Authentication and sessions

Risks include nonce replay, provider confusion, stolen sessions, incomplete
Apple credential-state handling, and account deletion that leaves data behind.
Use Firebase Authentication as canonical identity, cryptographically secure
Apple nonces, provider linking controls, Keychain only where appropriate, token
revocation, reauthentication for destructive actions, and deletion tests.

### Invitations and membership

An attacker may enumerate short codes, replay an invitation, race a second
redemption, or submit forged member IDs. Store only minimally exposed
invitation data; keep the full random token high entropy; expire, revoke, and
rate-limit; redeem through an authenticated Function transaction; and test
replay, concurrency, and escalation.

### Firestore tenant boundaries

Object-level authorization failure could expose an entire relationship. Rules
must derive identity from `request.auth.uid`, compare stored trusted membership,
validate immutable ownership fields, deny internal collections, constrain
updates field-by-field, and enforce archive policy. Do not authorize a write
solely from membership values supplied in that same write.

### Media and Storage

Malicious uploads may spoof extensions/content types, exceed limits, exploit
processing, or remain orphaned after deletion. Validate authenticated
membership, path, ownership, declared and inspected media type, and size.
Process derivatives in constrained server code, strip unnecessary metadata,
avoid unsafe filename handling, and run idempotent cleanup.

### Messaging, offline queues, and notifications

Clients may forge senders/timestamps, duplicate queued writes, access unbounded
history, or leak content on lock screens. Use server timestamps, immutable
sender identity, idempotency keys, pagination, lifecycle-aware authorization,
generic notification previews by default, and redacted widget/app-switcher
states. Firebase protections must not be described as E2EE.

### Location and calendar

A partner or forged client may attempt silent activation, over-precise storage,
expired-session access, or calendar-detail exfiltration. Consent is individual;
precision and expiry are stored and enforced; active sharing is visibly
indicated; revocation is immediate; derived/coarse values are preferred; and
full calendar/event details remain local unless a narrow purpose is explicit.

### AI

Threats include prompt injection through user content, cross-user context
leakage, provider-key extraction, excessive retention, unsafe output, and
authorization bypass at the proxy. Treat all content/model output as data,
construct context from server-authorized records, minimize identifiers, verify
Auth and App Check, validate typed input/output, rate-limit, redact logs, store
provider secrets in Secret Manager, and require user confirmation before send.
AI does not make authorization or high-impact relationship decisions.

### Lifecycle, export, and deletion

A malicious or former partner may retain access after unlinking, delete another
person's private content, or block departure. Relationship state transitions
must be server-controlled and auditable. Emergency unlink immediately revokes
sharing and notifications. Export and shared-content resolution honor
ownership, visibility, contribution, separate archive state, and dual-consent
deletion rules without blocking account access.

### Remote configuration and observability

Remote Config could accidentally weaken age, AI, upload, or rollout behavior,
but it must never grant authorization or bypass App Review. Use safe local
defaults, typed limits, constrained ranges, staged rollouts, and change review.
Logs, Analytics, Performance, and Crashlytics use redaction and allowlisted
fields only.

## Severity Calibration

### Critical

- Unauthenticated or cross-tenant access to messages, private AI memory, media,
  or location at broad scale
- Client-controlled relationship membership or administrator-equivalent
  privilege
- Production service credentials or cloud AI keys committed or embedded in the
  app with material access

### High

- A partner can enable or continue precise location after revocation
- Invitation replay/race creates an unauthorized active relationship
- Private journal or AI memory appears in partner-facing output
- Account deletion or emergency unlink leaves active sharing sessions usable

### Medium

- Notification/widget/app-switcher previews reveal limited sensitive content
  contrary to the selected privacy mode
- Missing upload bounds enables meaningful storage or processing abuse
- Analytics records stable identifiers or relationship metadata outside the
  approved schema without direct content exposure

### Low

- Redacted diagnostics reveal low-sensitivity implementation metadata
- A local-only UI inconsistency delays a visible expiry indicator while backend
  authorization has already revoked access
- Non-security copy or preference issues with no confidentiality, integrity, or
  availability impact

Severity depends on reachability, affected population, data sensitivity,
duration, and whether a former or current partner can exploit the behavior.

## Out of scope and non-assumptions

- The model does not assume a trusted partner.
- It does not assume App Check proves user identity or makes a client trusted.
- It does not claim protection from a fully compromised unlocked device.
- It does not claim E2EE, anonymous use, or zero operator access.
- Public discovery and third-party media rebroadcast are outside the initial
  product.
- A future E2EE design requires a separate threat model for key generation,
  multi-device sync, recovery, backups, moderation, migration, and deletion.

## Validation obligations

Before production, verify Rules and Storage policies in the Firebase Emulator;
exercise forged identity, non-member, archive, replay, location, and AI-memory
cases; inspect dependency/secret history; review entitlements and privacy
manifest; and test revocation, export, deletion, and emergency unlink end to
end. No control in this document should be marked implemented without evidence.

Repository: local-workspace-sha256:1980bc6e4bbfeec33f9d1c25b33902ad5001ba74e128bbd263098d1f36b51534
Version: codex-security-snapshot/v1:sha256:775c9c1dc87d58772ebb38e96e101649b7ac7b71275def42dcd021c7b8569a7e
