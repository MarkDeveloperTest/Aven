import Foundation
import Testing
@testable import Aven

@Suite("Welcome line cube motion")
struct LineCubeMotionTests {
    @Test("Every line rotation repeats after the full idle loop")
    func repeatsAfterFullIdleLoop() {
        for row in 0..<LineCubeMotion.gridRowCount {
            for column in 0..<LineCubeMotion.gridSize {
                let first = LineCubeMotion.rotationDegrees(
                    row: row,
                    column: column,
                    elapsed: 1.375
                )
                let repeated = LineCubeMotion.rotationDegrees(
                    row: row,
                    column: column,
                    elapsed: 1.375 + LineCubeMotion.idleLoopDuration
                )

                #expect(abs(first - repeated) < 0.000_001)
            }
        }
    }

    @Test("Idle loop moves through orbit, sweep, and ripple")
    func cyclesThroughDistinctIdleMotions() {
        #expect(LineCubeMotion.idleModeIndex(elapsed: 0) == 0)
        #expect(LineCubeMotion.idleModeIndex(elapsed: LineCubeMotion.period) == 1)
        #expect(LineCubeMotion.idleModeIndex(elapsed: LineCubeMotion.period * 2) == 2)
        #expect(LineCubeMotion.idleModeIndex(elapsed: LineCubeMotion.period * 3) == 0)

        let orbit = LineCubeMotion.idlePhaseOffset(row: 1, column: 8, elapsed: 1)
        let sweep = LineCubeMotion.idlePhaseOffset(
            row: 1,
            column: 8,
            elapsed: LineCubeMotion.period + 1
        )
        let ripple = LineCubeMotion.idlePhaseOffset(
            row: 1,
            column: 8,
            elapsed: LineCubeMotion.period * 2 + 1
        )

        #expect(abs(orbit - sweep) > 0.001)
        #expect(abs(sweep - ripple) > 0.001)
    }

    @Test("Neighboring lines use independent phases")
    func staggersNeighboringLines() {
        let first = LineCubeMotion.rotationDegrees(
            row: 2,
            column: 2,
            elapsed: 1
        )
        let neighbor = LineCubeMotion.rotationDegrees(
            row: 2,
            column: 3,
            elapsed: 1
        )

        #expect(abs(first - neighbor) > 0.1)
    }

    @Test("Heart uses the compact reference glyph and horizontal background cells")
    func heartUsesACompactSymmetricFixedGridGlyph() {
        #expect(LineCubeMotion.gridSize == 10)
        #expect(LineCubeMotion.gridRowCount == 11)
        #expect(LineCubeMotion.heartRotationDegrees(row: 4, column: 8) == 90)
        #expect(LineCubeMotion.heartLine(row: 4, column: 1).prominence == 1)
        #expect(LineCubeMotion.heartRotationDegrees(row: 5, column: 1) == 45)
        #expect(LineCubeMotion.heartRotationDegrees(row: 5, column: 8) == 135)
        #expect(LineCubeMotion.heartLine(row: 7, column: 3).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 8, column: 4).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 9, column: 4).prominence == 0)
        #expect(LineCubeMotion.heartRotationDegrees(row: 6, column: 5) == 0)
        #expect(LineCubeMotion.heartLine(row: 6, column: 5).prominence == 0)
        #expect(LineCubeMotion.heartLine(row: 0, column: 0).prominence == 0)
    }

    @Test("Heart target mirrors across the center axis")
    func heartTargetIsSymmetric() {
        for row in 0..<LineCubeMotion.gridRowCount {
            for column in 0..<(LineCubeMotion.gridSize / 2) {
                let leading = LineCubeMotion.heartLine(row: row, column: column)
                let trailing = LineCubeMotion.heartLine(
                    row: row,
                    column: LineCubeMotion.gridSize - 1 - column
                )

                #expect(leading.prominence == trailing.prominence)
                #expect(mirroredRotation(leading.rotation) == trailing.rotation)
            }
        }
    }

    @Test("Heart occupies the compact centered reference bounds")
    func heartUsesCompactReferenceBounds() {
        let heartRows = (0..<LineCubeMotion.gridRowCount).filter { row in
            (0..<LineCubeMotion.gridSize).contains { column in
                LineCubeMotion.heartLine(row: row, column: column).prominence == 1
            }
        }

        #expect(heartRows.first == 2)
        #expect(heartRows.last == 8)

        let heartColumns = (0..<LineCubeMotion.gridSize).filter { column in
            (0..<LineCubeMotion.gridRowCount).contains { row in
                LineCubeMotion.heartLine(row: row, column: column).prominence == 1
            }
        }
        #expect(heartColumns.first == 1)
        #expect(heartColumns.last == 8)
    }

    @Test("Heart formation settles smoothly at both ends")
    func heartFormationSettlesSmoothly() {
        let start = LineCubeMotion.heartFormationProgress(elapsed: 0)
        let halfway = LineCubeMotion.heartFormationProgress(
            elapsed: LineCubeMotion.heartFormationDuration / 2
        )
        let finish = LineCubeMotion.heartFormationProgress(
            elapsed: LineCubeMotion.heartFormationDuration
        )

        #expect(start == 0)
        #expect(abs(halfway - 0.5) < 0.000_001)
        #expect(finish == 1)
    }

    @Test("Heart tint follows the smooth formation progress")
    func heartTintFollowsFormationProgress() {
        #expect(LineCubeMotion.heartTintProgress(formationProgress: -0.2) == 0)
        #expect(LineCubeMotion.heartTintProgress(formationProgress: 0.5) == 0.5)
        #expect(LineCubeMotion.heartTintProgress(formationProgress: 1.2) == 1)
    }

    @Test("Heart formation rotates every line forward")
    func heartFormationUsesForwardRotation() {
        #expect(LineCubeMotion.heartHoldDuration == 1)
        let crossingZero = LineCubeMotion.forwardInterpolatedRotationDegrees(
            from: 350,
            to: 10,
            progress: 0.5
        )
        let longRoute = LineCubeMotion.forwardInterpolatedRotationDegrees(
            from: 10,
            to: 350,
            progress: 0.5
        )
        let fullTurn = LineCubeMotion.forwardInterpolatedRotationDegrees(
            from: 0,
            to: 0,
            progress: 0.5
        )

        #expect(abs(crossingZero - 360) < 0.001)
        #expect(abs(longRoute - 180) < 0.001)
        #expect(abs(fullTurn - 180) < 0.001)
    }

    @Test("Heart lights up once after formation")
    func heartGlowTiming() {
        let beforeFormation = LineCubeMotion.heartGlow(elapsed: nil)
        let forming = LineCubeMotion.heartGlow(
            elapsed: LineCubeMotion.heartFormationDuration - 0.01
        )
        let arrived = LineCubeMotion.heartGlow(
            elapsed: LineCubeMotion.heartFormationDuration
        )
        let held = LineCubeMotion.heartGlow(
            elapsed: LineCubeMotion.heartFormationDuration + 0.8
        )

        #expect(beforeFormation == .idle)
        #expect(forming == .idle)
        #expect(arrived.emphasis > 0)
        #expect(arrived == held)
    }

    private func mirroredRotation(_ rotation: Double) -> Double {
        switch rotation {
        case 45:
            return 135
        case 135:
            return 45
        default:
            return rotation
        }
    }
}
