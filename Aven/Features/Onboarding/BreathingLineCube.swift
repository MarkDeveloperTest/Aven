import SwiftUI

nonisolated enum LineCubeMotion {
    static let gridSize = 11
    static let period: TimeInterval = 6
    static let heartFormationDuration: TimeInterval = 0.8

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
        // The heart is composed from fixed grid cells. Every unspecified cell
        // deliberately settles horizontal to keep the heart outline legible.
        switch (row, column) {
        case (1, 1), (1, 6), (4, 9), (5, 8), (6, 7), (7, 6):
            return 135
        case (1, 4), (1, 9), (4, 1), (5, 2), (6, 3), (7, 4):
            return 45
        case (2, 0), (2, 5), (2, 10), (3, 0), (3, 10), (8, 5):
            return 90
        default:
            return 0
        }
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
    }

    private func heartProgress(at date: Date) -> CGFloat {
        guard heartFormationStart != nil else { return 0 }
        guard reduceMotion == false else { return 1 }

        let elapsed = date.timeIntervalSince(heartFormationStart ?? date)
        let rawProgress = min(max(elapsed / LineCubeMotion.heartFormationDuration, 0), 1)
        return 0.5 - (0.5 * cos(.pi * rawProgress))
    }

    private func drawLines(
        in context: GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        heartProgress: CGFloat
    ) {
        let side = min(size.width, size.height)
        let cellSize = side / CGFloat(LineCubeMotion.gridSize)
        let lineLength = cellSize * 0.54
        let lineWidth = max(1.6, cellSize * 0.055)
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
                let rotation = gridRotation + (
                    LineCubeMotion.heartRotationDegrees(
                        row: row,
                        column: column
                    ) - gridRotation
                ) * formationProgress

                var lineContext = context
                lineContext.translateBy(x: gridCenter.x, y: gridCenter.y)
                lineContext.rotate(by: .degrees(rotation))

                var line = Path()
                line.move(to: CGPoint(x: -lineLength / 2, y: 0))
                line.addLine(to: CGPoint(x: lineLength / 2, y: 0))
                lineContext.stroke(
                    line,
                    with: .color(PremiumArrivalStyle.ink.opacity(0.86)),
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
        VStack(spacing: 56) {
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
