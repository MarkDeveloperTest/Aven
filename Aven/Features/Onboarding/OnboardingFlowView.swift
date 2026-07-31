import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isNameFocused: Bool
    @State private var store = OnboardingStore()
    @State private var transitionDirection: StepTransitionDirection = .forward

    var body: some View {
        PremiumArrivalScaffold(
            primaryTitle: store.step == .finish
                ? "onboarding.finish.action"
                : "action.continue",
            showsPrimaryAction: store.step != .finish || session.user != nil,
            showsBack: store.canGoBack,
            isLoading: session.isWorking,
            primaryAction: {
                store.step == .finish ? completeOnboarding() : goForward()
            },
            backAction: goBack
        ) {
            currentScreen
                .id(store.step)
                .transition(screenTransition)
                .accessibilityIdentifier("onboarding.screen.\(store.step.rawValue)")
        }
        .task(id: session.onboardingDraftUserID) {
            store.attach(to: session.onboardingDraftUserID)
            settings.language = AppLanguage.inferred(fromRegionCode: store.countryCode)
        }
        .onChange(of: store.step) { _, _ in
            isNameFocused = false
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch store.step {
        case .privacy:
            privacyScreen
        case .displayName:
            displayNameScreen
        case .birthDate:
            birthDateScreen
        case .gender:
            genderScreen
        case .countryRegion:
            countryScreen
        case .relationshipType:
            relationshipTypeScreen
        case .relationshipStartDate:
            relationshipDateScreen
        case .notifications:
            notificationsScreen
        case .notificationPreviews:
            notificationPreviewsScreen
        case .preciseLocation:
            preciseLocationScreen
        case .aiPreference:
            aiPreferenceScreen
        case .pairing:
            pairingScreen
        case .finish:
            finishScreen
        }
    }

    private var privacyScreen: some View {
        PremiumArrivalHeading(
            title: "onboarding.privacy.title",
            message: "onboarding.privacy.message"
        )
    }

    private var displayNameScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.name.title",
                message: "onboarding.name.message"
            )

            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "onboarding.profile.name",
                    text: Bindable(store).displayName
                )
                .font(.system(size: 24, weight: .regular))
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($isNameFocused)
                .onSubmit(goForward)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            isNameFocused
                                ? PremiumArrivalStyle.ink
                                : PremiumArrivalStyle.divider
                        )
                        .frame(height: isNameFocused ? 2 : 1)
                        .animation(
                            reduceMotion ? nil : .smooth(duration: 0.22),
                            value: isNameFocused
                        )
                }
                .accessibilityIdentifier("onboarding.name")

                inlineValidation
            }
        }
    }

    private var birthDateScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.birth_date.title",
                message: "onboarding.birth_date.message"
            )

            DatePicker(
                "onboarding.profile.birth_date",
                selection: Bindable(store).dateOfBirth,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .tint(PremiumArrivalStyle.pinkInk)
            .accessibilityIdentifier("onboarding.birth-date")

        }
    }

    private var countryScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.country.title",
                message: "onboarding.country.message"
            )

            VStack(spacing: 0) {
                countryChoice("country.uk", code: "GB")
                Divider().overlay(PremiumArrivalStyle.divider)
                countryChoice("country.ukraine", code: "UA")
                Divider().overlay(PremiumArrivalStyle.divider)
                countryChoice("country.us", code: "US")
            }
        }
    }

    private var genderScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.gender.title",
                message: "onboarding.gender.message"
            )

            VStack(spacing: 0) {
                ForEach(Gender.allCases) { gender in
                    choiceRow(
                        title: gender.localizedResource,
                        isSelected: store.gender == gender
                    ) {
                        Haptics.selection()
                        store.gender = gender
                        store.validationError = nil
                    }
                    .accessibilityIdentifier(
                        "onboarding.gender.\(gender.rawValue)"
                    )

                    if gender != Gender.allCases.last {
                        Divider().overlay(PremiumArrivalStyle.divider)
                    }
                }

                inlineValidation
                    .padding(.top, 12)
            }
        }
    }

    private var relationshipTypeScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.relationship_type.title",
                message: "onboarding.relationship_type.message"
            )

            VStack(spacing: 0) {
                ForEach(RelationshipType.onboardingCases) { type in
                    choiceRow(
                        title: type.localizedResource,
                        isSelected: store.relationshipType == type
                    ) {
                        Haptics.selection()
                        store.relationshipType = type
                    }

                    if type.id != RelationshipType.onboardingCases.last?.id {
                        Divider().overlay(PremiumArrivalStyle.divider)
                    }
                }
            }
        }
    }

    private var relationshipDateScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.relationship_date.title",
                message: "onboarding.relationship_date.message"
            )

            DatePicker(
                "onboarding.relationship.start_date",
                selection: relationshipStartDateBinding,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .tint(PremiumArrivalStyle.pinkInk)
        }
    }

    private var notificationsScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.notifications.title",
                message: "onboarding.notifications.message"
            )

            VStack(spacing: 0) {
                choiceRow(
                    title: "onboarding.notifications.enable",
                    isSelected: store.wantsNotifications
                ) {
                    Haptics.selection()
                    store.wantsNotifications = true
                    Task { await NotificationAuthorizationClient.requestIfNeeded() }
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: store.wantsNotifications == false
                ) {
                    Haptics.selection()
                    store.wantsNotifications = false
                }
            }
        }
    }

    private var notificationPreviewsScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.notification_previews.title",
                message: "onboarding.notification_previews.message"
            )

            VStack(spacing: 0) {
                choiceRow(
                    title: "onboarding.notification_previews.show",
                    isSelected: settings.notificationPreviewsEnabled
                ) {
                    Haptics.selection()
                    settings.notificationPreviewsEnabled = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.notification_previews.private",
                    isSelected: settings.notificationPreviewsEnabled == false
                ) {
                    Haptics.selection()
                    settings.notificationPreviewsEnabled = false
                }
            }
        }
    }

    private var preciseLocationScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.location.title",
                message: "onboarding.location.message"
            )

            VStack(spacing: 0) {
                choiceRow(
                    title: "onboarding.location.enable",
                    isSelected: store.wantsPreciseLocation
                ) {
                    Haptics.selection()
                    store.wantsPreciseLocation = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: store.wantsPreciseLocation == false
                ) {
                    Haptics.selection()
                    store.wantsPreciseLocation = false
                }
            }
        }
    }

    private var aiPreferenceScreen: some View {
        VStack(alignment: .leading, spacing: 34) {
            PremiumArrivalHeading(
                title: "onboarding.ai.title",
                message: "onboarding.ai.message"
            )

            VStack(spacing: 0) {
                choiceRow(
                    title: "onboarding.ai.enable",
                    isSelected: settings.aiEnabled
                ) {
                    Haptics.selection()
                    settings.aiEnabled = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: settings.aiEnabled == false
                ) {
                    Haptics.selection()
                    settings.aiEnabled = false
                }
            }
        }
    }

    private var pairingScreen: some View {
        CouplePairingView(
            presentation: .onboarding,
            relationshipType: store.relationshipType,
            relationshipStartDate: store.relationshipStartDate
        )
    }

    private var finishScreen: some View {
        VStack(alignment: .leading, spacing: 28) {
            if session.user == nil {
                AuthenticationView(isEmbedded: true)
            } else {
                PremiumArrivalHeading(
                    title: "onboarding.finish.title",
                    message: "onboarding.finish.message"
                )

                if store.displayName.isEmpty == false {
                    Text(verbatim: store.displayName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(PremiumArrivalStyle.pinkInk)
                }

                Label("privacy.private_space", systemImage: "lock.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
                    .padding(.top, 8)
            }
        }
    }

    private func countryChoice(
        _ title: LocalizedStringResource,
        code: String
    ) -> some View {
        choiceRow(title: title, isSelected: store.countryCode == code) {
            Haptics.selection()
            store.countryCode = code
            settings.language = AppLanguage.inferred(fromRegionCode: code)
        }
    }

    private func choiceRow(
        title: LocalizedStringResource,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PremiumArrivalStyle.ink)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 16)

                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? PremiumArrivalStyle.pinkInk
                                : PremiumArrivalStyle.divider,
                            lineWidth: 1
                        )
                        .frame(width: 21, height: 21)

                    if isSelected {
                        Circle()
                            .fill(PremiumArrivalStyle.pinkInk)
                            .frame(width: 9, height: 9)
                    }
                }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var inlineValidation: some View {
        if let error = store.validationError {
            Label {
                Text(error.localizedResource)
                    .font(.caption)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .foregroundStyle(Color(red: 0.66, green: 0.25, blue: 0.34))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var relationshipStartDateBinding: Binding<Date> {
        Binding(
            get: { store.relationshipStartDate ?? .now },
            set: {
                Haptics.selection()
                store.relationshipStartDate = $0
            }
        )
    }

    private var screenTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .offset(
                    x: transitionDirection == .forward ? 18 : -18
                ).combined(with: .opacity),
                removal: .opacity
            )
    }

    private func goForward() {
        let previousStep = store.step
        transitionDirection = .forward
        Haptics.light()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.42)) {
            store.goForward()
        }
        if previousStep == .preciseLocation, store.wantsPreciseLocation {
            Task { await LocationAuthorizationClient.requestAlwaysPreciseIfNeeded() }
        }
        if store.step == previousStep, store.validationError != nil {
            Haptics.error()
        }
    }

    private func goBack() {
        guard store.canGoBack else { return }
        transitionDirection = .backward
        Haptics.soft()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.38)) {
            store.goBack()
        }
    }

    private func completeOnboarding() {
        guard let user = session.user else {
            Haptics.error()
            session.present(.authentication(.invalidCredential))
            return
        }

        do {
            let profile = try store.makeProfile(userID: user.id)
            Haptics.success()
            Task {
                await session.completeOnboarding(with: profile)
                if session.phase == .authenticated {
                    store.resetProgress()
                }
            }
        } catch let error as AppError {
            Haptics.error()
            store.validationError = error
        } catch {
            Haptics.error()
            store.validationError = .unknown
        }
    }
}

private extension RelationshipType {
    static let onboardingCases: [RelationshipType] = [
        .dating,
        .longDistance,
        .engaged,
        .married,
    ]
}

private enum StepTransitionDirection {
    case forward
    case backward
}

@MainActor
private enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.62)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
