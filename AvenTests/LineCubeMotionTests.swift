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

    @Test("Heart uses selected outline cells and horizontal background cells")
    func heartUsesAFixedRotationMap() {
        #expect(LineCubeMotion.gridSize == 11)
        #expect(LineCubeMotion.heartRotationDegrees(row: 1, column: 1) == 135)
        #expect(LineCubeMotion.heartRotationDegrees(row: 2, column: 5) == 90)
        #expect(LineCubeMotion.heartRotationDegrees(row: 4, column: 1) == 45)
        #expect(LineCubeMotion.heartRotationDegrees(row: 5, column: 5) == 0)
    }
}
