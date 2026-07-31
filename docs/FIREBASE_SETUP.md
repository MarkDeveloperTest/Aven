# Firebase Setup

## Current status

The live development Firebase project `aven-ios-dev-4f7c2` exists and its iOS
app is registered for `com.example.aven.dev`. The project alias is committed in
`firebase/.firebaserc`; the downloaded `GoogleService-Info.plist` is
machine-local and ignored by Git. Staging and production projects do not exist.

The development project's default Firestore database is live in
`europe-west2`, and the reviewed Firestore Rules plus all five composite indexes
are deployed. Anonymous live document access is denied. The project is on the
Blaze plan. The three checked-in TTL policies and Storage bucket remain
undeployed. The pairing Functions `createInvitation`, `redeemInvitation`, and
`revokeInvitation` are live in `europe-west2`, with the invitation-signing
secret held in Secret Manager.

Onboarding now requires authentication and prepares the entered profile before
showing pairing actions. Its Continue action stays unavailable until Firebase
observes an active relationship, and persisted progress cannot jump from an
unpaired state to the finish screen.

The backend scaffold includes Firestore Rules, Storage Rules, indexes, Node 22
TypeScript Functions, and emulator tests. TypeScript build/lint, 11 unit tests,
18 Firestore/Storage Rules tests, and 7 Firestore integration tests pass
locally. A production-dependency `npm audit --omit=dev --audit-level=high`
also passes after bounded transitive security overrides.

Firebase Apple SDK 12.16.0 bootstrap, Google Sign-In 9.0.0, authentication, and
profile repository adapters are implemented in the iOS source. The
post-integration Debug build and build-for-testing pass. Firebase
Authentication and its Apple provider are enabled in development, the Firebase
app has Apple Team ID `284W99L8L3`, and an invalid-token probe confirms Apple
requests reach the enabled provider. The app's demo authentication path has
been removed. Google provider/OAuth creation and a refreshed local Firebase
plist remain pending. A completed user login has not been verified because the
available Xcode 27 beta simulator service hangs during application
installation. A signed Debug build was installed and launched on the connected
physical iPhone after the pairing deployment, but a two-account pairing run has
not yet been completed. App Check is registered for the iOS app with App Attest, while
Storage, FCM, and provider-backed AI are not configured. The three pairing
callables require Firebase Authentication but intentionally do not enforce App
Check, so development installs do not depend on per-device debug-token setup.

## Environment strategy

Provision three isolated Firebase/Google Cloud projects:

| Build configuration | Environment | Firebase project |
| --- | --- | --- |
| `Debug` | Development | `aven-ios-dev-4f7c2` |
| `Staging` | Staging | To be created |
| `Release` | Production | To be created |

Each environment requires its own bundle identifier, Firebase iOS app, URL
schemes, `GoogleService-Info.plist`, App Check setup, and backend configuration.
Do not route development builds to production data.

The temporary bundle namespace is `com.example.aven`. The development
registration is disposable; replace the namespace before staging, production,
or Apple resources are treated as durable. Record final identifiers in
[MANUAL_ACTIONS.md](MANUAL_ACTIONS.md) and the decision log.

## Prerequisites

- An Apple Developer team with permission to create identifiers/capabilities
- Firebase/Google Cloud projects with least-privilege operator access
- Firebase CLI and a supported Node.js version for Functions/emulators
- Xcode project packages resolved through Swift Package Manager
- APNs authentication material for Firebase Cloud Messaging when push is tested

Do not download or create production credentials until the environment,
ownership, billing, region, and bundle identifiers have been reviewed.

## Console setup per environment

1. Create the Firebase project under the correct organization and billing
   policy.
2. Decide Firestore and Functions regions together. Development uses
   `europe-west2` as recorded in D-012. Production must still evaluate
   UK/Ukraine latency, UK/EU data residency, US launch users, availability,
   backups, cost, and operational simplicity before resources are created.
3. Register the iOS app with that environment's exact bundle identifier.
4. Download `GoogleService-Info.plist` locally. Keep the real file untracked and
   never paste its contents into documentation, issues, or logs.
5. Enable Authentication providers:
   - Sign in with Apple, including Services ID/key setup where required
   - Google Sign-In, including the correct reversed client URL scheme
6. Create Firestore in the chosen region and deploy reviewed Rules and
   composite indexes. Review billing before deploying TTL policies.
7. Create the default Storage bucket and deploy reviewed Storage Rules.
8. Enable Functions, Cloud Messaging, Remote Config, Crashlytics, Analytics,
   Performance, and App Check only as their app integrations are ready.
9. Configure App Check:
   - debug provider/token for local development
   - documented non-production policy for staging
   - App Attest for production
10. Add APNs authentication to Cloud Messaging and test generic/private
    notification modes.
11. Configure retention, budgets, alerts, IAM, audit logging, and Secret Manager.

## Apple SDK packages

