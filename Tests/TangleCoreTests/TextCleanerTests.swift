import XCTest
@testable import TangleCore

final class TextCleanerTests: XCTestCase {
    func testNormalizesWhitespaceAndRepeatedBlankLines() {
        let input = "Hello,\t\tworld!\n\n\nThis   is   Tangle."
        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "Hello, world!\n\nThis is Tangle.")
    }

    func testRemovesInvisibleCharactersSafely() {
        let input = "Tan\u{200B}gle\u{0007}"
        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "Tangle")
    }

    func testJoinsWrappedParagraphs() {
        let input = """
        This is a sentence
        wrapped by a PDF
        or copied webpage.
        """

        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "This is a sentence wrapped by a PDF or copied webpage.")
    }

    func testPreservesLists() {
        let input = """
        - One
        - Two
        - Three
        """

        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "- One\n- Two\n- Three")
    }
}
