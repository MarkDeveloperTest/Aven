# Testing

## Current evidence

On 2026-07-27 the Firebase Apple SDK and Google Sign-In 9.0.0-enabled Debug app
build and build-for-testing passed with Xcode 27.0 beta (`27A5209h`) for an
arm64 generic iOS simulator destination. Swift reports 6.4. The Swift unit and
UI bundles compile, but no completed passing test execution is claimed.

The Firebase Functions TypeScript build, ESLint, test typecheck, 10 unit tests,
18 Firestore/Storage emulator Rules tests, and 7 Firestore integration tests
pass locally. The emulator suites used Java 21. The production dependency audit
reports zero vulnerabilities.

The unit runner was bounded after 130 seconds. Xcode reported that it was
waiting for workers to materialize while initiating the test-runner session;
no test executable launched. Both the existing simulator and a fresh disposable
iOS 27 simulator then hung on application installation. These are runtime
tooling failures, not passing test results.

The premium onboarding redesign was revalidated on 2026-07-27 from a temporary
source copy because Xcode file coordination stalled while opening the project
in its original workspace path. The Debug app, Swift unit-test bundle, and UI
test bundle all compiled with `build-for-testing`. A booted iPhone 17 Pro again
stalled on `simctl install`; a bounded onboarding unit-test run reached
“Testing started” but remained at “waiting for workers to materialize” and was
interrupted after 62.5 seconds. No runtime, test-pass, or visual-fidelity claim
is made.

The subsequent all-ages, region-language, fixed-layout revision was also
validated with Xcode 27 beta using `build-for-testing`. The app, updated unit
tests, and updated UI tests compile. Static checks confirm that authentication
and onboarding contain no page-level `ScrollView`. Native wheel date pickers
were restored in the following design revision. The String Catalog parses
successfully. Runtime execution remains subject to the same simulator-service
blocker above.

No iOS 26 simulator runtime is installed, so the iOS 26 deployment requirement
has not been runtime-tested.

The intended project contract is:

- `Aven.xcodeproj`
- scheme `Aven`
- configurations `Debug`, `Staging`, and `Release`
- current destination `iPhone 17 Pro`, iOS 27.0

## Toolchain selection

The active developer directory currently points at Command Line Tools. Use the
beta Xcode explicitly:

```sh
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

Verified build command:

```sh
xcodebuild \
  -project Aven.xcodeproj \
  -scheme Aven \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  build
```

The following is the intended full test command. Its bundles compile, but a
completed passing result still requires a functioning simulator test service:

```sh
xcodebuild \
  -project Aven.xcodeproj \
  -scheme Aven \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  test
```

Record the exact command, exit status, failures, and warnings in
[PROGRESS.md](PROGRESS.md) after each validation run.

## Test layers

### Unit and domain tests

Use Swift Testing for new deterministic tests:

- value objects and validation
- age gate and regional minimum defaults
- date, duration, locale, and time-zone behavior
- invitation parsing and expiry
- relationship and message state transitions
- ownership, visibility, privacy, and unlink policy
- AI provider routing and memory visibility
- error translation and recovery eligibility
- theme and brand configuration

Use `#require` for values needed by later assertions and `#expect` for
independent expectations. Inject clocks, IDs, repositories, and services. Do
not sleep to wait for async behavior.

### Feature-state tests

Test observable models/use cases for authentication, onboarding, pairing, home,
messaging, media upload, Shared Day, insights, AI, settings, archive, export,
and deletion. Cover loading, success, empty, offline, cancellation, retry, and
permission-revoked states.

### Repository and integration tests

Use protocol fakes for fast contracts and Firebase emulators for real
serialization/listener behavior. Verify pagination boundaries, optimistic
state reconciliation, duplicate/idempotent writes, cache tombstones, retry,
and listener cancellation.

### Firebase Emulator tests

Rules, Storage, and Functions tests must cover:

- member access and non-member denial
- cross-user private data
- forged sender, owner, timestamp, and role
- invitation enumeration, expiry, replay, revocation, and redemption races
- archive/unlink/deletion authorization
- AI-memory visibility and cloud AI authorization
- location precision, expiry, and revocation
- upload path, ownership, content type, and size
- orphan cleanup, exports, and account deletion

Never substitute permissive emulator Rules for production-like authorization
tests.

### UI and accessibility tests

Keep XCUITest/XCTest for end-to-end UI automation:

- first launch and sign-in presentation
- resume-safe onboarding and age gate
- pairing code/deep-link flow
- send/retry/read message
- upload a memory
- create/remove a Shared Day event
- change and revoke a privacy setting
- archive and emergency unlink
- Face ID protected-state fallback where testable
- English/Ukrainian flows, VoiceOver identifiers, and accessibility text sizes

Stable accessibility identifiers belong on interactive controls and critical
state, not every view. Avoid snapshot tests unless the output and toolchain are
demonstrably stable and useful.

## Compatibility matrix

| Dimension | Required evidence |
| --- | --- |
| iOS 26 | Build, launch, primary flows, availability fallbacks |
| iOS 27 | Build, launch, primary flows, iOS 27 feature path |
| English | Core flows, validation, system surfaces |
| Ukrainian | Core flows, grammar-sensitive cases, system surfaces |
| Appearance | Light, dark, high contrast |
| Accessibility | Dynamic Type, VoiceOver, Reduce Motion/Transparency |
| Connectivity | Online, offline cache, reconnect, failed upload |
| Backend | Fakes, emulator, configured development project |
| Privacy | Revocation, generic notifications, locked/redacted surfaces |

Only iOS 27 simulator tooling is currently available for the new target. Add an
iOS 26 runtime or use a compatible CI/device before declaring compatibility.

## Determinism and isolation

- Tests own their state and may run in parallel.
- Shared emulator resources use unique namespaces and explicit cleanup.
- Serialize only tests that truly share external state.
- Time, randomness, UUIDs, locale, time zone, network, and model output are
  controlled inputs.
- AI tests use typed fixtures/fakes; production model output is not a stable
  assertion target.
- UI tests use fictional adults and generated non-sensitive assets.
- Live production Firebase is not a routine test dependency.

## Phase acceptance gates

After each major phase:

1. build the app
2. run relevant unit, feature, integration, and UI tests
3. fix compiler and test failures
4. review and resolve avoidable warnings
5. verify both success and failure/revocation paths
6. update progress and setup documentation
7. list unresolved external actions and limitations

No phase is complete because files exist or a package resolves. The relevant
behavior and security boundary must have test evidence.
