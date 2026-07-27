# Aven Delivery Roadmap

## Status and method

The repository has moved beyond an empty foundation: it contains a verified
local iOS app shell and a locally validated Firebase backend/security scaffold.
Most user-facing features are development/demo implementations and are not yet
connected to Firebase.

Work proceeds in vertical slices. A phase is complete only when its behavior,
failure paths, localization, privacy controls, tests, and external actions have
evidence. Later phases may be scaffolded while an earlier external dependency
is blocked, but scaffolding does not change completion status.

## Phase plan

| Phase | Current state | Delivered locally | Completion gate |
| --- | --- | --- | --- |
| 0. Assessment | Verified | repository/toolchain/security baseline | evidence recorded and blockers identified |
| 1. Project foundation | Verified on iOS 27; iOS 26 open | project generator, configurations, Swift 6 concurrency, design system, EN/UK catalogs, app/unit/UI targets, privacy manifest | iOS 26 runtime matrix and final asset/identity review |
| 2. Firebase foundation | In progress | Rules, indexes, Storage Rules, Node 22 Functions, emulators, validated unit/rules suites | projects, Apple SDK adapters, deployment, App Check and staging integration |
| 3. Authentication/onboarding | In progress | repository seams, Apple nonce/UI foundation, Google SDK/Firebase credential exchange, persisted onboarding without an age gate, region-based language; demo auth removed | enable/verify Google provider, real Apple/Google device flows, revocation/link/delete and device/UI tests |
| 4. Pairing/lifecycle | In progress | local invitation UI; transactional create/revoke/redeem Functions | iOS adapter, emulator integration, archive/unlink/export/delete operations |
| 5. Navigation/home | In progress | five-tab shell, unpaired/active local dashboard states | repository-backed live state, loading/offline/error/accessibility coverage |
| 6. Messaging | In progress | local composer, send validation, timeline UI | paginated Firestore sync, reactions/receipts/media, offline queue and push |
| 7. Memories | In progress | explicit PhotosPicker selection and local timeline | Storage upload/derivatives/cache, visibility, cleanup, pagination and tests |
| 8. Shared Day/location | In progress | local Shared Day event timeline | repository sync plus granular location modes, expiry/revocation and audits |
| 9. Insights | In progress | neutral summary UI and disabled-by-default score experiment | deterministic inputs, factor controls, consent, cadence and test evidence |
| 10. AI | In progress | secure callable foundation and server task allowlist | Swift router/providers/context, provider setup, memory lifecycle and quality tests |
| 11. Apple integrations | Not started | capability documentation only | privacy-aware widget plus reviewed App Intents/Live Activity/SharePlay/EventKit slices |
| 12. Hardening/release | In progress | baseline docs, privacy manifest, unit/UI suites | full test/accessibility/security/performance matrix and App Store checklist closed |

Detailed observed status lives in [PROGRESS.md](PROGRESS.md).

## Critical path to a backend-connected alpha

1. Finalize the non-production bundle namespace and create a development
   Firebase project.
2. Add only the required Firebase Apple SDK products and environment-safe plist
   selection.
3. Implement concrete authentication/session/profile repositories.
4. Connect Sign in with Apple and Google Sign-In; verify returning, revoked,
   linking, sign-out, and delete paths.
5. Connect onboarding profile creation and enforce the age/account state on the
   server.
6. Connect invitation create/revoke/redeem callables and live relationship
   state.
7. Replace local message/memory/day stores with repository-backed paginated
   listeners and explicit offline state.
8. Deploy reviewed rules/functions to development with App Check observability.
9. Run unit, emulator, integration, UI, accessibility, and privacy checks in
   both languages.

## MVP completion sequence

### Milestone A - Private account foundation

- real authentication and session restoration
- profile/onboarding persistence
- region/time-zone and age-policy configuration
- settings, sign-out, deletion prerequisites
- Firebase environment isolation and redacted observability

### Milestone B - Safe two-person space

- server-mediated pairing
- membership/lifecycle state machine
- active/archive/unlink behavior
- mutual permission summary and sharing audit
- end-to-end Rules/App Check tests

### Milestone C - Core shared experience

- messages, reactions, receipts, notifications
- shared photo memories
- Shared Day timeline
- pagination, offline queues, retries, tombstones, and cleanup
- private notification previews and localized failure recovery

### Milestone D - Insights and AI

- deterministic non-clinical insights
- disabled-by-default optional engagement score
- on-device capability adapter
- cloud proxy integration with explicit context consent
- private/shared AI memory lifecycle
- English/Ukrainian safety and quality evaluation

### Milestone E - Apple integrations

- one useful privacy-aware widget
- App Intent actions with safe authentication/confirmation behavior
- only genuinely time-bound Live Activities
- reusable SharePlay foundation
- selected-calendar EventKit integration using derived availability

Each integration is independently releasable and must have a useful fallback.

### Milestone F - Release candidate

- iOS 26 and current iOS runtime/device matrix
- accessibility, localization, performance, energy, offline, and migration tests
- production Rules/Functions/App Check and operational runbooks
- export, deletion, archive, unlink, and emergency unlink verification
- privacy/legal/provider review
- final app icon, metadata, screenshots, review notes, and TestFlight evidence

## Deliberate deferrals

The first release excludes public discovery, stranger matching, an open social
graph, manipulative streaks, predictive/clinical relationship judgments, and
unsupported E2EE claims. Advanced Apple integrations should not delay a safe,
complete core two-person experience unless they are part of the approved
release scope.

## Exit criteria

The MVP is ready for submission only when:

- core flows use real repositories rather than development stores
- one user's client cannot cross relationship/private boundaries
- sensitive sharing is explained, independent, visible, expiring where
  appropriate, and reversible
- the app works usefully offline and reconciles deletions correctly
- AI is provider-safe, consent-aware, editable, and never auto-sent
- English and Ukrainian UX/accessibility are complete
- full local, emulator, staging, UI, and compatibility evidence passes
- every open item in [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) required
  for the chosen release scope is closed
