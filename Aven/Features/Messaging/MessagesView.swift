import SwiftUI

struct MessagesView: View {
    @Environment(AppSession.self) private var session
    @Environment(RelationshipStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var composerText = ""

    var body: some View {
        Group {
            if store.isActive {
                messageTimeline
            } else {
                EmptyStateView(
                    systemImage: "bubble.left.and.exclamationmark.bubble.right",
                    title: "messages.unpaired.title",
                    message: "messages.unpaired.message"
                )
            }
        }
        .navigationTitle(Text("tab.messages"))
        .background(AvenBackground())
        .safeAreaInset(edge: .bottom) {
            if store.isActive {
                composer
            }
        }
    }

    private var messageTimeline: some View {
        ScrollView {
            LazyVStack(spacing: AvenSpacing.small) {
                PrivacyBadge(title: "messages.not_e2ee")
                    .padding(.bottom, AvenSpacing.small)

                ForEach(store.messages) { message in
                    MessageBubble(
                        message: message,
                        isCurrentUser: message.senderID == session.user?.id,
                        accent: settings.theme.palette.accent
                    )
                }
            }
            .padding(AvenSpacing.medium)
        }
        .background(AvenBackground())
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: AvenSpacing.small) {
            TextField("messages.composer.placeholder", text: $composerText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("messages.composer")

            Button {
                guard let userID = session.user?.id else { return }
                store.sendMessage(composerText, senderID: userID)
                composerText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text("messages.send"))
            .accessibilityIdentifier("messages.send")
        }
        .padding(AvenSpacing.small)
        .background(Color.white.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PremiumArrivalStyle.divider)
                .frame(height: 0.75)
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let accent: Color

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 54)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(verbatim: message.text)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser
                            ? AnyShapeStyle(accent)
                            : AnyShapeStyle(Color.white.opacity(0.90)),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        if isCurrentUser == false {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PremiumArrivalStyle.divider, lineWidth: 0.75)
                        }
                    }

                Text(message.sentAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isCurrentUser == false {
                Spacer(minLength: 54)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(isCurrentUser ? "messages.sender.you" : "messages.sender.partner")
        )
        .accessibilityValue(Text(verbatim: message.text))
    }
}
