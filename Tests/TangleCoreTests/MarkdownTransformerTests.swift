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

    func testMarkdownTransformIsIdempotentForFixtures() throws {
        let fixtureNames = [
            "pdf-report-input",
            "web-article-input",
            "kpmg-sdv-input",
            "deloitte-web-input"
        ]
        let transformer = MarkdownTransformer(preset: .llm)

        for fixtureName in fixtureNames {
            let input = try fixture(named: fixtureName, extension: "txt")
            let first = transformer.transform(input)
            let second = transformer.transform(first)

            XCTAssertEqual(first, second, "Expected \(fixtureName) to be idempotent")
        }
    }

    func testConvertsBrowserHTMLToMarkdown() {
        let html = """
        <html>
        <body>
          <h1>Sfide e opportunità del settore Automotive</h1>
          <p>Il settore <strong>automotive</strong> è in costante evoluzione.</p>
          <h2>Future of Mobility: le soluzioni di domani</h2>
          <p>Leggi il <a href="https://www.deloitte.com/it/it/Industries/automotive/about/automotive-deloitte-automotivesector.html?utm_source=google&amp;utm_medium=cpc&amp;gclid=abc#report">report Deloitte</a>.</p>
          <ul>
            <li><a href="https://www.deloitte.com/it/it.html">Deloitte Italia</a></li>
          </ul>
        </body>
        </html>
        """

        let output = MarkdownTransformer(preset: .llm).transform(
            html: html,
            fallbackText: "Sfide e opportunità del settore Automotive"
        )

        XCTAssertEqual(output, """
        # Sfide e opportunità del settore Automotive

        Il settore **automotive** è in costante evoluzione.

        ## Future of Mobility: le soluzioni di domani

        Leggi il [report Deloitte](https://www.deloitte.com/it/it/Industries/automotive/about/automotive-deloitte-automotivesector.html#report).

        - [Deloitte Italia](https://www.deloitte.com/it/it.html)
        """)
    }

    func testConvertsHTMLCodeBlocksTablesListsAndQuotes() {
        let html = """
        <article>
          <p>Don&rsquo;t lose <code>inline</code> code &mdash; keep it useful.</p>
          <pre><code>const value = 42;
        console.log(value);</code></pre>
          <ol>
            <li>Install the package<ul><li>Use the stable channel</li></ul></li>
            <li>Run the command</li>
          </ol>
          <blockquote><p>This is quoted text.</p></blockquote>
          <table>
            <tr><th>Token</th><th>Count</th></tr>
            <tr><td>word</td><td>42</td></tr>
          </table>
        </article>
        """

        let output = MarkdownTransformer(preset: .llm).transform(
            html: html,
            fallbackText: ""
        )

        XCTAssertEqual(output, """
        Don’t lose `inline` code — keep it useful.

        ```
        const value = 42;
        console.log(value);
        ```

        1. Install the package
          - Use the stable channel
        2. Run the command

        > This is quoted text.

        | Token | Count |
        | --- | --- |
        | word | 42 |
        """)
    }

    func testStandardHTMLPresetPreservesReadableMarkdown() {
        let html = """
        <h2>Setup</h2>
        <p>Use <strong>local</strong> transforms.</p>
        """

        let output = MarkdownTransformer(preset: .standard).transform(
            html: html,
            fallbackText: ""
        )

        XCTAssertEqual(output, """
        ## Setup

        Use **local** transforms.
        """)
    }

    func testFallsBackToPlainTextWhenHTMLHasNoContent() {
        let output = MarkdownTransformer(preset: .llm).transform(
            html: "<script>ignored()</script>",
            fallbackText: "TANGLE NOTES\n\nClipboard text"
        )

        XCTAssertEqual(output, """
        ## Tangle Notes

        Clipboard text
        """)
    }

    func testColonIntroLinesDoNotBecomeHeadingsInsideFlowingText() {
        let input = """
        Some context line without sentence ending

        Install the package using npm:

        npm install something

        Or using yarn:

        yarn add something
        """

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, """
        Some context line without sentence ending

        Install the package using npm:

        npm install something

        Or using yarn:

        yarn add something
        """)
    }

    func testEllipsisPreventsWebHeadingFalsePositive() {
        let input = """
        The cost is €99 or £85 per month…

        Next sentence continues here.
        """

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, """
        The cost is €99 or £85 per month…

        Next sentence continues here.
        """)
    }

    func testWeakContinuationWordsDoNotBecomeHeadings() {
        let input = """
        This option is better than

        the previous implementation.

        We should avoid this because

        the result is incomplete.
        """

        let output = MarkdownTransformer(preset: .llm).transform(input)

        XCTAssertEqual(output, """
        This option is better than

        the previous implementation.

        We should avoid this because

        the result is incomplete.
        """)
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
