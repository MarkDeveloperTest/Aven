# Aven Architecture

## Status and scope

This document defines the target architecture for the iPhone app and Firebase
backend. Project construction is in progress; a described boundary is not
evidence that its concrete implementation is complete. See
[PROGRESS.md](PROGRESS.md).

## Architectural goals

- Keep product rules independent of SwiftUI, Firebase, and individual AI SDKs.
- Make sharing, authorization, lifecycle, and deletion rules testable without a
  network.
- Keep views declarative and free of collection paths or direct networking.
- Make development, staging, production, previews, and tests explicit
  dependency configurations.
- Preserve an iOS 26 path while isolating iOS 27-only capabilities.
- Support offline work without creating a second cloud source of truth.

## Dependency direction

```text
SwiftUI Views
    -> feature state / presentation models
        -> domain use cases
            -> domain repository and service protocols
                <- data repository implementations
                    <- Firebase / local cache / Apple and AI SDK adapters
```

Dependencies point inward. Domain entities and use cases do not import Firebase
or SwiftUI. Data DTOs do not leak into views. Cross-feature work goes through a
domain operation or intentionally shared core service rather than reaching
through another feature's internals.

## Runtime composition

The app entry point creates an `AppEnvironment`/dependency container with:

- brand and environment configuration
- authentication and session services
- repository implementations
- analytics, logging, redaction, and error translation
- permissions and privacy services
- local persistence and synchronization
- AI provider router and permission-aware context builder
- clocks, UUID generation, and other deterministic test seams

Production uses concrete Firebase and platform adapters. Development may use
the emulator or fictional demo data behind a development-only flag. Previews
and tests receive isolated fakes. A global mutable service locator is not part
of the design.

## Feature boundaries

Each meaningful feature may contain its own views, observable state,
presentation models, and feature-specific use cases:

- Authentication and session
- Onboarding and age gate
- Pairing and invitations
- Relationship lifecycle and archives
- Home dashboard
- Messaging
- Memories
- Shared Day and location moments
- Insights
- AI assistance and memory
- Profile
- Settings, privacy, export, and deletion

Use the smallest presentation pattern that keeps ownership and effects clear.
Simple SwiftUI screens can use a focused observable model. Features with
auditable lifecycle transitions may use an explicit state machine. Avoid
forwarding-only view models and feature-wide “god” objects.

## Project layout

The intended high-level layout is:

```text
Aven/
  App/                 composition, routing, environment configuration
  Core/                cross-cutting analytics, errors, logging, permissions
  Domain/              entities, value objects, repository protocols, use cases
  Data/                DTOs, mappers, Firebase/local adapters, repositories
  Features/            feature-owned UI and presentation state
  Resources/           assets, String Catalog, privacy/config resources
AvenWidgets/           privacy-aware widget extension
AvenTests/             unit and contract tests
AvenUITests/           XCUITest flows
firebase/              rules, indexes, Functions, emulator configuration
docs/                  product, architecture, operations, and status
```

Folders should be introduced by working vertical slices, not solely to mirror a
diagram.

## Navigation and UI state

Use `NavigationStack` with typed routes and a small iPhone-native tab structure:
Home, Messages, Memories, Our Day, and Us. “Us” owns relationship information,
insights, archive, and settings.

App/session routing distinguishes at least launching, signed out, onboarding,
unpaired, invitation pending, active relationship, and archived contexts.
UI-facing mutable state runs on the main actor. Long-lived listeners are
bridged to `AsyncSequence` or an equivalent cancellable abstraction and stop
when the session or owning feature ends.

## Data ownership

Firebase is the canonical shared store. Firestore holds typed metadata and
relationship-scoped records; Storage holds validated media; Functions mediate
privileged or rate-sensitive operations.

SwiftData is limited to selected cache/offline roles:

- cached profile and relationship summary
- recent paginated messages and timeline metadata
- thumbnails and media state
- drafts, pending uploads, and safe offline operations
- UI preferences and permitted AI cache

Synchronization records server version/last-write metadata, pending status,
retry state, conflict policy, and deletion tombstones. A remote deletion must
not be resurrected from cache.

## Firebase boundaries

Views never know Firestore collection paths. Data sources map typed DTOs to
domain values. Sensitive operations such as invitation redemption,
relationship creation, lifecycle resolution, export, deletion, notification
fan-out, counters, and cloud AI run through authenticated Functions with input
validation and App Check.

Unbounded records use subcollections and pagination. Server timestamps and
schema versions are required. Internal notification, moderation, and audit
collections are not client-readable.

## Environment model

`Debug`, `Staging`, and `Release` map to development, staging, and production
services. Each environment has a separate bundle identifier, Firebase project,
URL scheme, App Check policy, and non-secret configuration. Production data
must never be used by the development build.

Configuration files identify an environment but must not contain provider API
secrets. Firebase client configuration plists are environment-specific and
remain outside source control.

## iOS 26 and iOS 27

iOS 26 is the deployment floor. Code that requires iOS 27 uses `@available`
checks and an injected protocol. Unsupported devices receive a useful fallback,
not a hidden crash or compile-time dependency.

The current environment has Xcode 27 beta and an iOS 27 simulator runtime, but
no iOS 26 runtime. Therefore the architecture can be built against the iOS 27
SDK while iOS 26 runtime behavior remains an open verification gate.

## Concurrency

- UI mutation is main-actor isolated.
- Shared mutable service state is actor-isolated where appropriate.
- Public async boundaries use typed errors and honor cancellation.
- Firestore listeners, uploads, and session tasks have explicit lifetimes.
- `Sendable` is adopted only where valid.
- Unstructured tasks and concurrency-warning suppression require written
  justification.
- Retry uses an injected clock/backoff policy so tests do not sleep.

## Error and observability boundaries

Domain/application errors cover authentication, network, permission, Firebase,
validation, media, AI, relationship state, invitation, rate limit, offline, and
unknown failures. Presentation maps them to localized safe messages and
recovery actions; underlying diagnostics stay out of production UI.

Analytics events are typed and exclude private content and raw user IDs. Local
logs and Crashlytics metadata pass through redaction helpers. Sensitive prompts,
messages, journals, media, and exact coordinates are not recorded by default.

## Delivery strategy

Implementation proceeds as tested vertical slices:

1. project/configuration/localization/design foundation
2. Firebase and emulator foundation
3. authentication/onboarding
4. pairing/lifecycle
5. navigation/home
6. messaging
7. memories
8. Shared Day/location
9. insights
10. AI
11. Apple integrations
12. hardening and App Store preparation

Each slice must build, test relevant success and failure paths, update
documentation, and list external actions before it is reported complete.
