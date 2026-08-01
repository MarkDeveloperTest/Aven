import SwiftUI
import UIKit

struct CouplePairingView: View {
    enum Presentation {
        case onboarding
        case dashboard

        var qrSize: CGFloat {
            switch self {
            case .onboarding: 176
            case .dashboard: 184
            }
        }
    }

    private enum Screen: Hashable {
        case choice
        case invite
        case join
        case codeEntry
    }

    @Environment(RelationshipStore.self) private var relationshipStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isCodeFieldFocused: Bool
    @State private var screen = Screen.choice
    @State private var transitionDirection = PairingTransitionDirection.forward
    @State private var showsScanner = false
    @State private var showCodeAfterScanner = false
    @State private var showsCopiedConfirmation = false
    @State private var manualEntry = ""
    @State private var lastSubmittedCode: String?
    @State private var lastHapticError: AppError?
    @State private var celebratedRelationshipID: String?
    @State private var successIsVisible = false

    let presentation: Presentation
    let relationshipType: RelationshipType
    let relationshipStartDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Group {
                if relationshipStore.isActive {
                    connectedState
                } else if relationshipStore.isPairing {
                    workingState
                } else if let invitation = relationshipStore.invitation,
                          relationshipStore.relationship.status == .invitationPending {
                    invitationState(invitation)
                } else {
                    screenContent
                        .id(screen)
                        .transition(screenTransition)
                }
            }

