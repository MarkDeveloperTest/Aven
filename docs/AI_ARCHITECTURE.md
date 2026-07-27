# Aven AI Architecture

## Status

Aven's AI design is provider-independent, permission-aware, and advisory. The
repository currently contains a guarded Firebase callable named
`secureAIProxy`. It is a backend foundation, not a live AI feature:

- no AI provider secret, model, or production endpoint is configured
- no Firebase project has been deployed or connected
- the iOS provider/router layer and user-facing AI workflow are not implemented
- Apple Foundation Models availability and language behavior are not verified

The callable, TypeScript build, lint, unit tests, and local Rules suites have
been validated. This does not prove provider quality, production authorization,
cost controls, or end-to-end user consent.

## Product boundaries

AI may help users communicate and reflect, but it must not act as an authority
about a relationship. Every AI output must be:

- clearly identified as generated
- editable, dismissible, regeneratable, and reportable
- neutral and non-diagnostic
- limited to data the requesting user is authorized and consented to use
- explicitly sent or saved by the user; never delivered to a partner
  automatically

AI must not infer cheating, abuse, mental illness, attraction, deception,
compatibility as fact, or breakup probability. It must not impersonate a user,
rank partners, or turn an experimental engagement summary into a clinical or
predictive score.

## Target dependency boundary

```text
Feature use case
    -> AI request + permitted context categories
        -> permission-aware context builder
            -> AI provider router
                -> on-device Apple adapter, when eligible
                -> authenticated cloud proxy, when explicitly allowed
                    -> configured provider adapter
```

SwiftUI views must not call an AI SDK or cloud endpoint directly. Domain-facing
protocols own request, capability, and response types. Provider adapters own
SDK-specific conversion.

A conceptual Swift boundary is:

```swift
protocol RelationshipLanguageModel: Sendable {
    var identifier: String { get }
    var capabilities: ModelCapabilities { get }

    func generate<Response: Decodable & Sendable>(
        request: AIRequest,
        responseType: Response.Type
    ) async throws -> Response
}

protocol AIProviderRouter: Sendable {
    func provider(
        for request: AIRequest
    ) async throws -> any RelationshipLanguageModel
}
```

These protocols are a design contract only until corresponding Swift types and
tests exist.

## Routing policy

Prefer an on-device Apple model when all of the following are true:

- the device and OS support the required capability
- the requested language and modality are supported
- the task fits the model's documented limits
- the result can be generated reliably
- all requested context is permitted for on-device use
- the user enabled the feature

Cloud AI is considered only when the task needs capabilities unavailable
on-device and the user has separately enabled cloud processing for every
context category involved. Lack of cloud consent is not an error that may be
silently bypassed. An unavailable provider receives an honest fallback or a
localized retry state.

Provider choice must be observable to the user at an appropriate level, but
credentials, model internals, and security controls remain server-side.

## Request contract

The current callable accepts a strict versioned shape with:

- scope: `private` or `shared`
- relationship identifier only for shared scope
- task
- English or Ukrainian output language
- bounded input text
- UUID idempotency key

The implemented task allowlist is currently:

- `calmerRewrite`
- `topicSummary`
- `conversationPrompt`
- `translate`

This is narrower than the intended MVP task set. Activity suggestions, memory
captioning/search, weekly summaries, calendar/time-zone suggestions, and
structured trend explanations remain roadmap items.

Production request types should additionally identify:

- response schema version
- permitted context categories and their consent snapshot
- source visibility for each context item
- retention policy
- provider constraints such as on-device-only
- locale, time zone, and relevant formatting preferences

Raw provider payloads must not leak into domain or UI types.

## Current cloud proxy controls

`firebase/functions/src/ai.ts` currently provides:

- Firebase Authentication and App Check requirements
- active-account and private/shared authorization checks
- mutual shared-AI opt-in for shared scope
- strict Zod input validation
- a per-user rate limit of 12 requests per five-minute window
- deterministic request IDs derived from user and idempotency key
- input-hash verification to prevent idempotency-key reuse with new content
- a short processing lease and 24-hour request expiry metadata
- a 20-second provider timeout
- HTTPS enforcement outside the local emulator
- Secret Manager parameter boundaries for the provider key
- server-side provider/model configuration
- `store: false` in the current provider request
- bounded, validated provider output
- generic provider errors and redacted operational logging

The `AIRequests` collection is server-only under Firestore Rules. It stores an
input hash rather than raw prompt content, plus processing state and the
generated output for idempotent retry. Production must add a documented TTL
policy and confirm whether retaining output for up to 24 hours is necessary.

The current proxy does not yet prove:

- a live provider call
- token and cost accounting
- content safety/reporting operations
- prompt or response quality in English and Ukrainian
- Remote Config integration
- deletion/export coverage
- load, abuse, retry, or provider-outage behavior

## Permission-aware context

Context must be assembled from typed items with an owner, visibility, source,
timestamp, and consent category. Categories include:

- user-authored prompt
- selected messages
- shared memories
- shared activities and Shared Day events
- private reflections
- private AI memory
- shared AI memory
- derived availability
- optional calendar, photo, or location-derived context

Private context never becomes shared merely because the user belongs to a
relationship. Shared AI requires both relationship membership and category
consent. Removing consent stops future use immediately and schedules any
category-specific retained context for deletion according to the approved
policy.

AI context should prefer minimal derived values over raw source data. For
example, use an agreed availability window rather than private calendar event
titles, and a confirmed place label rather than a location history.

## AI memory

The target model supports:

- private per-user memory under the user boundary
- shared relationship memory under the relationship boundary

Every memory item needs an ID, owner or creator, visibility, source, created
and updated timestamps, schema version, edit/remove controls, and an audit-safe
reason for creation. Shared memory additionally requires current relationship
membership and mutual shared-AI consent.

Current Firestore Rules define private and shared AI-memory paths and enforce
their visibility boundaries. The iOS editor, confirmation UX, lifecycle
cleanup, export, deletion, and production retention jobs are not implemented.

## Output safety and UX

Provider system instructions are defense in depth, not the authorization model.
The current cloud instruction requests neutral, non-diagnostic language and
forbids blame, separation advice, manipulation, impersonation, and automatic
sending.

Before release, each task needs:

- a typed or structurally validated response
- local presentation rules
- empty/refusal/error states
- explicit user confirmation before sharing or sending
- report and delete actions
- deterministic fixtures in English and Ukrainian
- adversarial prompt and cross-scope authorization tests

## Observability and secrets

Provider keys belong in Google Cloud Secret Manager and must never enter the
iOS app, Git, Remote Config, Firestore, analytics, crash reports, or logs.
Operational telemetry may include an opaque request ID, task, provider class,
latency bucket, result category, token/cost aggregate, and error code. It must
exclude raw prompts, generated relationship content, messages, memories, exact
locations, direct identifiers, and secrets by default.

## Release gates

AI remains unavailable in production until all of these are evidenced:

- Swift provider protocols, router, context builder, and UI are implemented
- on-device capability checks and useful fallbacks are tested
- cloud provider/legal/retention terms are approved
- Auth, App Check, membership, consent, rate-limit, and replay tests pass
- output schemas and localized error paths are tested
- provider outage, timeout, cost, and abuse controls are exercised
- private/shared memory edit, export, unlink, and deletion flows work
- English and Ukrainian safety/quality review is complete
- no credential or private-payload logging issue remains

