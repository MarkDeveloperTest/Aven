# App Store Readiness Checklist

## Readiness report

**Current status: not ready for submission.**

The repository has a compiling iPhone app foundation, English/Ukrainian String
Catalogs, a privacy manifest, localized permission-copy resources, local
Firebase Rules/Functions foundations, and tests. It does not have final
identity/legal values, production signing, a real app icon, live Firebase
configuration, complete authentication/capabilities, end-to-end lifecycle
features, iOS 26 runtime evidence, or a passing full UI suite.

An `[x]` below means the source artifact or local validation exists. It does not
mean App Review has approved it.

## Product and binary

- [x] iPhone-only target
- [x] Swift 6 / SwiftUI project with an iOS 26 deployment target
- [x] Debug build succeeds on an iPhone 17 Pro iOS 27 simulator
- [x] Development, staging, and production build configurations exist
- [ ] iOS 26 simulator/device build and runtime matrix passes
- [ ] Staging and Release archive/install validation passes
- [ ] Final product name and legal entity are approved
- [ ] Temporary `com.example.aven` bundle identifiers are replaced
- [ ] Marketing version/build numbering and release branch policy are approved
- [ ] Final 1024 x 1024 app icon and all appearance variants are supplied
- [ ] Launch experience and all required production assets are reviewed

## Apple developer configuration

- [ ] Apple Developer team selected in local/CI signing
- [ ] Development, staging, and production App IDs created
- [ ] Sign in with Apple capability configured
- [ ] Push Notifications and APNs key configured
- [ ] Associated Domains and Universal Links configured
- [ ] App Group configured for widget/shared data, if shipped
- [ ] Live Activities capability configured, if shipped
- [ ] SharePlay/GroupActivities capability configured, if shipped
- [ ] Entitlements match actual features and least privilege
- [ ] Distribution certificate/profile or managed signing verified in CI

## Authentication and account management

- [x] Sign in with Apple UI and secure nonce foundation exist
- [x] Authentication repository boundary and fail-closed development adapter
      exist
- [ ] Sign in with Apple completes first/returning/revoked-credential flows
- [ ] Google Sign-In is integrated and provider-linking conflicts are handled
- [ ] Sign-out clears listeners, caches, and private UI state
- [ ] In-app account deletion works end to end after reauthentication
- [ ] Data export works end to end
- [ ] Partner unlink/archive/emergency-unlink cleanup is verified
- [ ] App Review test-account/partner-link strategy is documented and usable

## Firebase and backend

- [x] Firestore Rules, Storage Rules, indexes, and Functions scaffold exist
- [x] TypeScript build, lint, unit tests, and local Rules tests pass
- [ ] Separate development, staging, and production projects are provisioned
- [ ] Correct untracked `GoogleService-Info.plist` is selected per build
- [ ] Firebase Apple SDK products are integrated into the iOS app
- [ ] Reviewed Rules, indexes, Functions, and TTL policies are deployed
- [ ] App Check valid, invalid, and replay behavior is verified
- [ ] Auth providers, FCM/APNs, Remote Config, Crashlytics, Analytics, and
      Performance are configured only where used
- [ ] IAM, budgets, alerts, audit logs, backups, and retention are approved
- [ ] Production region is approved
- [ ] Export, deletion, unlink, media cleanup, and notification fan-out jobs are
      implemented and observed

## Privacy and legal

- [x] Privacy manifest file exists and declares no tracking
- [x] English and Ukrainian permission-description catalogs exist
- [x] Security/privacy docs avoid unsupported E2EE and clinical claims
- [ ] Final binary's required-reason APIs are audited and declared accurately
- [ ] Privacy manifest data collection matches every shipped SDK and backend
- [ ] App Store privacy nutrition labels match observed production behavior
- [ ] Privacy policy and terms are legally approved for launch regions
- [ ] Support email, support URL, privacy URL, and terms URL are final
- [ ] Age rating and all-ages access policy are approved
- [ ] Data inventory, purpose, retention, export, and deletion schedule are
      approved
- [ ] Cloud AI provider, retention, region, and consent language are approved
- [ ] Location, calendar, photo, microphone, notifications, analytics, and AI
      consent are purpose-specific and reversible
