import XCTest
@testable import TangleCore

final class MarkdownTransformerTests: XCTestCase {
    func testPdfReportFixture() throws {
        let input = try fixture(named: "pdf-report-input", extension: "txt")
        let expected = try fixture(named: "pdf-report-expected", extension: "md")

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, expected)
    }

    func testWebArticleFixture() throws {
        let input = try fixture(named: "web-article-input", extension: "txt")
        let expected = try fixture(named: "web-article-expected", extension: "md")

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, expected)
    }

    func testKPMGSoftwareDefinedVehicleFixture() throws {
        let input = try fixture(named: "kpmg-sdv-input", extension: "txt")
        let expected = try fixture(named: "kpmg-sdv-expected", extension: "md")

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, expected)
    }

    func testDeloitteWebHeadingFixture() throws {
        let input = try fixture(named: "deloitte-web-input", extension: "txt")
        let expected = try fixture(named: "deloitte-web-expected", extension: "md")

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, expected)
    }

    func testConvertsPdfLikeTextToCompactMarkdown() {
        let input = """
        TANGLE WHITEPAPER
        1

        Clipboard transforma-
        tions should stay local
        and predictable.

        • Clean copied text
        • Remove tracking URLs

        TANGLE WHITEPAPER
        2

        TOKEN SAVINGS
        Messy PDF text often
        wastes context window.

        TANGLE WHITEPAPER
        3
        """

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, """
        ## Tangle Whitepaper

        Clipboard transformations should stay local and predictable.

        - Clean copied text
        - Remove tracking URLs

        ## Token Savings
        Messy PDF text often wastes context window.
        """)
    }

    func testConvertsUnderlineHeadings() {
        let input = """
        Introduction
        ============

        Tangle cleans clipboard text.
        """

        let output = MarkdownTransformer(preset: .standard).transform(input)

        XCTAssertEqual(output, """
        # Introduction

        Tangle cleans clipboard text.
        """)
    }

    private func fixture(named name: String, extension fileExtension: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: fileExtension))
        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
