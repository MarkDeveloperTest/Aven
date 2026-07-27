# Aven for iOS

Aven is an in-development, privacy-conscious relationship app for two people
who already know each other. The product vision includes private messaging,
shared memories, a deliberately shared day timeline, relationship lifecycle
management, and permission-aware AI assistance.

> [!IMPORTANT]
> This repository contains a Firebase-enabled iOS product shell that builds and
> builds-for-testing, plus a locally validated Firebase backend/security
> scaffold. A live development Firebase project, Firestore Rules, and composite
> indexes now exist, but shared product features still primarily use
> development data and no live authentication flow has been verified. This is
> not a completed MVP, production deployment, or App Store-ready application. See
> [docs/PROGRESS.md](docs/PROGRESS.md) for verified status.

## Product constraints

- iPhone only, Swift and SwiftUI
- Minimum deployment target: iOS 26
- English and Ukrainian at launch
- Initial markets: United Kingdom, Ukraine, and United States
- One active relationship per user; archived relationship history is allowed
- Shared features must be mutual, transparent, and reversible
- AI output is advisory, editable, and never sent automatically
- No public discovery, matching, or stranger-facing social graph
- No claim of end-to-end encryption until an audited E2EE design exists

## Current development environment

The current environment and local foundation were verified on 2026-07-27:

- `/Applications/Xcode-beta.app` is Xcode 27.0 beta, build `27A5209h`.
- The bundled iOS SDK is 27.0.
- An iOS 27.0 simulator runtime is available; no iOS 26 runtime is installed.
- Swift reports version 6.4.
- The active `xcode-select` path points to Command Line Tools, not Xcode.
- The development Firebase project is `aven-ios-dev-4f7c2`; its
  `com.example.aven.dev` iOS app is registered and its machine-local,
  Git-ignored `GoogleService-Info.plist` is present.
- Firebase Authentication and the Apple provider are enabled for development.
  Firebase records Apple Team ID `284W99L8L3`, and an invalid-token probe
  reaches the provider rather than failing as disabled.
- The Firebase Apple SDK 12.16.0-enabled Debug app build and
  build-for-testing pass for an iPhone 17 Pro iOS 27 simulator.
- An automatically provisioned generic-device Debug build also passes with the
  Sign in with Apple and App Group entitlements in its signed app.
- Xcode 27 beta's simulator application service currently hangs before
  installing the app or materializing a test runner, so launch and completed
  Swift test execution are not claimed.
- Firebase Functions build/lint, 10 unit tests, 18 Firestore/Storage Rules
  tests, and 7 Firestore integration tests pass locally. The production
  dependency audit reports no high-severity vulnerabilities.

The iOS 26 minimum target is a product requirement, but compatibility has not
yet been tested on an iOS 26 runtime. Testing only on iOS 27 is not sufficient
to close that requirement.

## Local build

Until the active developer directory is changed, prefix Apple tool commands
with:

```sh
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

The project contract is:

- Project: `Aven.xcodeproj`
- Scheme: `Aven`
- Configurations: `Debug`, `Staging`, `Release`
- Current simulator destination: `iPhone 17 Pro`, iOS 27.0

Verified build command:

```sh
xcodebuild \
  -project Aven.xcodeproj \
  -scheme Aven \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  build
```

This command passes with Xcode 27 beta after the Firebase Apple SDK and Google
Sign-In integration. A generic-device Debug build with automatic provisioning
also passes. These results do not verify launch behavior, a completed provider
login, iOS 26 runtime compatibility, staging, or release configuration.

## What works locally

- environment-aware iPhone app shell and reusable SwiftUI design components
- English/Ukrainian String Catalog with automatic region-based language
- configured development Apple Authentication provider, correctly signed Apple
  capability, nonce/UI foundation, and a real Google-to-Firebase credential flow
- no demo authentication path; unavailable providers fail closed
- persisted onboarding that accepts any date of birth
- local unpaired/pairing, messaging, memory, Shared Day, insight, privacy, and
  settings surfaces
- a consent-aware Swift AI routing/context foundation with fail-closed
  unavailable providers
- a privacy-minimizing WidgetKit extension and App Intents/Shortcuts foundation
- Firebase Apple SDK 12.16.0 bootstrap, Google Sign-In 9.0.0, Auth and profile
  repository adapters in source; a provider-backed login still needs a real
  device or a functioning signed-in simulator for end-to-end verification
- strict Firestore/Storage Rules and guarded invitation/AI callable foundations
- unit and UI test targets that build with the Firebase SDK integration

The local stores are intentional development seams. They do not represent
cross-device synchronization, production authentication, export/deletion, or
deployed feature behavior.

## Firebase

Aven is designed for separate development, staging, and production Firebase
projects. Development uses the live `aven-ios-dev-4f7c2` project and a
machine-local, Git-ignored configuration plist. Its default Firestore database
is in `europe-west2`, and reviewed Firestore Rules are deployed. Staging and
production projects do not exist.

No real `GoogleService-Info.plist`, service-account file, signing material, or
provider API key belongs in Git. Firebase Authentication and Apple sign-in are
configured in development; Google sign-in, App Check, Storage, Functions, and
FCM are not configured live. The development project remains on the free Spark
plan; all five checked-in composite indexes are deployed. The three TTL field
policies remain undeployed because they require an explicit billing decision.

Follow [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) before enabling
additional live services. Remaining console and developer-account work is
tracked in
[docs/MANUAL_ACTIONS.md](docs/MANUAL_ACTIONS.md).

Local backend validation from `firebase/functions`:

```sh
npm run build
npm run lint
npm test
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  npm run test:rules
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  npm run test:emulator
```

The Rules suite requires Java 21 or newer. The Firestore Rules deployment is
live in development; passing local tests does not mean Storage, Functions, or
any other backend service has been deployed.

## Documentation

- [Product specification](docs/PRODUCT_SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Technical decisions](docs/DECISIONS.md)
- [Security model](docs/SECURITY_MODEL.md)
- [Privacy model](docs/PRIVACY_MODEL.md)
- [Firebase setup](docs/FIREBASE_SETUP.md)
- [Firebase schema](docs/FIREBASE_SCHEMA.md)
- [AI architecture](docs/AI_ARCHITECTURE.md)
- [Localization](docs/LOCALIZATION.md)
- [Testing](docs/TESTING.md)
- [Delivery roadmap](docs/ROADMAP.md)
- [App Store checklist](docs/APP_STORE_CHECKLIST.md)
- [Manual actions](docs/MANUAL_ACTIONS.md)
- [Progress and verified status](docs/PROGRESS.md)

Documentation describes the target design unless a status section explicitly
says that behavior has been built and verified.
