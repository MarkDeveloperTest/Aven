import Foundation
import OSLog

nonisolated enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.aven"

    static let authentication = Logger(subsystem: subsystem, category: "authentication")
    static let relationship = Logger(subsystem: subsystem, category: "relationship")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let privacy = Logger(subsystem: subsystem, category: "privacy")
    static let application = Logger(subsystem: subsystem, category: "application")

    static func redactedIdentifier(_ value: String) -> String {
        guard value.isEmpty == false else { return "empty" }
        return String(value.prefix(3)) + "…"
    }
}
