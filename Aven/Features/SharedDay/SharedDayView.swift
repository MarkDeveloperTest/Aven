import SwiftUI

struct SharedDayView: View {
    private enum SheetDestination: String, Identifiable {
        case addEvent
        var id: String { rawValue }
    }

    @Environment(AppSession.self) private var session
    @Environment(RelationshipStore.self) private var store
    @State private var sheet: SheetDestination?

    var body: some View {
        Group {
            if store.isActive {
                timeline
            } else {
                EmptyStateView(
                    systemImage: "sun.max.trianglebadge.exclamationmark",
                    title: "shared_day.unpaired.title",
                    message: "shared_day.unpaired.message"
                )
            }
        }
        .navigationTitle(Text("tab.shared_day"))
        .background(AvenBackground())
        .toolbar {
            if store.isActive {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .addEvent
                    } label: {
                        Label("shared_day.add", systemImage: "plus")
                    }
                    .accessibilityIdentifier("shared_day.add")
                }
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .addEvent:
                AddSharedDayEventView { title, category in
                    guard let creatorID = session.user?.id else { return }
                    store.addSharedDayEvent(
                        title: title,
                        category: category,
                        creatorID: creatorID
                    )
                }
            }
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AvenSpacing.small) {
                        Label("shared_day.today", systemImage: "calendar")
                            .font(.headline)
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.title2.bold())
                        Text("shared_day.privacy_note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, AvenSpacing.large)

                if store.sharedDayEvents.isEmpty {
                    EmptyStateView(
                        systemImage: "sun.horizon",
                        title: "shared_day.empty.title",
                        message: "shared_day.empty.message"
                    )
                    .frame(minHeight: 340)
                } else {
                    ForEach(store.sharedDayEvents) { event in
                        TimelineEventRow(event: event)
                    }
                }
            }
            .padding(AvenSpacing.medium)
        }
        .background(AvenBackground())
    }
}

private struct TimelineEventRow: View {
    let event: SharedDayEvent

    var body: some View {
        HStack(alignment: .top, spacing: AvenSpacing.medium) {
            VStack(spacing: 0) {
                Circle()
                    .fill(.tint)
                    .frame(width: 14, height: 14)
                Rectangle()
                    .fill(.tint.opacity(0.24))
                    .frame(width: 2, height: 72)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(event.category.localizedResource)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(event.occurredAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(verbatim: event.title)
                    .font(.body.weight(.medium))

                PrivacyBadge(title: "privacy.shared_with_partner")
            }
            .padding(.bottom, AvenSpacing.medium)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AddSharedDayEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: SharedDayEvent.Category = .note

    let onSave: (String, SharedDayEvent.Category) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("shared_day.add.details") {
                    TextField("shared_day.add.placeholder", text: $title, axis: .vertical)
                    Picker("shared_day.add.category", selection: $category) {
                        ForEach(SharedDayEvent.Category.allCases) { category in
                            Text(category.localizedResource).tag(category)
                        }
                    }
                }

                Section {
                    Text("shared_day.add.consent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text("shared_day.add.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        onSave(title, category)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
