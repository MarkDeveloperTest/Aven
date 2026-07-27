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
        switch self {
        case .aven:
            AvenPalette(
                accent: Color(red: 0.61, green: 0.46, blue: 0.26),
                secondary: Color(red: 0.76, green: 0.68, blue: 0.54),
                backgroundTop: Color(red: 0.985, green: 0.98, blue: 0.96),
                backgroundBottom: Color(red: 0.93, green: 0.91, blue: 0.87),
                onBackground: Color(red: 0.12, green: 0.11, blue: 0.10),
                onBackgroundSecondary: Color(red: 0.38, green: 0.36, blue: 0.33)
            )
        case .rose:
            AvenPalette(
                accent: .pink,
                secondary: Color(red: 0.96, green: 0.56, blue: 0.68),
                backgroundTop: Color(red: 0.28, green: 0.07, blue: 0.14),
                backgroundBottom: Color(red: 0.71, green: 0.22, blue: 0.36),
                onBackground: .white,
                onBackgroundSecondary: .white.opacity(0.78)
            )
        case .sunset:
            AvenPalette(
                accent: .orange,
                secondary: .pink,
                backgroundTop: Color(red: 0.23, green: 0.08, blue: 0.22),
                backgroundBottom: Color(red: 0.90, green: 0.31, blue: 0.20),
                onBackground: .white,
                onBackgroundSecondary: .white.opacity(0.78)
            )
        case .ocean:
            AvenPalette(
                accent: .cyan,
                secondary: .blue,
                backgroundTop: Color(red: 0.02, green: 0.15, blue: 0.29),
                backgroundBottom: Color(red: 0.03, green: 0.49, blue: 0.59),
                onBackground: .white,
                onBackgroundSecondary: .white.opacity(0.78)
            )
        case .midnight:
            AvenPalette(
                accent: .indigo,
                secondary: .purple,
                backgroundTop: Color(red: 0.02, green: 0.03, blue: 0.09),
                backgroundBottom: Color(red: 0.11, green: 0.10, blue: 0.28),
                onBackground: .white,
                onBackgroundSecondary: .white.opacity(0.78)
            )
        case .minimal:
            AvenPalette(
                accent: Color(red: 0.61, green: 0.46, blue: 0.26),
                secondary: Color(red: 0.76, green: 0.68, blue: 0.54),
                backgroundTop: Color(red: 0.995, green: 0.99, blue: 0.98),
                backgroundBottom: Color(red: 0.95, green: 0.94, blue: 0.91),
                onBackground: Color(red: 0.12, green: 0.11, blue: 0.10),
                onBackgroundSecondary: Color(red: 0.38, green: 0.36, blue: 0.33)
            )
        }
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
    static let card: CGFloat = 20
    static let control: CGFloat = 12
}
