import SwiftUI
import UIKit

struct CouplePairingView: View {
    enum Presentation {
        case onboarding
        case dashboard

        var qrSize: CGFloat {
            switch self {
            case .onboarding: 176
            case .dashboard: 224
            }
        }
    }

    @Environment(RelationshipStore.self) private var relationshipStore
    @AccessibilityFocusState private var isScanButtonFocused: Bool
    @State private var showsScanner = false
    @State private var showsCopiedConfirmation = false

    let presentation: Presentation
    let relationshipType: RelationshipType
    let relationshipStartDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading

            Group {
                if relationshipStore.isActive {
                    connectedState
                } else if let invitation = relationshipStore.invitation,
                          relationshipStore.relationship.status == .invitationPending {
                    invitationState(invitation)
                } else if relationshipStore.isPairing {
                    workingState
                } else {
                    switch relationshipStore.deferredPairingState {
                    case .none:
                        unpairedActions
                    case .createInvitation:
                        deferredCreateState
                    case .redeemInvitation:
                        deferredRedeemState
                    }
                }
            }

            if let pairingError = relationshipStore.pairingError {
                pairingErrorView(pairingError)
            }
        }
        .fullScreenCover(isPresented: $showsScanner, onDismiss: scannerDidDismiss) {
            PairingQRScannerView(environment: .current) { invitationCode in
                relationshipStore.redeemInvitation(code: invitationCode)
            }
        }
    }

    @ViewBuilder
    private var heading: some View {
        switch presentation {
        case .onboarding:
            PremiumArrivalHeading(
                title: "pairing.title",
                message: "pairing.message"
            )
        case .dashboard:
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
                    .accessibilityHidden(true)

                Text("pairing.title")
                    .font(.title.bold())

                Text("pairing.message")
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
            }
        }
    }

    private var unpairedActions: some View {
        VStack(spacing: 12) {
            PairingActionRow(
                title: "pairing.create",
                systemImage: "qrcode",
                isProminent: true,
                action: createInvitation
            )
            .accessibilityIdentifier("pairing.create")

            PairingActionRow(
                title: "pairing.scan.action",
                systemImage: "viewfinder",
                isProminent: false,
                action: openScanner
            )
            .accessibilityFocused($isScanButtonFocused)
            .accessibilityIdentifier("pairing.scan")
        }
    }

    private func invitationState(_ invitation: PairingInvitation) -> some View {
        VStack(spacing: 14) {
            if let payload = PairingQRCodePayload.makePayload(
                invitationCode: invitation.code,
                environment: .current
            ) {
                PairingQRCodeView(payload: payload, size: presentation.qrSize)
                    .padding(10)
                    .background(
                        PremiumArrivalStyle.blush.opacity(0.38),
                        in: .rect(cornerRadius: 20, style: .continuous)
                    )

                Text("pairing.qr.instructions")
                    .font(.subheadline)
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Text("pairing.qr.expires.label")
                    Text(
                        invitation.expiresAt,
                        format: .relative(presentation: .named)
                    )
                }
                .font(.caption)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)

                HStack(spacing: 10) {
                    Button {
                        copy(invitation.code)
                    } label: {
                        if showsCopiedConfirmation {
                            Label("pairing.copy.confirmation", systemImage: "checkmark")
                        } else {
                            Label("pairing.copy", systemImage: "doc.on.doc")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(PremiumArrivalStyle.ink)
                    .frame(minHeight: 44)

                    Button("pairing.revoke", role: .destructive) {
                        relationshipStore.revokeInvitation()
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("pairing.revoke")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var workingState: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(PremiumArrivalStyle.pinkInk)

            Text("pairing.connecting")
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .accessibilityElement(children: .combine)
    }

    private var deferredCreateState: some View {
        deferredState(
            systemImage: "qrcode",
            title: "pairing.deferred.create.title",
            message: "pairing.deferred.create.message"
        )
    }

    private var deferredRedeemState: some View {
        deferredState(
            systemImage: "checkmark.viewfinder",
            title: "pairing.deferred.redeem.title",
            message: "pairing.deferred.redeem.message"
        )
    }

    private var connectedState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PremiumArrivalStyle.blush)
                    .frame(width: 76, height: 76)

                Image(systemName: "heart.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
            }
            .accessibilityHidden(true)

            Text("pairing.connected.title")
                .font(.title3.weight(.semibold))

            Text("pairing.connected.message")
                .font(.subheadline)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pairing.connected")
    }

    private func deferredState(
        systemImage: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(PremiumArrivalStyle.pinkInk)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .multilineTextAlignment(.center)

            Button("pairing.deferred.cancel") {
                relationshipStore.clearDeferredPairing()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PremiumArrivalStyle.ink)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
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
                    relationshipStore.retryDeferredPairing()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PremiumArrivalStyle.ink)
                .frame(minHeight: 44)
            }
        }
    }

    private func createInvitation() {
        relationshipStore.createInvitation(
            relationshipType: relationshipType,
            relationshipStartDate: relationshipStartDate
        )
    }

    private func openScanner() {
        showsScanner = true
    }

    private func scannerDidDismiss() {
        isScanButtonFocused = true
    }

    private func copy(_ payload: String) {
        UIPasteboard.general.string = payload
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showsCopiedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false else { return }
            showsCopiedConfirmation = false
        }
    }
}

private struct PairingActionRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.body.weight(.semibold))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isProminent ? Color.white : PremiumArrivalStyle.ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isProminent {
                    PremiumArrivalStyle.ink
                } else {
                    Color.white
                }
            }
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .overlay {
                if isProminent == false {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PremiumArrivalStyle.divider, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
