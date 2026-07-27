import Foundation

nonisolated enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case messages
    case memories
    case sharedDay
    case us

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .home: "tab.home"
        case .messages: "tab.messages"
        case .memories: "tab.memories"
        case .sharedDay: "tab.shared_day"
        case .us: "tab.us"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "heart.fill"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .memories: "photo.on.rectangle.angled"
        case .sharedDay: "sun.max.fill"
        case .us: "person.2.fill"
        }
    }
}
