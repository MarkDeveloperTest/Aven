# Aven Progress

- **Last updated:** 2026-07-27
- **Overall status:** Local product foundations and development Firestore Rules implemented; live feature integration in progress
- **App Store readiness:** Not ready

## Status rules

- **Verified:** directly observed through files or command output
- **In progress:** work has started but acceptance evidence is incomplete
- **Not started:** no implementation evidence recorded
- **Blocked externally:** local work can continue, but a credential, console,
  developer-account, legal, or toolchain action is required for completion

Files, plans, package declarations, or documentation alone do not establish a
working feature.

## Phase status

| Phase | Status | Evidence / next gate |
| --- | --- | --- |
| 0 — Repository assessment | Verified | Environment and empty starting repository inspected; findings below. |
| 1 — Project foundation | Verified on iOS 27; runtime compatibility open | Generated Xcode project, three environments, Swift 6 strict concurrency, EN/UK catalogs, design system, privacy manifest, unit/UI targets, Firebase-enabled Debug build, and build-for-testing pass. Simulator launch, completed Swift test execution, iOS 26, and final assets remain open. |
| 2 — Firebase foundation | In progress | Live development project `aven-ios-dev-4f7c2`, registered iOS app, Apple Authentication provider, `europe-west2` Firestore database, deployed Firestore Rules, and five deployed composite indexes are verified. Firebase Apple SDK 12.16.0 bootstrap/repository integration builds. Functions build/lint, 10 unit tests, 18 Rules tests, 7 Firestore integration tests, and the production dependency audit pass locally. App Check, Storage, Functions, FCM, TTL policies, staging, and production remain open. |
| 3 — Authentication/onboarding | In progress | Firebase Apple Auth is enabled; the app has Apple nonce/sign-in handling, Google Sign-In 9.0.0 and Firebase credential exchange, an automatically provisioned signed Apple capability, profile repository adapters, fail-closed provider behavior, and persisted onboarding without an age gate. The premium white-and-baby-pink sign-in and focused onboarding flow compile with stable string persistence, legacy draft migration, region-based EN/UK selection, and no step/progress or vertical scrolling UI. Demo authentication has been removed. A completed user login and visual comparison still need device/runtime verification, and saving the Google provider/OAuth client plus refreshing the local Firebase plist remain pending. |
| 4 — Pairing/lifecycle | In progress | Local invitation UI exists; callable create/revoke/redeem foundations use transactions, expiry, idempotency, rate limits, App Check, and audit records. iOS integration and archive/unlink/export/delete remain open. |
| 5 — Navigation/home | In progress | Five-tab iPhone shell and local unpaired/active dashboard states compile. Repository-backed live/offline state is not implemented. |
| 6 — Messaging | In progress | Local composer/timeline and blank-message validation exist. Firestore sync, media, reactions, receipts, pagination, offline queue, and push are not implemented. |
| 7 — Memories | In progress | Explicit PhotosPicker selection and a local timeline exist. Storage upload, derivatives, cache, visibility, pagination, and cleanup are not integrated. |
| 8 — Shared Day/location | In progress | Local Shared Day event UI exists. Cloud sync and granular location sharing/expiry/revocation are not implemented. |
| 9 — Insights | In progress | Neutral local summary UI and a disabled-by-default score experiment exist. Production inputs, factor controls, cadence, and consent-aware computation are not implemented. |
| 10 — AI | In progress | Consent-aware Swift request/context models, router, provider seams, guarded service, redacted logging, and guarded callable proxy foundation exist. No real on-device or cloud provider is configured, and no production AI generation flow has been verified. |
| 11 — Apple integrations | In progress | A privacy-minimizing WidgetKit extension, shared widget state, App Intents, and App Shortcuts foundation exist. Live Activity, SharePlay, EventKit, production App Group/signing, and device validation remain open. |
| 12 — Production hardening | In progress | Privacy/security/store documentation and initial unit/UI/emulator suites exist. Full Swift/UI, accessibility, performance, security, signed release, and store validation remain open. |

## Phase 0 evidence

Verified on 2026-07-26:

- The repository began without an existing application/Xcode project or Git
  commit.
- `/Applications/Xcode-beta.app` exists.
- With its developer directory selected, `xcodebuild -version` reports:
  - Xcode 27.0
  - build `27A5209h`
