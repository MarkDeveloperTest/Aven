import CoreHaptics
import UIKit

@MainActor
final class AvenHaptics {
    static let shared = AvenHaptics()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var heartEngine: CHHapticEngine?
    private var heartPlayer: CHHapticAdvancedPatternPlayer?
    private var standbyEngine: CHHapticEngine?
    private var standbyPlayer: CHHapticAdvancedPatternPlayer?

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

    func playContinuousHeartFormation(duration: TimeInterval) {
        stopContinuousHeartFormation()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            soft()
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: 0.18
                    ),
                    CHHapticEventParameter(
                        parameterID: .hapticSharpness,
                        value: 0.1
                    ),
                ],
                relativeTime: 0,
                duration: duration
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            heartEngine = engine
            heartPlayer = player
        } catch {
            soft()
        }
    }

    func stopContinuousHeartFormation() {
        try? heartPlayer?.stop(atTime: CHHapticTimeImmediate)
        heartPlayer = nil
        heartEngine = nil
    }

    func playContinuousStandbyAnimation(period: TimeInterval) {
        stopContinuousStandbyAnimation()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: 0.06
                    ),
                    CHHapticEventParameter(
                        parameterID: .hapticSharpness,
                        value: 0
                    ),
                ],
                relativeTime: 0,
                duration: period
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = period
            try player.start(atTime: CHHapticTimeImmediate)
            standbyEngine = engine
            standbyPlayer = player
        } catch {
            return
        }
    }

    func stopContinuousStandbyAnimation() {
        try? standbyPlayer?.stop(atTime: CHHapticTimeImmediate)
        standbyPlayer = nil
        standbyEngine = nil
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
