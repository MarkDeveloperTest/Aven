# Aven Decision Log

## How to read this file

Decisions establish the intended engineering direction. They do not prove the
corresponding code is complete. Each entry records the reason, alternatives,
tradeoffs, and likely migration impact required for later review.

## D-001 — Native iPhone app with an iOS 26 floor

- **Status:** Accepted product constraint; iOS 26 runtime verification pending
- **Decision:** Use Swift, SwiftUI, Swift Package Manager, Swift concurrency,
  and an iOS 26 minimum deployment target. Gate iOS 27 APIs with availability
  checks behind protocols.
- **Reason:** The product needs deep Apple-platform integration while remaining
  useful on the required launch floor.
- **Alternatives considered:** iOS 27-only deployment; cross-platform UI.
- **Tradeoffs:** Availability paths and a fallback test matrix add work.
- **Future migration impact:** Raising the floor can remove fallbacks only
  after adoption, product, and App Store evidence supports the change.

## D-002 — Feature-oriented Clean Architecture

- **Status:** Accepted target architecture; implementation in progress
- **Decision:** Keep domain rules independent of Firebase and SwiftUI. Use a
  composition root, explicit dependency injection, protocol-backed repositories,
  focused observable UI models, and feature folders.
- **Reason:** Authentication, pairing, sharing, lifecycle, offline state, and AI
  have meaningful rules and need deterministic test seams.
- **Alternatives considered:** Direct Firebase calls from views; a global
  service locator; heavyweight reducer architecture across every screen.
- **Tradeoffs:** DTO mapping and protocols add code; trivial screens should not
  receive ceremonial layers.
- **Future migration impact:** Concrete providers and feature state models can
  change without rewriting domain rules or views.

## D-003 — Firebase is the shared source of truth

- **Status:** Accepted; backend credentials and live verification pending
- **Decision:** Use Firebase Authentication, Firestore, Storage, Functions,
  Cloud Messaging, App Check, Remote Config, Crashlytics, Analytics, and
  emulators where each service has a defined role. Use SwiftData selectively as
  a cache and offline-support layer.
- **Reason:** The product requires real-time two-user synchronization,
  server-mediated sensitive operations, media, notifications, and offline
  support.
- **Alternatives considered:** CloudKit; a custom backend; local-first
  peer-to-peer data as the canonical store.
- **Tradeoffs:** Vendor coupling, rules complexity, emulator work, and careful
  region selection are required.
- **Future migration impact:** Repository protocols and typed domain models
  contain provider coupling; migrations still require data and identity plans.

## D-004 — Separate development, staging, and production environments

- **Status:** Accepted; Firebase projects and identifiers not yet provisioned
- **Decision:** Use separate Firebase projects, bundle identifiers, URL schemes,
  build configurations, App Check setup, and configuration files for each
  environment.
- **Reason:** Test data and relaxed development controls must never affect
  production users.
- **Alternatives considered:** One Firebase project with logical environment
  fields; development and production only.
- **Tradeoffs:** More console setup and release configuration, with much safer
  isolation.
- **Future migration impact:** Environment-specific identifiers must be updated
  when the temporary brand and `com.example.aven` bundle namespace are replaced.

## D-005 — Server-mediated relationship and invitation mutations

- **Status:** Accepted; invitation Functions and local authorization tests implemented, lifecycle completion pending
- **Decision:** Invitations are expiring, revocable, one-time records.
  Redemption, relationship creation, role changes, sensitive lifecycle changes,
  exports, deletion, and rate-limited actions run atomically through trusted
  server code.
- **Reason:** Client-only checks cannot prevent replay, forged membership,
  privilege escalation, or race conditions.
- **Alternatives considered:** Direct client transactions; email-only pairing.
- **Tradeoffs:** Functions add latency and operations work.
- **Future migration impact:** Stable callable contracts and schema versions
  allow backend evolution without exposing privileged writes to clients.

## D-006 — Provider-independent, consent-aware AI

- **Status:** Accepted architecture; production providers not yet configured
- **Decision:** Prefer supported on-device Apple models for suitable work. Route
  cloud AI through an authenticated server proxy with App Check, authorization,
  rate limits, typed responses, redaction, and category-level consent.
- **Reason:** Capabilities, languages, availability, privacy, latency, and cost
  differ across providers.
- **Alternatives considered:** One cloud provider called directly by the app;
  on-device-only AI; no shared AI memory.
- **Tradeoffs:** Routing, fallbacks, structured output validation, and permission
 -aware context construction increase complexity.
- **Future migration impact:** Providers and model identifiers can change
  without changing product-facing use cases. Memory migrations remain
  visibility- and consent-sensitive.

## D-007 — English and Ukrainian String Catalog from the start

- **Status:** Accepted; catalog coverage and linguistic review remain ongoing
- **Decision:** Use stable namespaced String Catalog keys, explicit in-app
  language selection independent of the system, modern localized string types,
  and locale-aware `FormatStyle`.
