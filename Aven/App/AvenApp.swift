import GoogleSignIn
import SwiftUI
import UIKit

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
                    AvenHaptics.shared.prepare()
                    let pairingRestoreTask = Task { @MainActor in
                        await relationshipStore.restoreDeferredPairing()
                    }
                    await session.start()
                    await pairingRestoreTask.value
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
                .onChange(of: session.profile?.userID) { _, profileUserID in
                    guard
                        let profileUserID,
                        let user = session.user,
                        user.id == profileUserID
                    else {
                        return
                    }
                    relationshipStore.prepare(
                        for: user,
                        profile: session.profile,
                        locale: settings.language.locale
                    )
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.protectedDataDidBecomeAvailableNotification
                    )
                ) { _ in
                    Task {
                        await relationshipStore.restoreDeferredPairing()
                        if let user = session.user {
                            relationshipStore.prepare(
                                for: user,
                                profile: session.profile,
                                locale: settings.language.locale
                            )
                        }
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handleIncomingURL(url)
                }
        }
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        if let credential = PairingQRCodePayload.parse(url) {
            Task {
                await relationshipStore.restoreDeferredPairing()
                relationshipStore.redeemInvitation(credential: credential)
            }
            return
        }
        _ = GIDSignIn.sharedInstance.handle(url)
    }
}
