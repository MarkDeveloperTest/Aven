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
        _relationshipStore = State(
            initialValue: RelationshipStore(
                repository: environment.relationshipRepository,
                pairingIntentVault: environment.pairingIntentVault
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(settings)
                .environment(relationshipStore)
                .tint(PremiumArrivalStyle.pinkInk)
                .task {
                    await relationshipStore.restoreDeferredPairing()
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
                    if (phase == .onboarding || phase == .authenticated),
                       let user = session.user {
                        relationshipStore.prepare(
                            for: user,
                            profile: session.profile,
                            locale: settings.language.locale
                        )
                    } else if phase == .signedOut {
                        relationshipStore.reset()
                    }
                }
                .onChange(of: session.user?.id) { previousUserID, userID in
                    guard let userID, let user = session.user else {
                        if previousUserID != nil {
                            relationshipStore.reset()
                        }
                        return
                    }
                    guard user.id == userID else { return }
                    relationshipStore.prepare(
                        for: user,
                        profile: session.profile,
                        locale: settings.language.locale
                    )
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
