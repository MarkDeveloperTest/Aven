import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(RelationshipStore.self) private var relationshipStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isNameFocused: Bool
    @State private var store = OnboardingStore()
    @State private var transitionDirection: StepTransitionDirection = .forward

    var body: some View {
        PremiumArrivalScaffold(
            primaryTitle: store.step == .finish
                ? "onboarding.finish.action"
                : "action.continue",
            showsPrimaryAction: showsPrimaryAction,
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
            if relationshipStore.isActive == false {
                store.requirePairingBeforeFinish()
            }
            settings.language = AppLanguage.inferred(fromRegionCode: store.countryCode)
        }
        .task(id: pairingPreparationID) {
            await preparePairingProfileIfNeeded()
        }
        .onChange(of: relationshipStore.isActive) { _, isActive in
            if isActive == false {
                store.requirePairingBeforeFinish()
            }
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
                        guard store.gender != gender else { return }
                        AvenHaptics.shared.selection()
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
                        guard store.relationshipType != type else { return }
                        AvenHaptics.shared.selection()
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
                    guard store.wantsNotifications == false else { return }
                    AvenHaptics.shared.selection()
                    store.wantsNotifications = true
                    Task { await NotificationAuthorizationClient.requestIfNeeded() }
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: store.wantsNotifications == false
                ) {
                    guard store.wantsNotifications else { return }
                    AvenHaptics.shared.selection()
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
                    guard settings.notificationPreviewsEnabled == false else { return }
                    AvenHaptics.shared.selection()
                    settings.notificationPreviewsEnabled = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.notification_previews.private",
                    isSelected: settings.notificationPreviewsEnabled == false
                ) {
                    guard settings.notificationPreviewsEnabled else { return }
                    AvenHaptics.shared.selection()
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
                    guard store.wantsPreciseLocation == false else { return }
                    AvenHaptics.shared.selection()
                    store.wantsPreciseLocation = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: store.wantsPreciseLocation == false
                ) {
                    guard store.wantsPreciseLocation else { return }
                    AvenHaptics.shared.selection()
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
                    guard settings.aiEnabled == false else { return }
                    AvenHaptics.shared.selection()
                    settings.aiEnabled = true
                }

                Divider().overlay(PremiumArrivalStyle.divider)

                choiceRow(
                    title: "onboarding.option.not_now",
                    isSelected: settings.aiEnabled == false
                ) {
                    guard settings.aiEnabled else { return }
                    AvenHaptics.shared.selection()
                    settings.aiEnabled = false
                }
            }
        }
    }

    private var pairingScreen: some View {
        Group {
            if session.user == nil {
                AuthenticationView(isEmbedded: true)
            } else if session.profile == nil {
                HStack(spacing: 14) {
                    ProgressView()
                        .tint(PremiumArrivalStyle.pinkInk)

                    Text("pairing.connecting")
                        .font(.body.weight(.medium))
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .accessibilityElement(children: .combine)
            } else {
                CouplePairingView(
                    presentation: .onboarding,
                    relationshipType: store.relationshipType,
                    relationshipStartDate: store.relationshipStartDate
                )
            }
        }
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
            guard store.countryCode != code else { return }
            AvenHaptics.shared.selection()
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
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .background(
                isSelected ? PremiumArrivalStyle.blush.opacity(0.28) : .clear,
                in: .rect(cornerRadius: AvenRadius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PremiumPressableButtonStyle())
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isSelected)
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
                store.relationshipStartDate = $0
            }
        )
    }

    private var showsPrimaryAction: Bool {
        switch store.step {
        case .pairing:
            pairingIsComplete
        case .finish:
            session.user != nil
        default:
            true
        }
    }

    private var pairingPreparationID: String {
        guard store.step == .pairing else { return "not-pairing" }
        return [
            "pairing",
            session.user?.id ?? "signed-out",
            session.profile?.userID ?? "profile-missing",
        ].joined(separator: ":")
    }

    private var pairingIsComplete: Bool {
        session.user != nil
            && session.profile != nil
            && relationshipStore.isActive
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
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.42)) {
            store.goForward(pairingIsComplete: pairingIsComplete)
        }
        if previousStep == .preciseLocation, store.wantsPreciseLocation {
            Task { await LocationAuthorizationClient.requestAlwaysPreciseIfNeeded() }
        }
        if store.step == previousStep, store.validationError != nil {
            AvenHaptics.shared.error()
        } else if store.step != previousStep {
            AvenHaptics.shared.light()
        }
    }

    private func preparePairingProfileIfNeeded() async {
        guard
            store.step == .pairing,
            let user = session.user,
            session.profile == nil
        else {
            return
        }

        do {
            let profile = try store.makeProfile(userID: user.id)
            await session.prepareProfileForPairing(profile)
        } catch let error as AppError {
            store.validationError = error
        } catch {
            store.validationError = .unknown
        }
    }

    private func goBack() {
        guard store.canGoBack else { return }
        transitionDirection = .backward
        AvenHaptics.shared.soft()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.38)) {
            store.goBack()
        }
    }

    private func completeOnboarding() {
        guard let user = session.user else {
            AvenHaptics.shared.error()
            session.present(.authentication(.invalidCredential))
            return
        }

        do {
            let profile = try store.makeProfile(userID: user.id)
            Task {
                await session.completeOnboarding(with: profile)
                if session.phase == .authenticated {
                    AvenHaptics.shared.success()
                    store.resetProgress()
                }
            }
        } catch let error as AppError {
            AvenHaptics.shared.error()
            store.validationError = error
        } catch {
            AvenHaptics.shared.error()
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
