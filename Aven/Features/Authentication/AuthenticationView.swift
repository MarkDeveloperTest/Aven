import AuthenticationServices
import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

struct AuthenticationView: View {
    @Environment(AppSession.self) private var session
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @State private var currentNonce: String?
    let isEmbedded: Bool

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    var body: some View {
        Group {
            if isEmbedded {
                authenticationContent
            } else {
                ZStack {
                    PremiumArrivalBackground()

                    GeometryReader { geometry in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                PremiumArrivalWordmark()
                                    .padding(.top, 28)

                                authenticationContent
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 20)
                            .frame(maxWidth: 560)
                            .frame(minHeight: geometry.size.height, alignment: .top)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var authenticationContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEmbedded == false {
                Spacer(minLength: 28)
            }

            VStack(alignment: .leading, spacing: 22) {
                Text("auth.premium.title")
                    .font(
                        .system(
                            size: min(titleSize, 54),
                            weight: .regular,
                            design: .serif
                        )
                    )
                    .tracking(-1.1)
                    .foregroundStyle(PremiumArrivalStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("auth.welcome.title")

                Text("auth.welcome.subtitle")
                    .font(.body)
                    .lineSpacing(3)
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, isEmbedded ? 0 : 92)

            Spacer(minLength: 28)

            authenticationButtons

            Label("privacy.private_space", systemImage: "lock.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .padding(.top, 24)

            Text("auth.legal")
                .font(.caption)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    private var authenticationButtons: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.continue) { request in
                prepareAppleRequest(request)
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(.rect(cornerRadius: 10, style: .continuous))
            .allowsHitTesting(session.isWorking == false)
            .opacity(session.isWorking ? 0.55 : 1)
            .accessibilityIdentifier("auth.apple")

            if AppBuildEnvironment.current.supportsGoogleAuthentication {
                Button {
                    AvenHaptics.shared.light()
                    Task { await signInWithGoogle() }
                } label: {
                    Label("auth.google", systemImage: "g.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PremiumArrivalStyle.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                }
                .background(Color.white.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PremiumArrivalStyle.ink, lineWidth: 1)
                }
                .disabled(session.isWorking)
                .buttonStyle(PremiumPressableButtonStyle())
                .accessibilityIdentifier("auth.google")
            }

            Button {
                AvenHaptics.shared.light()
                Task { await session.continueAsGuest() }
            } label: {
                Text("auth.guest")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(PremiumPressableButtonStyle())
            .disabled(session.isWorking)
            .accessibilityIdentifier("auth.guest")
        }
    }

    private func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard session.isWorking == false else { return }
        AvenHaptics.shared.light()
        do {
            let nonce = try SecureNonceGenerator.make()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = SecureNonceGenerator.sha256(nonce)
        } catch {
            session.present(.authentication(.providerUnavailable))
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .failure(let error):
            currentNonce = nil
            if (error as? ASAuthorizationError)?.code == .canceled {
                session.present(.authentication(.cancelled))
            } else {
                session.present(.authentication(.invalidCredential))
            }
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                session.present(.authentication(.invalidCredential))
                return
            }

            let authorizationCode = credential.authorizationCode
                .flatMap { String(data: $0, encoding: .utf8) }
            let payload = AppleSignInPayload(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                rawNonce: nonce,
                displayName: credential.fullName.map {
                    PersonNameComponentsFormatter().string(from: $0)
                },
                fullName: credential.fullName,
                email: credential.email,
                appleUserIdentifier: credential.user
            )
            Task {
                await session.signInWithApple(payload)
                currentNonce = nil
            }
        }
    }

    @MainActor
    private func signInWithGoogle() async {
        guard session.isWorking == false else { return }
        guard
            let clientID = FirebaseApp.app()?.options.clientID,
            clientID.isEmpty == false,
            let presenter = Self.presentingViewController()
        else {
            session.present(.authentication(.notConfigured))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID
        )

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter
            )
            guard let identityToken = result.user.idToken?.tokenString else {
                session.present(.authentication(.invalidCredential))
                return
            }

            let payload = GoogleSignInPayload(
                identityToken: identityToken,
                accessToken: result.user.accessToken.tokenString
            )
            await session.signInWithGoogle(payload)
        } catch {
            let signInError = error as NSError
            if signInError.domain == kGIDSignInErrorDomain,
               signInError.code == -5 {
                session.present(.authentication(.cancelled))
            } else if signInError.domain == NSURLErrorDomain {
                session.present(.offline)
            } else {
                AppLogger.authentication.error("Google sign-in presentation failed")
                session.present(.authentication(.providerUnavailable))
            }
        }
    }

    @MainActor
    private static func presentingViewController() -> UIViewController? {
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController

        guard let rootViewController else { return nil }
        return topViewController(from: rootViewController)
    }

    @MainActor
    private static func topViewController(
        from viewController: UIViewController
    ) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tabs = viewController as? UITabBarController,
           let selected = tabs.selectedViewController {
            return topViewController(from: selected)
        }
        return viewController
    }
}
