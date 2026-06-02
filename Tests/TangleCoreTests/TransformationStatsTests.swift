import XCTest
@testable import TangleCore

final class TransformationStatsTests: XCTestCase {
    func testComputesCharacterAndTokenSavings() {
        let stats = TransformationStats(input: "1234567890", output: "1234")

        XCTAssertEqual(stats.inputCharacters, 10)
        XCTAssertEqual(stats.outputCharacters, 4)
        XCTAssertEqual(stats.characterDelta, 6)
        XCTAssertEqual(stats.estimatedInputTokens, 3)
        XCTAssertEqual(stats.estimatedOutputTokens, 1)
        XCTAssertEqual(stats.estimatedTokenDelta, 2)
    }

    func testEmptyTokenEstimateIsZero() {
        XCTAssertEqual(TransformationStats.estimatedTokens(for: ""), 0)
    }
}
