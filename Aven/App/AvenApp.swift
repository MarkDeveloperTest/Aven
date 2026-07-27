import GoogleSignIn
import SwiftUI

@main
struct AvenApp: App {
    @State private var session: AppSession
    @State private var settings: AppSettings
    @State private var relationshipStore: RelationshipStore
    private let environment: AppEnvironment

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        _session = State(initialValue: AppSession(environment: environment))
        _settings = State(initialValue: AppSettings())
        _relationshipStore = State(initialValue: RelationshipStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(settings)
                .environment(relationshipStore)
                .tint(settings.theme.palette.accent)
                .task {
                    await session.start()
                    if let user = session.user {
                        relationshipStore.prepare(
                            for: user,
                            profile: session.profile,
                            locale: settings.language.locale
                        )
                    }
                }
                .onChange(of: session.phase) { _, phase in
                    if phase == .authenticated, let user = session.user {
                        relationshipStore.prepare(
                            for: user,
                            profile: session.profile,
                            locale: settings.language.locale
                        )
                    } else if phase == .signedOut {
                        relationshipStore.reset()
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
