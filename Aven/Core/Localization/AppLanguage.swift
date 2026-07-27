import Foundation

nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case ukrainian = "uk"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    static func inferred(from locale: Locale = .current) -> AppLanguage {
        inferred(fromRegionCode: locale.region?.identifier)
    }

    static func inferred(fromRegionCode regionCode: String?) -> AppLanguage {
        regionCode?.uppercased() == "UA" ? .ukrainian : .english
    }

    var titleResource: LocalizedStringResource {
        switch self {
        case .english: "language.english"
        case .ukrainian: "language.ukrainian"
        }
    }
}