The Xcode project currently pins Firebase Apple SDK `12.16.0` through Swift
Package Manager and links:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseStorage`
- `FirebaseFunctions`
- `FirebaseRemoteConfig`
- `FirebaseAppCheck`
- `FirebaseMessaging`
- `FirebaseAnalytics`
- `GoogleSignIn` `9.0.0`

The source includes fail-closed bootstrap validation against the expected
project and bundle IDs, Firebase Auth adapters for Apple and Google
credentials, Google callback URL handling, and a Firestore profile adapter.
The demo authentication repository and UI have been removed. Google Auth
console enablement and its generated client configuration remain pending, and
no Firebase Auth provider has completed a live sign-in test. Crashlytics,
Performance, and Firebase AI Logic should be added only when their product
slices and SDK APIs are verified. The app must not invent SDK methods or embed
cloud provider keys.

Package resolution and source integration do not prove that a Firebase feature
works. The post-integration build passes, but a live development
sign-in/profile test is still required.

## Local configuration placement

Development currently uses the ignored local file at
`Aven/Resources/GoogleService-Info.plist`. Its project ID and bundle ID match
`aven-ios-dev-4f7c2` and `com.example.aven.dev`. Staging and production have no
configuration files or project IDs, and their build configurations exclude the
development plist.

After enabling Google Authentication and downloading the refreshed Firebase
plist, generate the ignored Google URL/client settings with:

```sh
./scripts/configure-google-signin.sh
```

Requirements:

- real plists remain outside Git
- example/template configuration contains no credential values
- startup fails safely with a clear development diagnostic when configuration
  is absent
- previews and tests do not require production credentials
- Release cannot silently use development configuration
- logs never print plist contents, tokens, secrets, or raw user data

The bootstrap checks that the selected plist's bundle ID and project ID match
the compile-time build environment before configuring Firebase. The build
passes; a runtime test is still required.

## Firebase CLI and emulators

From the repository root, after the Firebase CLI structure exists:

```sh
firebase login
firebase use --add
firebase emulators:start
```

The current Rules suite can be run from `firebase/functions` with:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  npm run test:rules
```

Firebase Tools requires Java 21 or newer for this suite.

Use explicit project aliases such as `development`, `staging`, and `production`.
Never make `production` the implicit target for routine local commands.

The committed `development` alias points to `aven-ios-dev-4f7c2`. The default
Firestore database, Rules, five composite indexes, and the three pairing
Functions are live there. Storage Rules, three TTL policies, and all
staging/production deployments remain pending.

Functions should use TypeScript strict mode, runtime schema validation, typed
errors, structured redacted logging, idempotency, retry-aware handlers, and
Secret Manager. Emulator tests should cover at minimum:

- valid member access and non-member denial
- cross-user private-data denial
- forged sender and role escalation
- invitation expiry, revocation, replay, and concurrent redemption
- archived relationship access
- AI-memory visibility and AI proxy authorization
- location-sharing precision/expiry boundaries
- upload path, ownership, type, and size
- export, deletion, archive, and emergency unlink

## Rules and trusted operations

Clients may directly perform only narrowly validated operations. Functions must
mediate invitation redemption, atomic relationship creation, privilege or
lifecycle transitions, notification fan-out, cloud AI, exports, deletion,
shared-content resolution, counters, and rate-sensitive actions.

Rules derive identity from Firebase Auth and trusted stored membership. Do not
trust client-supplied user IDs, roles, timestamps, ownership, or membership in
the same write being authorized.

## App Check rollout

Start with observability before enforcement, then:

1. verify legitimate development and staging traffic
2. configure and protect debug tokens as credentials
3. enable App Attest for production
4. enforce App Check on sensitive Functions after verified clients are ready;
   pairing currently remains authentication-only to avoid blocking users
5. enforce supported Firebase services after monitoring rejects
6. document recovery and key/team changes

App Check complements authentication and authorization; it does not replace
either.

## Cloud AI secrets

OpenAI or other provider keys belong in Google Cloud Secret Manager and are
read only by the least-privileged server function. Cloud AI endpoints must
verify Firebase Authentication, App Check, relationship membership, category
consent, input schema, and rate limit. Do not log raw prompts by default.

`secureAIProxy` is not deployed in development. Its Firebase secret and
environment placeholders exist only because the shared Functions codebase
requires declarations to be present while pairing Functions are deployed; do
not deploy that endpoint until they are replaced with a real approved provider
configuration.

## Remote Config safe defaults

Ship local defaults for age gating, disabled experiments, AI availability,
upload/rate limits, insight cadence, maintenance state, and regional flags.
Remote Config must not grant data access, bypass review requirements, silently
enable precise sharing, or make an unavailable provider mandatory.

## Verification checklist

- [x] Development project selected as `aven-ios-dev-4f7c2`
- [x] Development configuration file is machine-local and untracked
- [x] Default development Firestore database created in `europe-west2`
- [x] Reviewed Firestore Rules deployed to development
- [x] Firebase Authentication and Apple provider enabled in development
- [x] Signed Debug device build carries the Apple sign-in entitlement
- [ ] Staging and production projects/configuration created
- [x] Post-Firebase-SDK iOS build and build-for-testing verified
- [x] Current signed Debug build installed and launched on physical iPhone
- [ ] Simulator launch verified on a functioning runtime
- [ ] Authentication providers complete a local test
- [x] Firestore/Storage Rules behavior verified locally with 18 tests
- [x] Functions build/lint and 11 unit tests pass locally
- [x] Firestore integration suite passes locally with 7 tests
- [x] Production dependency audit reports zero high-severity vulnerabilities
- [x] Five reviewed composite indexes deployed
- [ ] Three TTL policies deployed after explicit billing approval
- [ ] Storage created and Storage Rules deployed
- [x] Pairing Functions deployed in `europe-west2`
- [x] Pairing call reaches the Firebase Authentication guard without App Check
- [x] Onboarding pairing gate blocks forward navigation while unpaired
- [ ] Pairing Functions exercised end to end with two authenticated users
- [ ] App Check valid and invalid requests tested
- [ ] APNs/FCM foreground, background, and privacy modes tested
- [ ] Crash/analytics events contain no private payloads
- [ ] Cloud secrets are server-only and logs are redacted
- [ ] Export, deletion, archive, and unlink cleanup tested
- [ ] Production region, budgets, alerts, retention, IAM, and backups reviewed

Until the remaining checks have evidence, Firebase integration remains
development-only and incomplete.
