import AppIntents
import WidgetKit

struct OpenAvenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Aven"
    static let description = IntentDescription(
        "Opens your private Aven space."
    )
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ProtectAvenWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Protect Aven Widget"
    static let description = IntentDescription(
        "Immediately removes relationship details from the Aven widget."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try AvenWidgetStateStore.lock()
        WidgetCenter.shared.reloadTimelines(ofKind: AvenWidgetStateStore.widgetKind)
        return .result(dialog: "Aven’s widget is now private.")
    }
}

#if AVEN_APP_TARGET
struct AvenAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAvenIntent(),
            phrases: [
                "Open \(.applicationName)",
            ],
            shortTitle: "Open Aven",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: ProtectAvenWidgetIntent(),
            phrases: [
                "Protect my \(.applicationName) widget",
            ],
            shortTitle: "Protect Widget",
            systemImageName: "lock.fill"
        )
    }
}
#endif
