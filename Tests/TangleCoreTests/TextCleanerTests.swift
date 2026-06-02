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

    func testPreservesPdfHyphenControlCharacters() {
        let input = "Software\u{0002}defined vehicles and vehicle\u{00AD}wide data"
        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "Software-defined vehicles and vehicle-wide data")
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

    func testRepairsPdfHyphenatedLineBreaks() {
        let input = """
        Clipboard transforma-
        tions should stay local.
        """

        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, "Clipboard transformations should stay local.")
    }

    func testRemovesRepeatedShortHeadersAndPageNumbers() {
        let input = """
        TANGLE REPORT
        1

        First paragraph.

        TANGLE REPORT
        2

        Second paragraph.

        TANGLE REPORT
        3
        """

        let output = TextCleaner().clean(input)

        XCTAssertEqual(output, """
        TANGLE REPORT

        First paragraph.

        Second paragraph.
        """)
    }
}