- [ ] No private content or credentials appear in logs, analytics, crash data,
      notifications, screenshots, or review notes

## Permission copy

- [x] English and Ukrainian Photo Library explanation resources exist
- [x] English and Ukrainian calendar explanation resources exist
- [x] English and Ukrainian location explanation resources exist
- [x] English and Ukrainian microphone explanation resources exist
- [x] English and Ukrainian speech-recognition explanation resources exist
- [ ] Every purpose string is reviewed against the final feature behavior
- [ ] Permissions are requested only at the moment of explained use
- [ ] Denied/restricted/limited states and OS Settings recovery are tested
- [ ] Background/precise location copy and persistent sharing indicator are
      tested if location ships
- [ ] Notification explanation and preview controls are tested

## Localization

- [x] English and Ukrainian String Catalogs are source-controlled
- [x] In-app language choice is represented independently from system language
- [ ] Automated catalog completeness/format validation passes
- [ ] All user-facing errors, notifications, widgets, Siri phrases, and privacy
      text are localized
- [ ] Native linguistic review is complete in both languages
- [ ] Dynamic Type and long-copy layouts pass on compact iPhones
- [ ] Locale-specific dates, time zones, numbers, plurals, and accessibility
      labels are reviewed
- [ ] App Store metadata and screenshots are localized

## Quality, accessibility, and security

- [x] Debug build and build-for-testing succeed on iOS 27 simulator
- [x] Firebase unit and Rules suites pass locally
- [ ] Swift unit tests complete successfully
- [ ] Full UI suite completes successfully
- [ ] VoiceOver, Dynamic Type, Reduce Motion, contrast, keyboard, and touch
      target review passes
- [ ] Offline, reconnect, retry, conflict, cancellation, and data-deletion
      scenarios pass
- [ ] Release configuration receives a clean compiler/analyzer result
- [ ] Security review covers auth, membership, invitations, media, AI, exports,
      deletion, cache, logging, and notification content
- [ ] Performance, memory, energy, media upload, and cold-launch budgets pass
- [ ] Crash-free and backend health thresholds are defined for phased release

## AI

- [x] Guarded server proxy foundation keeps provider keys server-side
- [x] Current callable requires Auth, App Check, authorization, validation,
      rate limiting, and idempotency
- [ ] iOS provider protocols/router/context builder are implemented
- [ ] On-device Apple capability/language fallback is verified
- [ ] Cloud provider/model/secret is configured and legally approved
- [ ] Structured outputs and failure/refusal UX are tested
- [ ] Outputs are visibly generated, editable, dismissible, reportable, and
      never auto-sent
- [ ] Private/shared AI memory edit, consent, export, unlink, and delete work
- [ ] English and Ukrainian safety/quality evaluation passes
- [ ] Token/cost controls and provider-outage behavior are verified

## Store listing and review package

- [ ] App Store Connect records created for final identifiers
- [ ] Name, subtitle, description, keywords, promotional text, and categories
      approved
- [ ] Support, marketing, privacy, and terms URLs are live
- [ ] Required iPhone screenshots captured from a release-like build
- [ ] Screenshot set avoids real personal/relationship data
- [ ] App preview, if used, has rights-cleared media and localized captions
- [ ] Review notes explain partner pairing, demo/test account, permissions, AI,
      export, and deletion
- [ ] Export compliance, content rights, advertising identifier, encryption,
      age rating, and trader-status questions are answered accurately
- [ ] Third-party SDK privacy manifests/signatures and license notices are
      reviewed

## Beta distribution

- [ ] Staging backend and App Check policy are ready
- [ ] Internal TestFlight group validates install, migration, auth, pairing,
      unlinking, push, and deletion
- [ ] External beta consent/support/privacy process is approved
- [ ] Feedback and crash reports contain no private relationship content
- [ ] Rollback, feature-disable, incident, and backend migration runbooks exist
- [ ] Production release is phased with monitoring and a stop condition

## External blockers

The remaining developer-account, Firebase-console, legal, provider, and store
actions are tracked in [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md). This checklist
must be re-audited against the final signed archive; source files alone are not
submission evidence.
