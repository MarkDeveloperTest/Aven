import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(RelationshipStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            AvenBackground()

            ScrollView {
                LazyVStack(spacing: AvenSpacing.medium) {
                    header

                    if store.isActive {
                        activeDashboard
                    } else {
                        pairingDashboard
                    }
                }
                .padding(AvenSpacing.medium)
            }
        }
        .navigationTitle(Text("tab.home"))
        .toolbarBackground(.hidden, for: .navigationBar)
        .foregroundStyle(settings.theme.palette.onBackground)
    }

    private var header: some View {
        HStack(spacing: AvenSpacing.medium) {
            ZStack {
                Circle()
                    .fill(settings.theme.palette.accent)
                Text(initials)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .accessibilityLabel(Text("profile.avatar.accessibility"))

            VStack(alignment: .leading, spacing: 2) {
                Text("home.greeting")
                    .font(.subheadline)
                    .foregroundStyle(settings.theme.palette.onBackgroundSecondary)
                Text(verbatim: session.profile?.displayName ?? session.user?.displayName ?? "")
                    .font(.title2.bold())
            }

            Spacer()

            PrivacyBadge(title: "privacy.shared_with_partner")
        }
    }

    @ViewBuilder
    private var activeDashboard: some View {
        partnerCard
        metricsCard
        recentMessageCard
        if settings.aiEnabled {
            insightCard
        }
    }

    private var partnerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AvenSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("home.partner.title")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let partnerName = store.relationship.partnerName {
                            Text(verbatim: partnerName)
                                .font(.title.bold())
                        } else {
                            Text("home.partner.fallback")
                                .font(.title.bold())
                        }
                    }
                    Spacer()
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(settings.theme.palette.accent)
                }

                if let startDate = store.relationship.startDate {
                    Label {
                        Text(startDate, format: .dateTime.year().month().day())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                }

                Text("home.partner.consent_note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var metricsCard: some View {
        GlassCard {
            HStack(spacing: AvenSpacing.medium) {
                metric(
                    value: messagesCount,
                    title: "home.metric.messages",
                    systemImage: "bubble.left.fill"
                )
                Divider()
                metric(
                    value: memoriesCount,
                    title: "home.metric.memories",
                    systemImage: "photo.fill"
                )
                Divider()
                metric(
                    value: sharedDayCount,
                    title: "home.metric.moments",
                    systemImage: "sun.max.fill"
                )
            }
        }
        .foregroundStyle(.primary)
    }

    private var recentMessageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AvenSpacing.small) {
                Label("home.recent_message.title", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.headline)
                if let message = store.messages.last {
                    Text(verbatim: message.text)
                        .lineLimit(2)
                    Text(message.sentAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("home.recent_message.empty")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var insightCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AvenSpacing.small) {
                Label("home.insight.title", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(settings.theme.palette.accent)
                Text("home.insight.detail")
                Text("home.insight.disclaimer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var pairingDashboard: some View {
        GlassCard {
            CouplePairingView(
                presentation: .dashboard,
                relationshipType: session.profile?.relationshipType ?? .unspecified,
                relationshipStartDate: session.profile?.relationshipStartDate
            )
        }
        .foregroundStyle(.primary)
    }

    private func metric(
        value: String,
        title: LocalizedStringResource,
        systemImage: String
    ) -> some View {
        VStack(spacing: AvenSpacing.xSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(settings.theme.palette.accent)
            Text(verbatim: value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        let name = session.profile?.displayName ?? session.user?.displayName ?? ""
        return name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var messagesCount: String { store.messages.count.formatted() }
    private var memoriesCount: String { store.memories.count.formatted() }
    private var sharedDayCount: String { store.sharedDayEvents.count.formatted() }
}
