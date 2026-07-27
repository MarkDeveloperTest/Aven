import SwiftUI

struct AvenBackground: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let palette = settings.theme.palette
        LinearGradient(
            colors: reduceTransparency
                ? [palette.backgroundTop, palette.backgroundTop]
                : [palette.backgroundTop, palette.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.accent.opacity(reduceTransparency ? 0 : 0.08))
                .frame(height: 1)
                .padding(.horizontal, AvenSpacing.large)
                .accessibilityHidden(true)
        }
    }
}