            if let pairingError = relationshipStore.pairingError {
                pairingErrorView(pairingError)
            }
        }
        .fullScreenCover(isPresented: $showsScanner, onDismiss: scannerDidDismiss) {
            PairingQRScannerView(
                environment: .current,
                onScanned: redeemLinkToken,
                onManualEntryRequested: requestCodeEntryFromScanner
            )
        }
        .onChange(of: relationshipStore.pairingError) { _, error in
            guard let error, error != lastHapticError else { return }
            lastHapticError = error
            AvenHaptics.shared.error()
        }
        .onChange(of: relationshipStore.isActive) { _, isActive in
            guard isActive else { return }
            celebrateConnectionIfNeeded()
        }
        .task {
            celebrateConnectionIfNeeded()
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .choice:
            choiceState
        case .invite:
            createInvitationState
        case .join:
            joinState
        case .codeEntry:
            manualCodeState
        }
    }

    private var choiceState: some View {
        VStack(alignment: .leading, spacing: 30) {
            heading(
                title: "pairing.choice.title",
                message: "pairing.choice.message"
            )

            VStack(spacing: 12) {
                PairingActionRow(
                    title: "pairing.choice.invite",
                    message: "pairing.choice.invite.message",
                    systemImage: "qrcode",
                    action: showInvite
                )
                .accessibilityIdentifier("pairing.invite")

                PairingActionRow(
                    title: "pairing.choice.join",
                    message: "pairing.choice.join.message",
                    systemImage: "person.2.badge.plus",
                    action: showJoin
                )
                .accessibilityIdentifier("pairing.join")
            }
        }
    }

    private var createInvitationState: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading(
                title: "pairing.invite.title",
                message: "pairing.invite.message"
            )

            PremiumPrimaryButton("pairing.invite.create", action: createInvitation)
                .accessibilityIdentifier("pairing.create")

            pairingBackButton(action: showChoice)
        }
    }

    private var joinState: some View {
        VStack(alignment: .leading, spacing: 30) {
            heading(
                title: "pairing.join.title",
                message: "pairing.join.message"
            )

            VStack(spacing: 12) {
                PairingActionRow(
                    title: "pairing.join.scan",
                    message: "pairing.join.scan.message",
                    systemImage: "viewfinder",
                    action: openScanner
                )
                .accessibilityIdentifier("pairing.scan")

                PairingActionRow(
                    title: "pairing.join.code",
                    message: "pairing.join.code.message",
                    systemImage: "character.cursor.ibeam",
                    action: showCodeEntry
                )
                .accessibilityIdentifier("pairing.enter-code")
            }

            pairingBackButton(action: showChoice)
        }
    }

    private var manualCodeState: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading(
                title: "pairing.code.title",
                message: "pairing.code.message"
            )

            PairingManualCodeField(
                code: $manualEntry,
                isFocused: $isCodeFieldFocused,
                hasError: relationshipStore.pairingError != nil,
                onChanged: manualCodeChanged
            )

            pairingBackButton(action: showJoin)
        }
        .task {
            isCodeFieldFocused = true
        }
    }

    private func invitationState(_ invitation: PairingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            heading(
                title: "pairing.invitation.title",
                message: "pairing.invitation.message"
            )

            if invitation.expiresAt <= .now {
                expiredInvitationState
            } else if let payload = PairingQRCodePayload.makePayload(
                linkToken: invitation.linkToken,
                environment: .current
            ) {
                VStack(spacing: 16) {
                    PairingQRCodeView(payload: payload, size: presentation.qrSize)
                        .padding(10)
                        .background(
                            PremiumArrivalStyle.blush.opacity(0.38),
                            in: .rect(cornerRadius: 20, style: .continuous)
                        )

                    Text(invitation.formattedManualCode)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(PremiumArrivalStyle.ink)
                        .textSelection(.enabled)
                        .accessibilityLabel(Text("pairing.code.accessibility"))

                    Text("pairing.invitation.expiry")
                        .font(.footnote)
                        .foregroundStyle(PremiumArrivalStyle.mutedInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                ShareLink(
                    item: shareMessage(invitation: invitation, url: payload),
                    subject: Text("pairing.share.subject")
                ) {
                    Label("pairing.share.action", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            PremiumArrivalStyle.ink,
                            in: .rect(cornerRadius: AvenRadius.control, style: .continuous)
                        )
                }
                .buttonStyle(PremiumPressableButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AvenHaptics.shared.soft()
                })
                .accessibilityIdentifier("pairing.share")

                HStack(spacing: 18) {
                    Button(action: { copy(invitation.formattedManualCode) }) {
                        Label(
                            showsCopiedConfirmation
                                ? "pairing.copy.confirmation"
                                : "pairing.copy",
                            systemImage: showsCopiedConfirmation
                                ? "checkmark"
                                : "doc.on.doc"
                        )
                    }
                    .accessibilityIdentifier("pairing.copy")

                    Button("pairing.invitation.new", action: replaceInvitation)
                        .accessibilityIdentifier("pairing.replace")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PremiumArrivalStyle.ink)
                .buttonStyle(PremiumPressableButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var expiredInvitationState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("pairing.invitation.expired", systemImage: "clock.badge.exclamationmark")
                .font(.body.weight(.medium))
                .foregroundStyle(PremiumArrivalStyle.mutedInk)

            PremiumPrimaryButton("pairing.invitation.new", action: replaceInvitation)
        }
    }

    private var workingState: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading(
                title: "pairing.connecting.title",
                message: "pairing.connecting.message"
            )

            HStack(spacing: 14) {
                ProgressView()
                    .tint(PremiumArrivalStyle.pinkInk)

                Text("pairing.connecting")
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .accessibilityElement(children: .combine)
        }
    }

    private var connectedState: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading(
                title: "pairing.connected.title",
                message: "pairing.connected.message"
            )

            ZStack {
                Circle()
                    .stroke(PremiumArrivalStyle.blush.opacity(0.72), lineWidth: 12)
                    .frame(width: 94, height: 94)

                Circle()
                    .fill(PremiumArrivalStyle.blush)
                    .frame(width: 76, height: 76)

                Image(systemName: "heart.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(successIsVisible || reduceMotion ? 1 : 0.92)
            .opacity(successIsVisible ? 1 : 0)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pairing.connected")
    }

    private func pairingErrorView(_ error: AppError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(error.localizedResource)
                    .font(.caption)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .foregroundStyle(Color(red: 0.66, green: 0.25, blue: 0.34))

            if relationshipStore.deferredPairingState != .none {
                Button("pairing.retry") {
                    AvenHaptics.shared.light()
                    relationshipStore.retryDeferredPairing()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PremiumArrivalStyle.ink)
                .frame(minHeight: 44)
                .buttonStyle(PremiumPressableButtonStyle())
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func heading(
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) -> some View {
        switch presentation {
        case .onboarding:
            PremiumArrivalHeading(title: title, message: message)
        case .dashboard:
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(.largeTitle, design: .serif, weight: .regular))
                Text(message)
                    .font(.body)
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
            }
        }
    }

    private func pairingBackButton(action: @escaping () -> Void) -> some View {
        Button("action.back") {
            AvenHaptics.shared.soft()
            action()
        }
        .font(.body)
        .foregroundStyle(PremiumArrivalStyle.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(PremiumPressableButtonStyle())
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

    private func navigate(to destination: Screen, direction: PairingTransitionDirection) {
        transitionDirection = direction
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.32)) {
            screen = destination
        }
    }

    private func showInvite() {
        AvenHaptics.shared.selection()
        navigate(to: .invite, direction: .forward)
    }

    private func showJoin() {
        AvenHaptics.shared.selection()
        navigate(to: .join, direction: .forward)
    }

    private func showChoice() {
        navigate(to: .choice, direction: .backward)
    }

    private func showCodeEntry() {
        AvenHaptics.shared.selection()
        manualEntry = ""
        lastSubmittedCode = nil
        navigate(to: .codeEntry, direction: .forward)
    }

    private func createInvitation() {
        AvenHaptics.shared.light()
        relationshipStore.createInvitation(
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate
        )
    }

    private func replaceInvitation() {
        AvenHaptics.shared.light()
        relationshipStore.replaceInvitation(
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate
        )
    }

    private func openScanner() {
        AvenHaptics.shared.selection()
        showCodeAfterScanner = false
        showsScanner = true
    }

    private func requestCodeEntryFromScanner() {
        showCodeAfterScanner = true
    }

    private func scannerDidDismiss() {
        if showCodeAfterScanner {
            showCodeAfterScanner = false
            showCodeEntry()
        }
    }

    private func redeemLinkToken(_ token: String) {
        relationshipStore.redeemInvitation(credential: .linkToken(token))
    }

    private func manualCodeChanged(_ rawValue: String) {
        let normalized = String(
            PairingInvitation.normalizeManualCode(rawValue).prefix(6)
        )
        if manualEntry != normalized {
            manualEntry = normalized
        }
        guard normalized.count == 6 else {
            lastSubmittedCode = nil
            return
        }
        guard normalized != lastSubmittedCode else { return }
        lastSubmittedCode = normalized
        AvenHaptics.shared.selection()
        relationshipStore.redeemInvitation(credential: .manualCode(normalized))
    }

    private func copy(_ code: String) {
        UIPasteboard.general.string = code
        AvenHaptics.shared.light()
        showsCopiedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false else { return }
            showsCopiedConfirmation = false
        }
    }

    private func shareMessage(invitation: PairingInvitation, url: String) -> String {
        [
            String(localized: "pairing.share.message"),
            url,
            "\(String(localized: "pairing.share.code")): \(invitation.formattedManualCode)",
            String(localized: "pairing.share.expiry"),
        ].joined(separator: "\n")
    }

    private func celebrateConnectionIfNeeded() {
        let relationshipID = relationshipStore.relationship.id
        guard
            relationshipStore.isActive,
            celebratedRelationshipID != relationshipID
        else {
            return
        }
        celebratedRelationshipID = relationshipID
        AvenHaptics.shared.success()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.34)) {
            successIsVisible = true
        }
    }
}

