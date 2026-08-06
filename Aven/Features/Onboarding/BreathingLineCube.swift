import SwiftUI

nonisolated enum LineCubeMotion {
    private enum IdleMotion: CaseIterable {
        case orbit
        case sweep
        case ripple
    }

    private struct HeartCell: Hashable {
        let row: Int
        let column: Int
    }

    struct HeartPulse: Equatable {
        let emphasis: Double

        static let idle = Self(emphasis: 0)
    }

    static let gridSize = 10
    static let gridRowCount = 11
    static let period: TimeInterval = 6
    static let idleLoopDuration: TimeInterval = period * 3
    static let heartFormationDuration: TimeInterval = 0.8
    static let heartHoldDuration: TimeInterval = 1
    private static let heartTargets: [HeartCell: Double] = [
        // Compact upper lobes, inner notch, and a clean taper matching the
        // welcome-screen reference. The unused grid remains horizontal.
        HeartCell(row: 2, column: 2): 0,
        HeartCell(row: 2, column: 3): 0,
        HeartCell(row: 2, column: 6): 0,
        HeartCell(row: 2, column: 7): 0,
        HeartCell(row: 3, column: 1): 135,
        HeartCell(row: 3, column: 4): 45,
        HeartCell(row: 3, column: 5): 135,
        HeartCell(row: 3, column: 8): 45,
        HeartCell(row: 4, column: 1): 90,
        HeartCell(row: 4, column: 8): 90,
        // The marked bridge row starts the lower taper without a visual gap.
        HeartCell(row: 5, column: 1): 45,
        HeartCell(row: 5, column: 8): 135,
        // The sides sweep inward in one even diagonal run to a soft point.
        HeartCell(row: 6, column: 2): 45,
        HeartCell(row: 6, column: 7): 135,
        HeartCell(row: 7, column: 3): 45,
        HeartCell(row: 7, column: 6): 135,
        HeartCell(row: 8, column: 4): 45,
        HeartCell(row: 8, column: 5): 135,
    ]

    static func rotationDegrees(
        row: Int,
        column: Int,
        elapsed: TimeInterval
    ) -> Double {
        let progress = cycleProgress(
            row: row,
            column: column,
            elapsed: elapsed
        )
        let easedProgress = 0.5 - (0.5 * cos(.pi * progress))
        return easedProgress * 360
    }

    static func cycleProgress(
        row: Int,
        column: Int,
        elapsed: TimeInterval
    ) -> Double {
        let rawProgress = (elapsed / period)
            + idlePhaseOffset(row: row, column: column, elapsed: elapsed)
        return rawProgress - floor(rawProgress)
    }

    static func idleModeIndex(elapsed: TimeInterval) -> Int {
        Int(floor(elapsed / period)).quotientAndRemainder(
            dividingBy: IdleMotion.allCases.count
        ).remainder
    }

    static func idlePhaseOffset(
        row: Int,
        column: Int,
        elapsed: TimeInterval
    ) -> Double {
        let modeIndex = idleModeIndex(elapsed: elapsed)
        let currentMode = IdleMotion.allCases[modeIndex]
        let nextMode = IdleMotion.allCases[
            (modeIndex + 1) % IdleMotion.allCases.count
        ]
        let cycleProgress = (elapsed / period).truncatingRemainder(dividingBy: 1)
        let transition = smoothProgress((cycleProgress - 0.70) / 0.30)
        let current = phaseOffset(for: currentMode, row: row, column: column)
        let next = phaseOffset(for: nextMode, row: row, column: column)
        return current + (next - current) * transition
    }

    static func heartRotationDegrees(row: Int, column: Int) -> Double {
        heartLine(row: row, column: column).rotation
    }

    static func heartFormationProgress(elapsed: TimeInterval) -> CGFloat {
        CGFloat(smoothProgress(elapsed / heartFormationDuration))
    }

    static func heartTintProgress(formationProgress: CGFloat) -> Double {
        Double(min(max(formationProgress, 0), 1))
    }

    static func heartGlow(elapsed: TimeInterval?) -> HeartPulse {
        guard let elapsed, elapsed >= heartFormationDuration else { return .idle }
        return HeartPulse(emphasis: 0.45)
    }

    static func heartLine(
        row: Int,
        column: Int
    ) -> (rotation: Double, prominence: Double) {
        let target = heartTargets[HeartCell(row: row, column: column)]
        return (rotation: target ?? 0, prominence: target == nil ? 0 : 1)
    }

    static func forwardInterpolatedRotationDegrees(
        from start: Double,
        to end: Double,
        progress: CGFloat
    ) -> Double {
        let normalizedStart = start.truncatingRemainder(dividingBy: 360)
        let normalizedEnd = end.truncatingRemainder(dividingBy: 360)
        let forwardDelta = (normalizedEnd - normalizedStart + 360)
            .truncatingRemainder(dividingBy: 360)
        let travel = forwardDelta == 0 ? 360 : forwardDelta
        return start + travel * Double(progress)
    }

    private static func phaseOffset(
        for motion: IdleMotion,
        row: Int,
        column: Int
    ) -> Double {
        let rowCenter = Double(gridRowCount - 1) / 2
        let columnCenter = Double(gridSize - 1) / 2
        let rowDistance = Double(row) - rowCenter
        let columnDistance = Double(column) - columnCenter
        let maximumDistance = hypot(rowCenter, columnCenter)
        let radius = hypot(rowDistance, columnDistance) / maximumDistance
        let angle = (atan2(rowDistance, columnDistance) + .pi) / (2 * .pi)
        let diagonal = (
            Double(row) / Double(gridRowCount - 1)
                + Double(column) / Double(gridSize - 1)
        ) / 2
        let individualOffset = individualOffset(row: row, column: column)

        switch motion {
        case .orbit:
            return radius * 0.13 + angle * 0.11 + individualOffset
        case .sweep:
            return diagonal * 0.28 + individualOffset * 0.65
        case .ripple:
            let rings = (sin(radius * .pi * 3) + 1) * 0.10
            return rings + angle * 0.07 + individualOffset * 0.75
        }
    }

    private static func individualOffset(row: Int, column: Int) -> Double {
        let lineIndex = (row * gridSize) + column
        return Double((lineIndex * 7) % 13) / 13 * 0.035
    }

    private static func smoothProgress(_ value: Double) -> Double {
        let normalized = min(max(value, 0), 1)
        // Quintic smootherstep settles with no visible acceleration at either end.
        return normalized * normalized * normalized
            * (normalized * (normalized * 6 - 15) + 10)
    }

}

