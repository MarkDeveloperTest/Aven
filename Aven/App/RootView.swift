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
                AuthenticationView()
            case .onboarding:
                OnboardingFlowView()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: session.phase)
        .environment(\.locale, settings.language.locale)
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
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            AvenBackground()
            ProgressView()
                .controlSize(.large)
                .tint(settings.theme.palette.onBackground)
                .accessibilityLabel(Text("launch.loading"))
        }
    }
}
