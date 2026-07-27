# Aven build configuration

Xcode configurations map to environments as follows:

| Xcode configuration | xcconfig | Environment | Temporary bundle identifier |
| --- | --- | --- | --- |
| Debug | `Development.xcconfig` | Development | `com.example.aven.dev` |
| Staging | `Staging.xcconfig` | Staging | `com.example.aven.staging` |
| Release | `Production.xcconfig` | Production | `com.example.aven` |

Replace the three `AVEN_BUNDLE_IDENTIFIER` values before registering the app
with Apple or Firebase. Keep their environment suffixes distinct.

For local device signing, copy `Secrets.xcconfig.example` to
`Secrets.xcconfig` and set `DEVELOPMENT_TEAM`. The local file is ignored by
Git. Simulator builds explicitly disable code signing and do not require it.

Each Firebase environment should supply its own untracked
`GoogleService-Info.plist`. Do not place API secrets or service-account
credentials in this directory or in the iOS app.