- **Reason:** Localization changes layout, grammar, notifications, errors,
  privacy explanations, and AI behavior; retrofitting it is risky.
- **Alternatives considered:** English-first rollout; separate `.strings` files;
  using English copy as API-facing keys.
- **Tradeoffs:** Every feature requires two-language review and plural/format
  tests.
- **Future migration impact:** Stable keys and centralized brand configuration
  allow copy and product-name changes without widespread code churn.

## D-008 — Privacy is explicit, granular, and reversible

- **Status:** Accepted product and security invariant
- **Decision:** Keep precise location, calendar, media analysis, notifications,
  microphone, and AI data access off until purpose-specific consent. Preserve
  private-user boundaries and allow immediate sharing revocation.
- **Reason:** A relationship app has asymmetric-use and coercion risks even when
  both users are authenticated.
- **Alternatives considered:** Broad onboarding consent; partner-managed shared
  permissions; convenience-first continuous sharing.
- **Tradeoffs:** More settings and state transitions, with safer and more
  understandable behavior.
- **Future migration impact:** New data categories must enter the same consent,
  audit, export, deletion, and unlinking model before release.

## D-009 — No E2EE or clinical claims without proof

- **Status:** Accepted communication constraint
- **Decision:** Describe Firebase transport/storage protections accurately and
  do not market messaging as end-to-end encrypted. AI and insights remain
  non-clinical, non-predictive, and uncertainty-aware.
- **Reason:** Incorrect security or mental-health claims would mislead users and
  distort consent.
- **Alternatives considered:** Marketing-grade “secure/private” shorthand;
  numerical compatibility or health scores.
- **Tradeoffs:** Product language is deliberately narrower than some competing
  claims.
- **Future migration impact:** E2EE requires a separately reviewed protocol,
  key lifecycle, multi-device, recovery, moderation, export, and migration plan.

## D-010 — Modern unit tests; XCTest for UI boundaries

- **Status:** Accepted; test targets and suites are in progress
- **Decision:** Use Swift Testing for new unit and repository contract tests.
  Keep XCUITest/XCTest for UI automation and platform-specific boundaries.
  Use Firebase emulators for Rules, Storage, and Functions behavior.
- **Reason:** This gives fast deterministic domain tests plus realistic
  authorization and integration coverage.
- **Alternatives considered:** XCTest for every layer; live Firebase integration
  tests; snapshot-heavy UI testing.
- **Tradeoffs:** Multiple runners and emulator orchestration must be documented.
- **Future migration impact:** Frameworks may coexist; migrations proceed one
  deterministic suite at a time without changing behavior expectations.

## D-011 — Centralized, rename-safe brand configuration

- **Status:** Accepted; final legal and store values are unresolved
- **Decision:** Treat “Aven” and `com.example.aven` as temporary. Centralize
  display/legal names, URLs, support address, typography, accent, analytics
  namespace, environment, deep-link host, and invitation copy.
- **Reason:** A future rename should not require changes throughout domain logic,
  analytics, Firebase paths, strings, or assets.
- **Alternatives considered:** Literal names in each feature; postponing brand
  abstraction.
- **Tradeoffs:** A small configuration layer is required early.
- **Future migration impact:** Renaming still requires Apple/Firebase console
  updates, but code and localization changes remain localized.

## D-012 — London regional backend for development

- **Status:** Accepted for development; production requires a final legal and
  reliability review before resources are created
- **Decision:** Place the development Firestore database and callable Functions
  in `europe-west2` (London). Keep Storage in the same region when it is
  provisioned.
- **Reason:** London provides low latency for the initial UK audience,
  reasonable European routing for Ukraine, workable transatlantic latency for
  early US users, and exact co-location with the existing callable Functions.
  A regional database also reduces write latency, cost, and operational
  complexity for the development environment.
- **Alternatives considered:** `eur3` for multi-region durability and an EU
  data location; a US multi-region for the US audience; Warsaw for proximity
  to Ukraine.
- **Tradeoffs:** Regional Firestore has a lower published SLA than multi-region
  Firestore (99.99% rather than 99.999%), London is outside the EU, and US
  latency is higher. Production must review UK/EU transfer requirements,
  measured latency, availability objectives, cost, backups, and disaster
  recovery before copying this choice.
- **Future migration impact:** A Firestore database location cannot be changed
  after creation. Staging and production remain separate projects so they can
  choose a different location without moving development data.

## Open decisions

- Final product and legal name
- Production bundle identifier and environment suffixes
- Whether production should retain `europe-west2` or use `eur3` after legal,
  latency, availability, and cost review
- Support, privacy, terms, website, App Store, and deep-link URLs
- Cloud AI provider/model policy and budget
- Retention durations and final shared-content resolution policy
- Apple Developer team, App Group, Associated Domains, and entitlement IDs
