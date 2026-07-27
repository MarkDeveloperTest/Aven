# Localization

## Scope and status

Aven launches in English (`en`) and Ukrainian (`uk`). Localization is a
foundation requirement, not a final copy claim: the String Catalog, UI coverage,
notification templates, permission text, and Ukrainian linguistic review must
be verified as each feature is implemented.

Users can choose the app language independently of the device language.
User-generated content retains its original language.

## Source of truth

Use `Localizable.xcstrings` for app copy and `InfoPlist.xcstrings` for localized
bundle/permission text. Prefer stable, namespaced keys instead of English prose
as API-facing identifiers:

```text
onboarding.welcome.title
pairing.invite.expiry
privacy.location.precise.explanation
error.network.retry
ai.disclaimer.generated
```

Keep product-facing name and link values in centralized brand configuration so
a rename does not churn every translation. Give translators context comments
for ambiguous strings, privacy-sensitive wording, placeholders, and character
limits.

## Swift usage

- SwiftUI literals/typed catalog symbols: `LocalizedStringKey`
- Service, validator, and error output resolved now: `String(localized:)`
- App Intents, widgets, notifications, and deferred system UI:
  `LocalizedStringResource`
- Logs, analytics event identifiers, schema fields: stable nonlocalized strings

Do not concatenate user-facing phrases. Interpolate typed values into one
localized unit so Ukrainian can reorder and inflect it correctly. Avoid
user-facing English buried in errors, fallbacks, accessibility labels, or
notification handlers.

## Formatting

Use Foundation `FormatStyle` for:

- calendar dates and relationship duration
- relative time and message timestamps
- partner-local time and time-zone names
- counts and pluralization
- distance and other measurements
- lists and percentages

Never hard-code date order, 12/24-hour assumptions, decimal separators, units,
or plural rules. Store canonical timestamps and time-zone identifiers; format
at the presentation boundary using the user's selected locale and intended
event time zone.

## Ukrainian quality

Ukrainian needs human review for cases, gender, polite tone, plural categories,
and relationship-sensitive vocabulary. Preserve complete phrases for
translation and use catalog plural variations rather than manual
`count == 1` logic.

AI disclaimers and privacy explanations must remain neutral and unambiguous in
both languages. Machine-generated translations are drafts, not linguistic QA.

## AI language behavior

AI responds in this order:

1. a language explicitly requested for the task
2. the clear language of selected conversation context when appropriate
3. the user's selected app language

Provider selection must account for language capability. Generated content is
labeled, remains editable, and must not silently translate user-generated
content or overwrite its original language. Stored AI memory may include
language/locale metadata without changing visibility authorization.

## Notifications, widgets, and extensions

System-facing text is localized at display or server-render time using an
explicit locale. Notification generation must know the recipient's chosen
language without exposing private message content. Widgets and App Intents use
deferred localizable resources and provide privacy-safe locked/redacted text.

Every extension target must include or safely access the required catalog
resources; do not assume the main app bundle is available.

## Adding or changing a string

1. Add a stable namespaced key and English source value.
2. Add a translator comment describing screen, intent, placeholders, and tone.
3. Add the Ukrainian translation, including all plural/device variations.
4. Use typed interpolation and locale-aware formatting.
5. Exercise the screen in both languages at normal and accessibility text
   sizes.
6. Check VoiceOver label, hint, value, reading order, and truncation.
7. Test a longer pseudolocalized value; record unresolved linguistic review.

## Test matrix

- English and Ukrainian first launch/onboarding
- runtime language switch and relaunch persistence
- age-gate and validation errors
- invitation expiry and relationship lifecycle terminology
- messages, timestamps, relative time, and time zones
- privacy, permission, emergency unlink, export, and deletion language
- AI consent/disclaimers and generated-content labels
- notification categories and generic privacy mode
- widgets, App Intents, and extension resources
- Dynamic Type, VoiceOver, and double-length pseudolocalization

Although English and Ukrainian are left-to-right, layouts should use
`leading`/`trailing` and flexible sizing so later right-to-left expansion does
not require a redesign.

## Release gate

Localization is complete only when catalog extraction reports no unintended
user-facing literals, both locales have required variants, linguistic review
is recorded, system surfaces use the correct resources, and primary UI tests
pass in both languages. The foundation stage has not yet met this release gate.
