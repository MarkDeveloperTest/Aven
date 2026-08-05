import Foundation
import Testing
@testable import Aven

@Suite("Welcome line cube motion")
struct LineCubeMotionTests {
    @Test("Every line rotation repeats after the full idle loop")
    func repeatsAfterFullIdleLoop() {
        for row in 0..<LineCubeMotion.gridSize {
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

    @Test("Heart uses a centered symmetric glyph and horizontal background cells")
    func heartUsesACenteredSymmetricFixedGridGlyph() {
        #expect(LineCubeMotion.gridSize == 10)
        #expect(LineCubeMotion.heartRotationDegrees(row: 3, column: 8) == 90)
        #expect(LineCubeMotion.heartLine(row: 3, column: 1).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 7, column: 3).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 8, column: 4).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 9, column: 4).prominence == 0)
        #expect(LineCubeMotion.heartRotationDegrees(row: 5, column: 5) == 0)
        #expect(LineCubeMotion.heartLine(row: 5, column: 5).prominence == 0)
        #expect(LineCubeMotion.heartLine(row: 0, column: 0).prominence == 0)
    }

    @Test("Heart target mirrors across the center axis")
    func heartTargetIsSymmetric() {
        for row in 0..<LineCubeMotion.gridSize {
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

    @Test("Heart is vertically centered and taller than the original compact mark")
    func heartIsTallAndCentered() {
        let heartRows = (0..<LineCubeMotion.gridSize).filter { row in
            (0..<LineCubeMotion.gridSize).contains { column in
                LineCubeMotion.heartLine(row: row, column: column).prominence == 1
            }
        }

        #expect(heartRows.first == 1)
        #expect(heartRows.last == 8)

        let heartColumns = (0..<LineCubeMotion.gridSize).filter { column in
            (0..<LineCubeMotion.gridSize).contains { row in
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

    @Test("Heart formation uses the shortest rotational route")
    func heartFormationUsesShortestRotation() {
        #expect(LineCubeMotion.heartHoldDuration == 3)
        let halfway = LineCubeMotion.interpolatedRotationDegrees(
            from: 350,
            to: 10,
            progress: 0.5
        )

        #expect(abs(halfway - 360) < 0.001)
    }

    @Test("Heart lines double-beat after formation")
    func heartPulseTiming() {
        let beforeFormation = LineCubeMotion.heartPulse(
            elapsed: nil,
            reduceMotion: false
        )
        let arrived = LineCubeMotion.heartPulse(
            elapsed: LineCubeMotion.heartFormationDuration,
            reduceMotion: false
        )
        let primaryBeat = LineCubeMotion.heartPulse(
            elapsed: LineCubeMotion.heartFormationDuration + 0.20,
            reduceMotion: false
        )
        let betweenBeats = LineCubeMotion.heartPulse(
            elapsed: LineCubeMotion.heartFormationDuration + 0.34,
            reduceMotion: false
        )
        let secondaryBeat = LineCubeMotion.heartPulse(
            elapsed: LineCubeMotion.heartFormationDuration
                + 0.44,
            reduceMotion: false
        )
        let reducedMotion = LineCubeMotion.heartPulse(
            elapsed: 0,
            reduceMotion: true
        )

        #expect(beforeFormation == .idle)
        #expect(arrived == .idle)
        #expect(primaryBeat.emphasis > betweenBeats.emphasis)
        #expect(secondaryBeat.emphasis > betweenBeats.emphasis)
        #expect(reducedMotion == .idle)
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
