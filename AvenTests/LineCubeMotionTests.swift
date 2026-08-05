import Foundation
import Testing
@testable import Aven

@Suite("Welcome line cube motion")
struct LineCubeMotionTests {
    @Test("Every line rotation repeats after one breathing period")
    func repeatsAfterOnePeriod() {
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
                    elapsed: 1.375 + LineCubeMotion.period
                )

                #expect(abs(first - repeated) < 0.000_001)
            }
        }
    }

    @Test("The center line completes a full eased rotation")
    func completesFullRotation() {
        let center = LineCubeMotion.gridSize / 2
        let start = LineCubeMotion.rotationDegrees(
            row: center,
            column: center,
            elapsed: 0
        )
        let halfway = LineCubeMotion.rotationDegrees(
            row: center,
            column: center,
            elapsed: LineCubeMotion.period / 2
        )
        let almostComplete = LineCubeMotion.rotationDegrees(
            row: center,
            column: center,
            elapsed: LineCubeMotion.period - 0.001
        )

        #expect(abs(start) < 0.000_001)
        #expect(abs(halfway - 180) < 0.000_001)
        #expect(almostComplete > 359.999)
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

    @Test("Heart uses a simple centered glyph and horizontal background cells")
    func heartUsesASimpleFixedGridGlyph() {
        #expect(LineCubeMotion.gridSize == 10)
        #expect(LineCubeMotion.heartRotationDegrees(row: 3, column: 8) == 90)
        #expect(LineCubeMotion.heartLine(row: 5, column: 3).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 6, column: 4).prominence == 1)
        #expect(LineCubeMotion.heartLine(row: 7, column: 4).prominence < 1)
        #expect(LineCubeMotion.heartRotationDegrees(row: 5, column: 5) == 0)
        #expect(LineCubeMotion.heartLine(row: 5, column: 5).prominence > 0)
        #expect(LineCubeMotion.heartLine(row: 0, column: 0).prominence == 0)
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
        #expect(LineCubeMotion.heartHoldDuration == 0.6)
        let halfway = LineCubeMotion.interpolatedRotationDegrees(
            from: 350,
            to: 10,
            progress: 0.5
        )

        #expect(abs(halfway - 360) < 0.001)
    }
}
