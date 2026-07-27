import SwiftUI
import WidgetKit

@main
struct AvenWidgets: WidgetBundle {
    var body: some Widget {
        AvenPrivacyWidget()
    }
}

struct AvenPrivacyWidget: Widget {
    let kind = AvenWidgetStateStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AvenPrivacyTimelineProvider()) { entry in
            AvenPrivacyWidgetView(entry: entry)
        }
        .configurationDisplayName("Aven")
        .description("A private glance at your shared space.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

struct AvenPrivacyEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: AvenWidgetSnapshot

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: 10, duration: 60 * 60)
    }
}

struct AvenPrivacyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AvenPrivacyEntry {
        AvenPrivacyEntry(date: .now, snapshot: .locked)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (AvenPrivacyEntry) -> Void
    ) {
        let snapshot = context.isPreview ? AvenWidgetSnapshot.locked : AvenWidgetStateStore.load()
        completion(AvenPrivacyEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<AvenPrivacyEntry>) -> Void
    ) {
        let entry = AvenPrivacyEntry(date: .now, snapshot: AvenWidgetStateStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct AvenPrivacyWidgetView: View {
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: AvenPrivacyEntry

    private var canShowSensitiveContent: Bool {
        !redactionReasons.contains(.privacy) && !isAccessoryFamily
    }

    private var isAccessoryFamily: Bool {
        switch family {
        case .accessoryInline, .accessoryRectangular, .accessoryCircular:
            true
        default:
            false
        }
    }

    var body: some View {
        Group {
            if isAccessoryFamily {
                accessoryContent
            } else {
                homeScreenContent
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.26),
                    Color(red: 0.35, green: 0.18, blue: 0.36),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .privacySensitive()
    }

    @ViewBuilder
    private var homeScreenContent: some View {
        let presentation = entry.snapshot.presentation(
            allowsSensitiveContent: canShowSensitiveContent
        )

        VStack(alignment: .leading, spacing: 10) {
            Label("Aven", systemImage: "heart.fill")
                .font(.headline)
                .widgetAccentable()

            Spacer(minLength: 0)

            switch presentation {
            case .private:
                protectedContent
            case .unpaired:
                Text("Your shared space is ready when you are.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            case let .shared(partnerDisplayName, daysTogether):
                sharedContent(
                    partnerDisplayName: partnerDisplayName,
                    daysTogether: daysTogether
                )
            }

            Spacer(minLength: 0)

            HStack {
                Button(intent: OpenAvenIntent()) {
                    Label("Open", systemImage: "arrow.up.right")
                }

                Spacer()

                if presentation != .private {
                    Button(intent: ProtectAvenWidgetIntent()) {
                        Image(systemName: "lock.fill")
                    }
                    .accessibilityLabel("Protect Aven widget")
                }
            }
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundStyle)
    }

    private var protectedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Private by design")
                .font(.title3.weight(.semibold))
                .unredacted()
            Text("Open Aven to view relationship details.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .unredacted()
        }
    }

    private func sharedContent(
        partnerDisplayName: String?,
        daysTogether: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let partnerDisplayName {
                Text(partnerDisplayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
            }

            if let daysTogether {
                Text("\(daysTogether) days together")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your shared space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var accessoryContent: some View {
        switch family {
        case .accessoryInline:
            Label("Aven is private", systemImage: "heart.fill")
                .unredacted()
        default:
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aven")
                        .font(.headline)
                    Text("Private by design")
                        .font(.caption)
                }
            }
            .unredacted()
        }
    }

    private var foregroundStyle: Color {
        renderingMode == .fullColor ? .white : .primary
    }
}
