import SwiftUI

struct PrimaryActionButton: View {
    let title: LocalizedStringResource
    let systemImage: String?
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringResource,
        systemImage: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AvenSpacing.small) {
                if isLoading {
                    ProgressView()
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
        }
        .disabled(isLoading)
        .avenProminentButtonStyle()
    }
}

extension View {
    @ViewBuilder
    func avenProminentButtonStyle() -> some View {
        self
            .foregroundStyle(.white)
            .background(Color(red: 0.12, green: 0.11, blue: 0.10), in: .rect(cornerRadius: AvenRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AvenRadius.control, style: .continuous)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
}
