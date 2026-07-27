# Manual Actions

## Purpose

These actions require developer-account, console, legal, credential, or
toolchain access that cannot be completed safely from source code alone. Do not
place credentials or secret values in this file.

## Immediate development actions

| Status | Owner | Action | Verification |
| --- | --- | --- | --- |
| Open | Developer | Select `/Applications/Xcode-beta.app` in Xcode Settings or use `DEVELOPER_DIR` for commands. | `xcodebuild -version` reports Xcode 27.0 from the beta app. |
| Open | Developer | Install an iOS 26 simulator runtime or provide a compatible iOS 26 device/CI runner. | App builds, launches, and passes the compatibility matrix on iOS 26. |
| Open | Product/Engineering | Confirm final product name, legal name, production bundle namespace, support address, and URLs. | Values are approved and centralized in brand/environment configuration. |
| In progress | Apple team admin | The development App ID now provisions and signs with Apple Team `284W99L8L3`; create durable staging and production App IDs after final identifiers are approved. | Debug signs with the intended development identifier; Staging and Release remain open. |
| Open | Backend owner | Choose the production Firestore/Functions region after legal, latency, availability, and operations review. | Decision recorded before production resources contain user data. |
| Open | Backend owner | Decide whether and where to enable billing before deploying the three checked-in TTL policies or billing-dependent services. | Billing, budgets, alerts, scope, and the exact target project are explicitly approved before deployment. |

The current environment has Xcode 27 beta and can exercise iOS 27. It has no
iOS 26 runtime, so iOS 26 remains a required external validation action.

## Firebase environments

Current development status:

- `aven-ios-dev-4f7c2` exists on the free Spark plan.
- `com.example.aven.dev` is registered.
- the local `Aven/Resources/GoogleService-Info.plist` is present and ignored
  by Git
- the default Firestore database exists in `europe-west2`
- reviewed Firestore Rules and five composite indexes are deployed
- Firebase Authentication and the Apple provider are enabled
- Firebase and the signed development app use Apple Team ID `284W99L8L3`
- staging and production do not exist
- Google Auth, App Check, Storage, Functions, FCM, and the three TTL policies
  are not configured or deployed live

Complete the following for staging and production, and for any still-missing
development service:

1. Create or assign the Firebase/Google Cloud project.
2. Register the exact environment bundle identifier.
3. Download the environment `GoogleService-Info.plist` locally.
4. Place it at the project-defined local configuration path without committing
   it.
5. Configure IAM, billing/budgets, audit logs, retention, and alerts.
6. Enable only services used by the current implementation.
7. Configure App Check debug/staging/production policies.
8. Deploy reviewed Firestore/Storage Rules, indexes, and Functions.
9. Map Firebase CLI aliases without making production the routine default.
10. Verify the build cannot cross-connect to another environment.

The development plist must remain local and untracked. Follow
[FIREBASE_SETUP.md](FIREBASE_SETUP.md); do not create staging/production by
copying the development plist, enable billing implicitly, commit any real
configuration file, or weaken Rules.

## Authentication

### Sign in with Apple

- Firebase Apple Authentication is enabled in `aven-ios-dev-4f7c2`.
- The development app builds with an automatically provisioned profile carrying
  the Sign in with Apple entitlement.
- Configure any Services ID/key only if a web or Android OAuth code flow needs
  it; the native Apple flow does not require those optional fields.
- Store Apple private key material only in the appropriate secure console.
- Verify nonce handling, first login, returning login, credential revocation,
  provider linking, sign-out, reauthentication, and deletion.

### Google Sign-In

- Enable the Firebase Google provider; it is not currently live and the iOS
  repository intentionally fails closed.
- Register the correct bundle ID and URL scheme per environment.
- Add the generated reversed client ID without exposing unrelated credentials.
- Verify first login, returning login, provider collision/linking, sign-out,
  and deletion.

## Push notifications

- Create or select the APNs authentication key in the Apple Developer portal.
- Upload it to the correct Firebase project.
- Enable Push Notifications and required background modes for each App ID.
- Verify foreground, background, terminated, token refresh, quiet hours, and
  generic/private previews in both languages.
- Never paste APNs keys or tokens into Git, logs, or documentation.

## Apple capabilities

Create and record environment-specific identifiers only when their feature
slice is ready:

- Associated Domains and the hosted `apple-app-site-association` file
- App Group for widget/shared container data
- Live Activities/ActivityKit capability
- Sign in with Apple
- Push Notifications
- SharePlay/GroupActivities entitlements
- alternate app icons where used

EventKit, Photos, location, microphone, speech, Face ID, and notifications also
need accurate localized purpose/explanation text and real-device review.

## App Check

- App Check is not currently configured in the live development project.
- Enable App Attest for production App IDs.
- Generate and protect development debug tokens.
- Define staging enforcement separately.
- Observe valid traffic before enforcement, then test invalid/replayed requests.
- Verify sensitive Functions require Auth, App Check, schema validation,
  relationship membership, consent, and rate limits.

## AI providers

- Approve provider, model, supported regions/languages, retention, data-use
  terms, rate limits, and budget.
- Put cloud provider keys in Google Cloud Secret Manager.
- Grant only the server function access; never add a key to the app, plist,
  Remote Config, Firestore, or Git.
- Configure safe model defaults server-side and test provider outage/fallback.
- Complete privacy/legal review for every context category that may leave the
  device.

## Legal and privacy

Product/legal owners must supply and approve:

- privacy policy and terms for each launch region
- legal product/entity name and support contact
- age policy and remotely configurable regional minimum
- retention, export, deletion, archive, and shared-content resolution policy
- AI disclosure, provider processing, and user consent language
- location, calendar, photo, microphone, notifications, and analytics language
- App Store privacy answers and required-reason API declarations

Placeholders are not App Store-ready legal text.

## App Store and release

- Create App Store Connect app records with final bundle identifiers.
- Complete signing, capabilities, privacy manifest, required-reason APIs,
  export compliance, age rating, and privacy nutrition labels.
- Provide localized metadata, screenshots, support/privacy URLs, review notes,
  and a test-account strategy compatible with partner linking.
- Exercise account deletion and data export end to end.
- Validate English and Ukrainian on supported devices and accessibility sizes.
- Test release builds against staging, then production, with App Check enforced.
- Review crash-free, performance, backend budget, and security test evidence.

Do not claim submission readiness while any required credential, entitlement,
legal text, backend validation, iOS 26 test, or production privacy control is
unfinished.
