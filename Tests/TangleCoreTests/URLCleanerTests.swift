import XCTest
@testable import TangleCore

final class URLCleanerTests: XCTestCase {
    func testRemovesCommonTrackingParameters() {
        let input = "https://example.com/article?id=42&utm_source=newsletter&fbclid=abc"
        let output = URLCleaner().cleanURLs(in: input)

        XCTAssertEqual(output, "https://example.com/article?id=42")
    }

    func testPreservesMeaningfulParametersAndFragments() {
        let input = "https://example.com/search?q=tangle&utm_campaign=launch#results"
        let output = URLCleaner().cleanURLs(in: input)

        XCTAssertEqual(output, "https://example.com/search?q=tangle#results")
    }

    func testSupportsMultipleURLsInText() {
        let input = "Read https://a.test/?utm_medium=social&x=1 and https://b.test/?gclid=abc&y=2."
        let output = URLCleaner().cleanURLs(in: input)

        XCTAssertEqual(output, "Read https://a.test/?x=1 and https://b.test/?y=2.")
    }

    func testAllowlistWinsOverBlocklist() {
        let cleaner = URLCleaner(allowedParameters: ["utm_source"])
        let input = "https://example.com/?utm_source=keep&utm_medium=drop"
        let output = cleaner.cleanURLs(in: input)

        XCTAssertEqual(output, "https://example.com/?utm_source=keep")
    }
}
