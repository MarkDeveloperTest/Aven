# Aven Product Specification

## Document status

This is the product contract for the initial Aven iPhone application. It
describes intended behavior, not current implementation completion. Verified
delivery status lives in [PROGRESS.md](PROGRESS.md).

## Vision

Aven is a private, shared relationship space for dating, long-distance,
engaged, and married couples. It helps two existing partners communicate,
preserve memories, deliberately share parts of their day, reflect on their
connection, and plan time together.

The experience should be warm, modern, Apple-native, playful, and calm. It must
not diagnose a relationship, predict a breakup, assign blame, infer abuse or
infidelity, replace professional support, or present AI interpretations as
objective truth.

## Audience and launch scope

- Age access: no minimum age gate in the app
- Initial markets: United Kingdom, Ukraine, United States
- Launch languages: English and Ukrainian
- Platform: iPhone, iOS 26 or later
- Relationship model: one active relationship and multiple archived
  relationships per account
- Network model: two known people; no public profiles, discovery, matching, or
  open social graph

## Product principles

### Mutuality

Every shared feature explains what is shared, with whom, when sharing begins,
whether history is included, and how to stop. One partner cannot remotely turn
on the other partner's location, calendar, photos, microphone, notifications,
or AI access.

### Reversibility

Users can revoke permissions, stop sharing, remove eligible content, export
their data, delete their account, archive or leave a relationship, and preview
content outcomes before unlinking. Emergency unlinking must immediately stop
active sharing without requiring partner approval.

### Privacy by design

Permissions are requested in context rather than in a launch-time bundle.
Precise continuous location is off by default. Private content remains private
unless its owner explicitly changes visibility. Analytics and logs exclude
message bodies, journals, AI prompts, precise coordinates, media, and
identifying free text.

### Helpful, not judgmental

Insights describe activity and user-provided check-ins in neutral language.
The optional relationship score is an explained engagement summary, disabled
by default, never predictive, and never used in notifications.

## MVP capabilities

### Identity and onboarding

- Sign in with Apple and Google through Firebase Authentication
- Resume-safe onboarding with language, display name, date of birth, region,
  time zone, relationship status, optional image, and notification preferences
- Localized age gating with safe Remote Config defaults
- Account sign-out, export, and deletion paths

### Partner linking and lifecycle

- Private invite code, deep/universal link, QR code, email, and native share
  sheet
- Expiring, revocable, one-time invitations redeemed server-side
- Atomic relationship creation with exactly two members
- States for unpaired, invitation pending, active, paused, ending requested,
  ended, archived, and deletion pending
- Transparent archive, unlink, content-resolution, and emergency-stop flows

### Shared experience

- Adaptive home dashboard for unpaired, pairing, active, long-distance, and
  archived states
- Private one-to-one messaging with pagination, optimistic delivery, retry,
  replies, reactions, media, voice, read state, and offline-safe behavior
- Shared photo/video memory timeline with explicit metadata and visibility
- Shared Day timeline containing manual or explicitly configured events
- Optional, granular location sharing with precision, expiry, and persistent
  active-state indicators
- Descriptive relationship insights and mood/activity summaries

### Privacy and settings

- Account, relationship, privacy, AI, appearance, notification, and about
  sections
- Category-level permissions and an audit-friendly sharing summary
- Optional Face ID protection, app-switcher privacy, and generic notification
  previews by default
- Data export, account deletion, relationship archive, and emergency unlink

### AI

- Provider-independent routing across supported on-device and cloud providers
- On-device Apple Foundation Models preferred when appropriate and available
- Cloud calls only through an authenticated, App Check-protected server
- Initial tasks: conversation prompts, opted-in weekly summaries, shared
  activity suggestions, considerate message drafts, memory captions, authorized
  memory search, neutral trend explanations, and suggested connection times
- Master, on-device-only, cloud, category, private-memory, and shared-memory
  controls
- Output is labeled, editable, dismissible, regeneratable, reportable, and
  never sent automatically

## Data and content rules

Every shared item records its creator, ownership, relationship, visibility,
timestamps, deletion state, archive state, and AI permission state. Unbounded
data uses paginated subcollections. User-generated content retains its original
language.

Private journals and private AI memory never appear to a partner unless the
owner explicitly shares the specific content. Exact coordinates and full
private calendar contents are not stored when a coarse event or derived
availability is sufficient.

## Offline and failure behavior

Firebase is the shared cloud source of truth. SwiftData may cache selected
profiles, relationship summaries, recent messages, thumbnails, drafts, pending
uploads, UI preferences, and permitted AI results. Synchronization must model
pending state, conflicts, retries, and deletion tombstones explicitly. Deleted
remote content must not be silently restored.

Every major screen needs loading, empty, offline, failure, and retry states.
Errors shown to users are localized and do not expose developer detail.

## Accessibility and quality

Primary flows must support VoiceOver, Dynamic Type, sufficient contrast,
non-color indicators, reduced motion, reduced transparency, accessible media,
and appropriate touch targets. Dates, time zones, pluralization, measurements,
and relative time must be locale-aware.

## Explicit non-goals for the first release

- Public dating discovery, stranger matching, or follower graphs
- Disappearing messages unless a complete secure design is delivered
- Claims of audited end-to-end encryption
- Continuous background analysis of all conversations
- Automatic full-library photo or calendar upload
- HealthKit without a concrete, consent-driven product need
- Payment gates during the free beta
- Relationship diagnosis, partner surveillance, or manipulative engagement

## Release acceptance

The MVP is not complete until the app builds and runs, required flows are
implemented rather than represented by inert controls, English and Ukrainian
are present, iOS 26 compatibility is exercised, security and emulator tests
pass where the toolchain permits, no secrets are committed, and all unresolved
developer-account, backend, legal, privacy, and App Store actions are listed.
