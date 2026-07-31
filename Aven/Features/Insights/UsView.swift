import SwiftUI

struct UsView: View {
    @Environment(RelationshipStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            if store.isActive {
                Section {
                    if settings.aiEnabled {
                        insightCard
                    }
                    participationCard
                } header: {
                    Text("us.insights.section")
                } footer: {
                    Text("us.insights.disclaimer")
                }

                if settings.aiEnabled && settings.relationshipScoreEnabled {
                    Section("us.score.section") {
                        VStack(alignment: .leading, spacing: AvenSpacing.small) {
                            Text("us.score.experimental")
                                .font(.headline)
                            ProgressView(value: engagementSummary)
                            Text("us.score.explanation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, AvenSpacing.small)
                    }
                }
            } else {
                Section {
                    EmptyStateView(
                        systemImage: "person.2.slash",
                        title: "us.unpaired.title",
                        message: "us.unpaired.message"
                    )
                }
            }

            Section("us.relationship.section") {
                LabeledContent("us.relationship.status") {
                    Text(relationshipStatusResource)
                }

                if let partnerName = store.relationship.partnerName {
                    LabeledContent("us.relationship.partner") {
                        Text(verbatim: partnerName)
                    }
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("settings.title", systemImage: "gearshape.fill")
                }
            }
        }
        .navigationTitle(Text("tab.us"))
        .scrollContentBackground(.hidden)
        .background(AvenBackground())
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: AvenSpacing.small) {
            Label("us.insight.title", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(settings.theme.palette.accent)
            Text("us.insight.detail")
            Text("us.insight.source")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AvenSpacing.small)
    }

    private var participationCard: some View {
        HStack {
            metric(store.messages.count, title: "us.metric.messages")
            Divider()
            metric(store.memories.count, title: "us.metric.memories")
            Divider()
            metric(store.sharedDayEvents.count, title: "us.metric.moments")
        }
        .padding(.vertical, AvenSpacing.small)
    }

    private func metric(_ value: Int, title: LocalizedStringResource) -> some View {
        VStack {
            Text(verbatim: value.formatted())
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var engagementSummary: Double {
        let activity = store.messages.count + store.memories.count + store.sharedDayEvents.count
        return min(Double(activity) / 20, 1)
    }

    private var relationshipStatusResource: LocalizedStringResource {
        switch store.relationship.status {
        case .unpaired: "relationship.status.unpaired"
        case .invitationPending: "relationship.status.invitation_pending"
        case .active: "relationship.status.active"
        case .paused: "relationship.status.paused"
        case .endingRequested: "relationship.status.ending_requested"
        case .ended: "relationship.status.ended"
        case .archived: "relationship.status.archived"
        case .deletionPending: "relationship.status.deletion_pending"
        }
    }
}
