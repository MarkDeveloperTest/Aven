import SwiftUI

nonisolated enum AvenTheme: String, CaseIterable, Identifiable, Sendable {
    case aven
    case rose
    case sunset
    case ocean
    case midnight
    case minimal

    var id: String { rawValue }

    var localizedResource: LocalizedStringResource {
        switch self {
        case .aven: "theme.aven"
        case .rose: "theme.rose"
        case .sunset: "theme.sunset"
        case .ocean: "theme.ocean"
        case .midnight: "theme.midnight"
        case .minimal: "theme.minimal"
        }
    }

    var palette: AvenPalette {
        AvenPalette(
            accent: PremiumArrivalStyle.pinkInk,
            secondary: PremiumArrivalStyle.blush,
            backgroundTop: .white,
            backgroundBottom: PremiumArrivalStyle.blush.opacity(0.52),
            onBackground: PremiumArrivalStyle.ink,
            onBackgroundSecondary: PremiumArrivalStyle.mutedInk
        )
    }
}

nonisolated struct AvenPalette: Sendable {
    let accent: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let onBackground: Color
    let onBackgroundSecondary: Color
}

nonisolated enum AvenSpacing {
    static let xSmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

nonisolated enum AvenRadius {
    static let card: CGFloat = 14
    static let control: CGFloat = 10
}
