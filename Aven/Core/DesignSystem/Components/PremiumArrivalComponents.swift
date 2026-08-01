import SwiftUI

enum PremiumArrivalStyle {
    static let ink = Color(red: 0.09, green: 0.085, blue: 0.085)
    static let mutedInk = Color(red: 0.34, green: 0.33, blue: 0.33)
    static let blush = Color(red: 1.0, green: 0.90, blue: 0.94)
    static let pinkInk = Color(red: 0.72, green: 0.38, blue: 0.50)
    static let divider = Color.black.opacity(0.16)
}

struct PremiumArrivalBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Color.white
            .ignoresSafeArea()
            .overlay {
                if reduceTransparency == false {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.48),
                            .init(color: PremiumArrivalStyle.blush.opacity(0.10), location: 0.76),
                            .init(color: PremiumArrivalStyle.blush.opacity(0.62), location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                }
            }
    }
}

struct PremiumArrivalWordmark: View {
    var body: some View {
        Text("AVEN")
            .font(.system(size: 18, weight: .regular, design: .default))
            .tracking(7)
            .foregroundStyle(PremiumArrivalStyle.ink)
            .accessibilityIdentifier("onboarding.wordmark")
    }
}

struct PremiumPrimaryButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: LocalizedStringResource
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringResource,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .foregroundStyle(.white)
            .background(
                PremiumArrivalStyle.ink,
                in: .rect(cornerRadius: 10, style: .continuous)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.18),
                value: isLoading
            )
        }
        .disabled(isLoading)
        .buttonStyle(PremiumPressableButtonStyle())
    }
}

struct PremiumPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || configuration.isPressed == false ? 1 : 0.985
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.16),
                value: configuration.isPressed
            )
    }
}

struct PremiumArrivalScaffold<Content: View>: View {
    let primaryTitle: LocalizedStringResource
    let showsPrimaryAction: Bool
    let showsBack: Bool
    let isLoading: Bool
    let primaryAction: () -> Void
    let backAction: () -> Void
    private let content: Content

    init(
        primaryTitle: LocalizedStringResource = "action.continue",
        showsPrimaryAction: Bool = true,
        showsBack: Bool,
        isLoading: Bool = false,
        primaryAction: @escaping () -> Void,
        backAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.primaryTitle = primaryTitle
        self.showsPrimaryAction = showsPrimaryAction
        self.showsBack = showsBack
        self.isLoading = isLoading
        self.primaryAction = primaryAction
        self.backAction = backAction
        self.content = content()
    }

    var body: some View {
        ZStack {
            PremiumArrivalBackground()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PremiumArrivalWordmark()
                            .padding(.top, 28)

                        Spacer(minLength: 24)
                            .frame(height: geometry.size.height > 700 ? 116 : 52)

                        content

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 30)
                    .frame(maxWidth: 560)
                    .frame(
                        minHeight: geometry.size.height,
                        alignment: .top
                    )
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .foregroundStyle(PremiumArrivalStyle.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                if showsPrimaryAction {
                    PremiumPrimaryButton(
                        primaryTitle,
                        isLoading: isLoading,
                        action: primaryAction
                    )
                    .accessibilityIdentifier("onboarding.continue")
                }

                if showsBack {
                    Button("action.back", action: backAction)
                        .font(.body)
                        .foregroundStyle(PremiumArrivalStyle.ink)
                        .frame(minHeight: 44)
                        .buttonStyle(PremiumPressableButtonStyle())
                        .accessibilityIdentifier("onboarding.back")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.white.opacity(0.96))
        }
        .preferredColorScheme(.light)
    }
}

struct PremiumArrivalHeading: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(
                    .system(
                        size: min(titleSize, 54),
                        weight: .regular,
                        design: .serif
                    )
                )
                .tracking(-1.1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
