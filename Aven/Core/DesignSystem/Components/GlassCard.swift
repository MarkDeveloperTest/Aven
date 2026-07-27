import SwiftUI

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AvenSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .avenGlassSurface()
    }
}

extension View {
    @ViewBuilder
    func avenGlassSurface(interactive: Bool = false) -> some View {
        self
            .background(Color.white.opacity(0.78), in: .rect(cornerRadius: AvenRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: AvenRadius.card, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(interactive ? 0.10 : 0.05),
                radius: interactive ? 18 : 12,
                y: interactive ? 8 : 4
            )
    }
}
