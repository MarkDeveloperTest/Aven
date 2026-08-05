import SwiftUI

nonisolated enum LineCubeMotion {
    static let gridSize = 10
    static let period: TimeInterval = 6
    static let heartFormationDuration: TimeInterval = 0.8
    static let heartHoldDuration: TimeInterval = 0.6

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
        let rawProgress = (elapsed / period) + phaseOffset(row: row, column: column)
        return rawProgress - floor(rawProgress)
    }

    static func heartRotationDegrees(row: Int, column: Int) -> Double {
        heartLine(row: row, column: column).rotation
    }

    static func heartFormationProgress(elapsed: TimeInterval) -> CGFloat {
        let normalized = min(max(elapsed / heartFormationDuration, 0), 1)
        // Quintic smootherstep settles with no visible acceleration at either end.
        let eased = normalized * normalized * normalized
            * (normalized * (normalized * 6 - 15) + 10)
        return CGFloat(eased)
    }

    static func heartLine(
        row: Int,
        column: Int
    ) -> (rotation: Double, prominence: Double) {
        guard isHeartCell(row: row, column: column) else {
            // These lines never leave their cells: a faint horizontal halo softens
            // the outline while the rest stays as the quiet background grid.
            return (rotation: 0, prominence: heartHaloProminence(row: row, column: column))
        }

        // A deliberately simple, rounded heart outline for the 10 by 10 grid.
        let rotation: Double
        switch (row, column) {
        case (2, 1), (2, 5), (4, 7), (5, 6), (6, 5):
            rotation = 135
        case (2, 4), (2, 8), (4, 2), (5, 3), (6, 4):
            rotation = 45
        case (3, 1), (3, 8):
            rotation = 90
        default:
            rotation = 0
        }
        return (rotation: rotation, prominence: 1)
    }

    static func interpolatedRotationDegrees(
        from start: Double,
        to end: Double,
        progress: CGFloat
    ) -> Double {
        let normalizedStart = start.truncatingRemainder(dividingBy: 360)
        let shortestDelta = (end - normalizedStart + 540)
            .truncatingRemainder(dividingBy: 360) - 180
        return start + shortestDelta * Double(progress)
    }

    private static func isHeartCell(row: Int, column: Int) -> Bool {
        switch row {
        case 1:
            return (2...3).contains(column) || (6...7).contains(column)
        case 2:
            return [1, 4, 5, 8].contains(column)
        case 3:
            return [1, 8].contains(column)
        case 4:
            return [2, 7].contains(column)
        case 5:
            return [3, 6].contains(column)
        case 6:
            return (4...5).contains(column)
        default:
            return false
        }
    }

    private static func heartHaloProminence(row: Int, column: Int) -> Double {
        for rowOffset in -1...1 {
            for columnOffset in -1...1 where rowOffset != 0 || columnOffset != 0 {
                if isHeartCell(row: row + rowOffset, column: column + columnOffset) {
                    return 0.16
                }
            }
        }
        return 0
    }

    private static func phaseOffset(row: Int, column: Int) -> Double {
        let center = Double(gridSize - 1) / 2
        let rowDistance = Double(row) - center
        let columnDistance = Double(column) - center
        let maximumDistance = hypot(center, center)
        let radialOffset = hypot(rowDistance, columnDistance) / maximumDistance * 0.22

        let lineIndex = (row * gridSize) + column
        let centerIndex = (gridSize * gridSize) / 2
        let individualOffset = lineIndex == centerIndex
            ? 0
            : Double((lineIndex * 7) % 13) / 13 * 0.035
        return radialOffset + individualOffset
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
                minimumInterval: 1.0 / 60.0,
                paused: reduceMotion || scenePhase != .active
            )
        ) { timeline in
            Canvas { context, size in
                drawLines(
                    in: context,
                    size: size,
                    elapsed: reduceMotion
                        ? 0
                        : timeline.date.timeIntervalSince(animationStart),
                    heartProgress: heartProgress(at: timeline.date)
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

    private func heartProgress(at date: Date) -> CGFloat {
        guard heartFormationStart != nil else { return 0 }
        guard reduceMotion == false else { return 1 }

        let elapsed = date.timeIntervalSince(heartFormationStart ?? date)
        return LineCubeMotion.heartFormationProgress(elapsed: elapsed)
    }

    private func drawLines(
        in context: GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        heartProgress: CGFloat
    ) {
        let side = min(size.width, size.height)
        let cellSize = side / CGFloat(LineCubeMotion.gridSize)
        let lineLength = cellSize * 0.60
        let lineWidth = max(1.6, cellSize * 0.06)
        let origin = CGPoint(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2
        )
        let formationProgress = min(max(heartProgress, 0), 1)

        for row in 0..<LineCubeMotion.gridSize {
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
                    : LineCubeMotion.interpolatedRotationDegrees(
                        from: gridRotation,
                        to: heartLine.rotation,
                        progress: formationProgress
                    )
                let heartOpacity = 0.28 + 0.64 * heartLine.prominence
                let opacity = 0.86 + (heartOpacity - 0.86) * formationProgress

                var lineContext = context
                lineContext.translateBy(x: gridCenter.x, y: gridCenter.y)
                lineContext.rotate(by: .degrees(rotation))

                var line = Path()
                line.move(to: CGPoint(x: -lineLength / 2, y: 0))
                line.addLine(to: CGPoint(x: lineLength / 2, y: 0))
                lineContext.stroke(
                    line,
                    with: .color(PremiumArrivalStyle.ink.opacity(opacity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
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
