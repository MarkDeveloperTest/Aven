import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                OnboardingFlowView()
            case .onboarding:
                OnboardingFlowView()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.28),
            value: session.phase
        )
        .environment(\.locale, settings.language.locale)
        .preferredColorScheme(.light)
        .alert(
            Text("error.title"),
            isPresented: Binding(
                get: { session.presentedError != nil },
                set: { if $0 == false { session.dismissError() } }
            ),
            presenting: session.presentedError
        ) { _ in
            Button("action.ok") {
                session.dismissError()
            }
        } message: { error in
            Text(error.localizedResource)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            PremiumArrivalBackground()

            VStack(alignment: .leading, spacing: 0) {
                PremiumArrivalWordmark()
                    .padding(.top, 28)

                Spacer()

                ProgressView()
                    .controlSize(.large)
                    .tint(PremiumArrivalStyle.pinkInk)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("launch.loading"))

                Spacer()
            }
            .padding(.horizontal, 30)
        }
    }
}