private enum PairingTransitionDirection {
    case forward
    case backward
}

private struct PairingActionRow: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PremiumArrivalStyle.ink)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(PremiumArrivalStyle.mutedInk)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PremiumArrivalStyle.ink)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Color.white.opacity(0.76))
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PremiumArrivalStyle.divider, lineWidth: 1)
            }
        }
        .buttonStyle(PremiumPressableButtonStyle())
    }
}

private struct PairingManualCodeField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var code: String
    @FocusState.Binding var isFocused: Bool
    let hasError: Bool
    let onChanged: (String) -> Void

    var body: some View {
        TextField("pairing.code.placeholder", text: $code)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .foregroundStyle(.clear)
            .tint(.clear)
            .frame(height: 68)
            .overlay {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        codeSlot(at: index)
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: code) { _, value in
                onChanged(value)
            }
            .accessibilityLabel(Text("pairing.code.accessibility"))
            .accessibilityHint(Text("pairing.code.hint"))
            .accessibilityIdentifier("pairing.code.field")
    }

    private func codeSlot(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let isCurrent = isFocused && index == min(characters.count, 5)

        return Text(character)
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundStyle(PremiumArrivalStyle.ink)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                PremiumArrivalStyle.blush.opacity(character.isEmpty ? 0.18 : 0.42),
                in: .rect(cornerRadius: AvenRadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AvenRadius.control, style: .continuous)
                    .stroke(
                        hasError
                            ? Color.red.opacity(0.72)
                            : isCurrent
                                ? PremiumArrivalStyle.pinkInk
                                : PremiumArrivalStyle.divider,
                        lineWidth: isCurrent ? 2 : 1
                    )
            }
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.2),
                value: character
            )
    }
}
