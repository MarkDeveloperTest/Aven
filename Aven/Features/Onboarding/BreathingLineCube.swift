import SwiftUI

nonisolated enum LineCubeMotion {
    static let gridSize = 15
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
        let center = Double(gridSize - 1) / 2
        let point = (x: Double(column), y: Double(row))
        let segmentCount = 96

        var nearestDistance = Double.infinity
        var nearestRotation = 0.0
        for index in 0..<segmentCount {
            let start = heartPoint(
                at: Double(index) / Double(segmentCount) * .pi * 2,
                center: center
            )
            let end = heartPoint(
                at: Double(index + 1) / Double(segmentCount) * .pi * 2,
                center: center
            )
            let horizontal = end.x - start.x
            let vertical = end.y - start.y
            let lengthSquared = (horizontal * horizontal) + (vertical * vertical)
            let projection = min(
                max(
                    ((point.x - start.x) * horizontal + (point.y - start.y) * vertical)
                        / lengthSquared,
                    0
                ),
                1
            )
            let closestX = start.x + horizontal * projection
            let closestY = start.y + vertical * projection
            let distance = hypot(point.x - closestX, point.y - closestY)

            guard distance < nearestDistance else { continue }
            nearestDistance = distance
            nearestRotation = atan2(vertical, horizontal) * 180 / .pi
        }

        // Lines outside the centered heart are the horizontal background grid.
        return nearestDistance <= 0.52 ? nearestRotation : 0
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

    private static func heartPoint(
        at parameter: Double,
        center: Double
    ) -> (x: Double, y: Double) {
        let scale = 0.24
        let horizontal = 16 * pow(sin(parameter), 3)
        let vertical = 13 * cos(parameter)
            - 5 * cos(2 * parameter)
            - 2 * cos(3 * parameter)
            - cos(4 * parameter)

        return (
            x: center + horizontal * scale,
            y: center - vertical * scale
        )
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
                let rotation = formationProgress == 0
                    ? gridRotation
                    : LineCubeMotion.interpolatedRotationDegrees(
                        from: gridRotation,
                        to: LineCubeMotion.heartRotationDegrees(
                            row: row,
                            column: column
                        ),
                        progress: formationProgress
                    )

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
