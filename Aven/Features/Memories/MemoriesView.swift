import PhotosUI
import SwiftUI
import UIKit

struct MemoriesView: View {
    @Environment(AppSession.self) private var session
    @Environment(RelationshipStore.self) private var store
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var caption = ""
    @State private var isImporting = false

    private let columns = [
        GridItem(.flexible(), spacing: AvenSpacing.small),
        GridItem(.flexible(), spacing: AvenSpacing.small)
    ]

    var body: some View {
        Group {
            if store.isActive {
                memoryTimeline
            } else {
                EmptyStateView(
                    systemImage: "photo.badge.exclamationmark",
                    title: "memories.unpaired.title",
                    message: "memories.unpaired.message"
                )
            }
        }
        .navigationTitle(Text("tab.memories"))
        .toolbar {
            if store.isActive {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("memories.add", systemImage: "plus")
                    }
                    .accessibilityIdentifier("memories.add")
                }
            }
        }
        .task(id: selectedPhoto) {
            await importSelectedPhoto()
        }
    }

    private var memoryTimeline: some View {
        ScrollView {
            VStack(spacing: AvenSpacing.medium) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AvenSpacing.small) {
                        TextField("memories.caption.placeholder", text: $caption)
                            .textFieldStyle(.roundedBorder)
                        Text("memories.photo_consent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, AvenSpacing.medium)

                if isImporting {
                    ProgressView("memories.importing")
                        .padding()
                }

                if store.memories.isEmpty {
                    EmptyStateView(
                        systemImage: "photo.stack",
                        title: "memories.empty.title",
                        message: "memories.empty.message"
                    )
                    .frame(minHeight: 360)
                } else {
                    LazyVGrid(columns: columns, spacing: AvenSpacing.small) {
                        ForEach(store.memories) { memory in
                            MemoryTile(memory: memory)
                        }
                    }
                    .padding(.horizontal, AvenSpacing.medium)
                }
            }
            .padding(.vertical, AvenSpacing.medium)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func importSelectedPhoto() async {
        guard
            let selectedPhoto,
            let creatorID = session.user?.id
        else { return }

        isImporting = true
        defer {
            isImporting = false
            self.selectedPhoto = nil
        }
        do {
            let sourceData = try await selectedPhoto.loadTransferable(type: Data.self)
            let data = try await Task.detached(priority: .userInitiated) {
                try PhotoImportProcessor.makeUploadThumbnail(from: sourceData)
            }.value
            store.addMemory(
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                imageData: data,
                creatorID: creatorID
            )
            caption = ""
        } catch {
            AppLogger.privacy.error("Selected photo import failed")
            session.present(.unknown)
        }
    }
}

private struct MemoryTile: View {
    let memory: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: AvenSpacing.small) {
            Group {
                if
                    let imageData = memory.imageData,
                    let image = UIImage(data: imageData)
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
            .clipped()
            .background(Color(uiColor: .secondarySystemBackground))

            if memory.caption.isEmpty == false {
                Text(verbatim: memory.caption)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .padding(.horizontal, AvenSpacing.small)
            }

            Text(memory.createdAt, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], AvenSpacing.small)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: AvenRadius.control))
        .clipShape(RoundedRectangle(cornerRadius: AvenRadius.control))
        .accessibilityElement(children: .combine)
    }
}