- `xcodebuild -showsdks` reports iOS 27.0 and iOS Simulator 27.0 SDKs.
- `swift --version` reports Apple Swift 6.4.
- CoreSimulator lists iOS 27.0 plus older iOS 18.x runtimes, but no iOS 26
  runtime.
- The active developer path is `/Library/Developer/CommandLineTools`, so
  unqualified `xcodebuild` does not currently select the Xcode app.
- No Firebase app configuration or credentials were present at the Phase 0
  assessment. A development project and untracked local app configuration were
  added later; see the current Firebase status below.
- The initial Git branch is `main` with no commits.

## Build and test status

| Check | Status | Notes |
| --- | --- | --- |
| Project parses/builds | Verified | `xcodebuild` successfully loaded `Aven.xcodeproj` and scheme `Aven`. |
| Debug build, iOS 27 simulator | Verified | Firebase SDK-enabled build passed for iPhone 17 Pro simulator UDID `E2199CB4-D13B-4014-B5CB-BEF9827EE995`. |
| Signed Debug device build | Verified | Generic iOS device build passes with automatic provisioning for `com.example.aven.dev`; the signed app contains the Apple sign-in and App Group entitlements. |
| Staging configuration build | Not yet verified | Configuration contract defined; run after project creation. |
| Release configuration build | Not yet verified | Signing/backend placeholders must fail safely. |
| Build for testing | Verified | Firebase-enabled app, Swift unit-test bundle, and UI-test bundle compile for the iOS 27 simulator. |
| Swift unit tests | Blocked by beta simulator tooling | Suites compile. Xcode 27 beta remained blocked for 130 seconds while “waiting for workers to materialize” and “initiating test runner session”; no tests executed. |
| Full UI tests | Not yet proven | Two XCUITest flows exist and compile; the full test invocation has not produced a completed passing result. |
| Firebase Functions build/lint | Verified | TypeScript build, ESLint, and test typecheck pass locally. |
| Firebase unit tests | Verified | 10 tests pass locally. |
| Firebase Emulator Rules tests | Verified | 18 Firestore/Storage tests pass locally using Java 21. |
| Firebase Firestore integration tests | Verified | 7 tests pass locally using Java 21. |
| Firebase production dependency audit | Verified | `npm audit --omit=dev --audit-level=high` reports zero high-severity vulnerabilities. |
| Development Firebase deployment | Partially verified | Default Firestore database, reviewed Rules, five composite indexes, Firebase Authentication, and Apple provider are live. Anonymous Firestore access returns `403 PERMISSION_DENIED`; an invalid Apple token reaches the enabled provider and is rejected as an invalid IDP response. TTL policies, Storage, Functions, Google Auth, App Check, and FCM are not live. |
| iOS simulator launch | Blocked by beta simulator tooling | Existing and fresh disposable iOS 27 devices report Booted, but CoreSimulator hangs on app install. No launch/UI claim is made. |
| iOS 26 compatibility | Blocked externally | No iOS 26 runtime is installed. |

The current intended validation destination is `iPhone 17 Pro`, iOS 27.0, using
`Aven.xcodeproj`, scheme `Aven`, and `Debug`. A passing iOS 27 build will not by
itself verify the iOS 26 requirement.

## Security status

- Security invariants and threat boundaries are documented in
  [SECURITY_MODEL.md](SECURITY_MODEL.md).
- Firestore Rules, Storage Rules, callable Functions, and local emulator
  security tests are present. The 18-test Rules suite and 7-test Firestore
  integration suite pass locally.
- Reviewed Firestore Rules are deployed only to the development project. This
  is not a production security audit: valid and invalid App Check traffic has
  not been exercised, Storage/Functions are not deployed, and several
  privileged lifecycle operations remain fail-closed stubs.
- The development Firebase app plist is present only as an ignored local file.
  No provider secret, service-account credential, or production credential is
  committed.
- No E2EE implementation or claim exists.
- Security documentation is a design requirement, not evidence of an audit.

## External actions

The immediate external gates are:

- select Xcode beta explicitly for command-line builds
- install/provide an iOS 26 runtime or device/CI target
- approve final brand, legal values, bundle identifiers, and Apple team
- create isolated staging and production Firebase projects and supply their
  local untracked configuration
- choose the production region and explicitly approve billing before deploying
  TTL policies or other billing-dependent services
- configure authentication, APNs, App Check, entitlements, and legal/store data

