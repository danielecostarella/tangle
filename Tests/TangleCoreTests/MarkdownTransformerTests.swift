import XCTest
@testable import TangleCore

final class MarkdownTransformerTests: XCTestCase {
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
}
