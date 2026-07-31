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
            .background(
                Color.white.opacity(0.88),
                in: .rect(cornerRadius: AvenRadius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AvenRadius.card, style: .continuous)
                    .stroke(PremiumArrivalStyle.divider, lineWidth: 0.75)
            }
            .shadow(
                color: Color.black.opacity(interactive ? 0.07 : 0.035),
                radius: interactive ? 12 : 8,
                y: interactive ? 5 : 3
            )
    }
}