See [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md) for exact actions and verification.

## Known limitations

- The app shell and local/demo feature behavior compile, but shared features are
  not connected to Firebase.
- The live development project currently provides Apple Authentication,
  Firestore, deployed Rules, and five composite indexes; Google Authentication,
  App Check, Storage, Functions, FCM, staging, and production remain pending.
- Firebase Apple SDK and Google Sign-In integration build, but live client behavior is not yet
  verified because the available Xcode 27 beta simulator service cannot install
  the app.
- iOS 26 runtime behavior is unknown.
- Xcode 27 is beta, while the product requirement calls for compatibility with
  the current stable release environment; toolchain drift must be reviewed.
- Product name, legal details, production identifiers, region, retention, and
  cloud AI policy are unresolved.

## Session log

### 2026-07-27 — Region language and all-ages onboarding

- Removed the age gate, its validator, validation error, tests, and 16+ product
  copy; date of birth now accepts any non-future date.
- Removed vertical page scrolling from authentication and onboarding. Native
  wheel date pickers were restored in the following design revision.
- Removed the authentication and Settings language pickers. First launch now
  infers English or Ukrainian from region, and onboarding country selection
  updates and persists the corresponding language.
- Removed the visible unspecified relationship type and the relationship-date
  “prefer not to add” option. Legacy unspecified drafts migrate to Dating.
- Added region-language, all-ages, and legacy-draft coverage.
- Revalidated the app, Swift unit-test bundle, and UI-test bundle with Xcode 27
  beta; `build-for-testing` succeeded.

### 2026-07-27 — Premium onboarding redesign

- Rebuilt authentication and onboarding around the selected white-and-baby-pink
  reference, with permanent light appearance and focused screens.
- Removed step counts, progress bars, dots, segmented progress, and loading
  progress indicators from the onboarding surface.
- Added stable string step persistence, legacy numeric-step migration,
  conditional notification-preview navigation, and expanded unit/UI coverage.
- Added localized English and Ukrainian copy for the separated flow.
- Revalidated the Debug app and both test bundles with Xcode 27 beta:
  `build-for-testing` succeeded.
- Booted iPhone 17 Pro successfully, but app installation stalled. The bounded
  unit-test runner remained at “waiting for workers to materialize” and was
  interrupted after 62.5 seconds, so runtime and visual validation remain open.
- Recorded the blocked visual comparison in `design-qa.md`.

### 2026-07-27 — Development Firebase foundation

- Created `aven-ios-dev-4f7c2` and registered `com.example.aven.dev`.
- Created the default Firestore database in `europe-west2` and deployed the
  reviewed Firestore Rules and five composite indexes.
- Verified that anonymous live Firestore access is denied with HTTP 403.
- Kept the downloaded plist local and ignored; no secrets were committed.
- Added Firebase Apple SDK 12.16.0 bootstrap, Auth, and profile repository code;
  the post-integration Debug build and build-for-testing pass.
- Enabled Firebase Authentication and the Apple provider, recorded Apple Team
  ID `284W99L8L3`, and verified that an invalid Apple token reaches the provider
  instead of returning `OPERATION_NOT_ALLOWED`.
- Verified a generic-device Debug build with automatic provisioning; the signed
  app contains the Sign in with Apple and App Group entitlements.
- Revalidated Functions build/lint, 10 unit tests, 18 Rules tests, 7 Firestore
  integration tests, and a zero-high-severity production dependency audit.
- Deferred TTL policies requiring billing plus Google Auth, App Check, Storage,
  Functions, and FCM live configuration.
- Recorded the Xcode 27 beta simulator failure: test workers do not materialize
  and application installation hangs on both existing and fresh devices.
- Added the Swift AI foundation, privacy widget, App Intents, and Shortcuts
  foundation.

### 2026-07-26 — Foundation start

- Recorded Phase 0 repository and toolchain evidence.
- Established product, architecture, security, Firebase, localization, testing,
  manual-action, decision, and progress documentation.
- Generated and built the iPhone project with environment configurations,
  localization, a design system, local feature shells, and unit/UI test targets.
- Built and linted the initial Firebase Functions scaffold; 4 unit tests and 13
  Firestore/Storage emulator tests passed.
- Full Swift test execution, iOS 26 compatibility, real Firebase/provider
  integration, Apple capabilities, lifecycle completion, and App Store
  readiness remain unclaimed.