struct BreathingLineCube: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationStart = Date.now
    let heartFormationStart: Date?

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 120.0,
                paused: reduceMotion || scenePhase != .active
            )
        ) { timeline in
            let heartElapsed = heartElapsed(at: timeline.date)
            Canvas { context, size in
                drawLines(
                    in: context,
                    size: size,
                    elapsed: reduceMotion
                        ? 0
                        : timeline.date.timeIntervalSince(animationStart),
                    heartProgress: heartProgress(elapsed: heartElapsed),
                    heartGlow: LineCubeMotion.heartGlow(elapsed: heartElapsed)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 288)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("onboarding.welcome.cube")
        .accessibilityHidden(true)
        .onAppear(perform: updateStandbyHaptics)
        .onDisappear {
            AvenHaptics.shared.stopContinuousStandbyAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateStandbyHaptics()
        }
        .onChange(of: scenePhase) { _, _ in
            updateStandbyHaptics()
        }
        .onChange(of: heartFormationStart) { _, _ in
            updateStandbyHaptics()
        }
    }

    private func updateStandbyHaptics() {
        guard
            reduceMotion == false,
            scenePhase == .active,
            heartFormationStart == nil
        else {
            AvenHaptics.shared.stopContinuousStandbyAnimation()
            return
        }

        AvenHaptics.shared.playContinuousStandbyAnimation(
            period: LineCubeMotion.period
        )
    }

    private func heartElapsed(at date: Date) -> TimeInterval? {
        guard let heartFormationStart else { return nil }
        return max(0, date.timeIntervalSince(heartFormationStart))
    }

    private func heartProgress(elapsed: TimeInterval?) -> CGFloat {
        guard let elapsed else { return 0 }
        guard reduceMotion == false else { return 1 }
        return LineCubeMotion.heartFormationProgress(elapsed: elapsed)
    }

    private func drawLines(
        in context: GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        heartProgress: CGFloat,
        heartGlow: LineCubeMotion.HeartPulse
    ) {
        let side = min(size.width, size.height)
        let cellSize = side / CGFloat(LineCubeMotion.gridRowCount)
        let gridWidth = cellSize * CGFloat(LineCubeMotion.gridSize)
        let gridHeight = cellSize * CGFloat(LineCubeMotion.gridRowCount)
        let lineLength = cellSize * 0.60
        let lineWidth = max(1.6, cellSize * 0.06)
        let origin = CGPoint(
            x: (size.width - gridWidth) / 2,
            y: (size.height - gridHeight) / 2
        )
        let formationProgress = min(max(heartProgress, 0), 1)

        for row in 0..<LineCubeMotion.gridRowCount {
            for column in 0..<LineCubeMotion.gridSize {
                let gridCenter = CGPoint(
                    x: origin.x + (CGFloat(column) + 0.5) * cellSize,
                    y: origin.y + (CGFloat(row) + 0.5) * cellSize
                )
                let gridRotation = LineCubeMotion.rotationDegrees(
                    row: row,
                    column: column,
                    elapsed: elapsed
                )
                let heartLine = formationProgress == 0
                    ? (rotation: 0.0, prominence: 0.0)
                    : LineCubeMotion.heartLine(row: row, column: column)
                let rotation = formationProgress == 0
                    ? gridRotation
                    : LineCubeMotion.forwardInterpolatedRotationDegrees(
                        from: gridRotation,
                        to: heartLine.rotation,
                        progress: formationProgress
                    )
                let finalOpacity = heartLine.prominence == 1
                    ? 0.78 + heartGlow.emphasis * 0.22
                    : 0.12
                let opacity = 0.86 + (finalOpacity - 0.86) * formationProgress
                let heartTint = heartLine.prominence
                    * LineCubeMotion.heartTintProgress(
                        formationProgress: formationProgress
                    )
                let inkOpacity = opacity * (1 - heartTint)
                let pinkOpacity = heartTint * (0.78 + heartGlow.emphasis * 0.22)
                let heartStrokeEmphasis = heartLine.prominence * Double(formationProgress)
                    * (0.34 + heartGlow.emphasis * 0.58)

                var lineContext = context
                lineContext.translateBy(x: gridCenter.x, y: gridCenter.y)
                lineContext.rotate(by: .degrees(rotation))

                var line = Path()
                line.move(to: CGPoint(x: -lineLength / 2, y: 0))
                line.addLine(to: CGPoint(x: lineLength / 2, y: 0))
                let strokeStyle = StrokeStyle(
                    lineWidth: lineWidth * (1 + CGFloat(heartStrokeEmphasis)),
                    lineCap: .round
                )
                if inkOpacity > 0 {
                    lineContext.stroke(
                        line,
                        with: .color(PremiumArrivalStyle.ink.opacity(inkOpacity)),
                        style: strokeStyle
                    )
                }
                if pinkOpacity > 0 {
                    lineContext.stroke(
                        line,
                        with: .color(PremiumArrivalStyle.pinkInk.opacity(pinkOpacity)),
                        style: strokeStyle
                    )
                }
            }
        }
    }

}

struct OnboardingWelcomeView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    let heartFormationStart: Date?

    var body: some View {
        VStack(spacing: 82) {
            BreathingLineCube(heartFormationStart: heartFormationStart)

            Text("onboarding.welcome.title")
                .font(
                    .system(
                        size: min(titleSize, 54),
                        weight: .regular,
                        design: .serif
                    )
                )
                .tracking(-1.1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.welcome.title")
        }
        .frame(maxWidth: .infinity)
    }
}
