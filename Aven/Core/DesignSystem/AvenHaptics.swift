import UIKit

@MainActor
final class AvenHaptics {
    static let shared = AvenHaptics()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    func prepare() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        softGenerator.prepare()
        mediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func light() {
        lightGenerator.impactOccurred(intensity: 0.72)
        lightGenerator.prepare()
    }

    func soft() {
        softGenerator.impactOccurred(intensity: 0.62)
        softGenerator.prepare()
    }

    func medium() {
        mediumGenerator.impactOccurred(intensity: 0.78)
        mediumGenerator.prepare()
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
}
