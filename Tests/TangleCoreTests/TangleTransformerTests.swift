import XCTest
@testable import TangleCore

final class TangleTransformerTests: XCTestCase {
    func testUsesConfiguredMarkdownPreset() {
        let input = """
        REPORT TITLE

        Text copied
        from a PDF.
        """
        let settings = TangleSettings(markdownPreset: .llm)
        let output = TangleTransformer(settings: settings).transform(input, kind: .markdown)

        XCTAssertEqual(output, """
        ## Report Title

        Text copied from a PDF.
        """)
    }

    func testMarkdownUsesClipboardHTMLWhenAvailable() {
        let content = ClipboardContent(
            text: "Plain fallback",
            html: "<p><strong>Rich</strong> <a href=\"https://example.com/?utm_source=x&id=42\">link</a></p>"
        )

        let output = TangleTransformer().transform(content, kind: .markdown)

        XCTAssertEqual(output, "**Rich** [link](https://example.com/?id=42)")
    }

    func testUsesConfiguredURLAllowlist() {
        let settings = TangleSettings(allowedURLParameters: ["utm_source"])
        let output = TangleTransformer(settings: settings).transform(
            "https://example.com/?utm_source=keep&utm_medium=drop&id=42",
            kind: .cleanURL
        )

        XCTAssertEqual(output, "https://example.com/?utm_source=keep&id=42")
    }

    func testPlainPasteUsesTextCleaner() {
        let output = TangleTransformer().transform("Hello,\t\tTangle", kind: .plainPaste)

        XCTAssertEqual(output, "Hello, Tangle")
    }

    // MARK: - Excel clipboard simulation

    func testExcelTSVPasteMarkdownProducesTable() throws {
        // Excel copies TSV as plain text + HTML table as rich content
        let tsv = "Product\tQ1\tQ2\nWidget A\t12,400\t15,200\nWidget B\t8,700\t9,100"
        let html = "<table><tr><th>Product</th><th>Q1</th><th>Q2</th></tr><tr><td><b>Widget A</b></td><td>12,400</td><td>15,200</td></tr><tr><td><b>Widget B</b></td><td>8,700</td><td>9,100</td></tr></table>"

        // When HTML is present (real Excel copy), smart uses HTML→Markdown
        let withHTML = ClipboardContent(text: tsv, html: html)
        let mdFromHTML = try TangleTransformer().transformContent(withHTML, kind: .smart)
        XCTAssertTrue(mdFromHTML.contains("| Product |"), "Should produce markdown table from HTML")
        XCTAssertTrue(mdFromHTML.contains("**Widget A**"), "Should preserve bold from HTML")

        // When only TSV is present (e.g. paste from Numbers without HTML), smart detects table
        let tsvOnly = ClipboardContent(text: tsv)
        let mdFromTSV = try TangleTransformer().transformContent(tsvOnly, kind: .smart)
        XCTAssertTrue(mdFromTSV.contains("| Product |"), "Should produce markdown table from TSV")
    }

    func testExcelTSVPasteCleanTextKeepsStructure() throws {
        // Paste Clean Text on a table should not flatten it to a word soup
        let tsv = "Name\tRevenue\nAcme\t100000\nBeta\t80000"
        let content = ClipboardContent(text: tsv)
        let output = try TangleTransformer().transformContent(content, kind: .smartText)
        // Should NOT collapse to a single line
        XCTAssertTrue(output.contains("Acme"), "Should preserve cell content")
        XCTAssertFalse(output == "Name Revenue Acme 100000 Beta 80000", "Should not flatten to a single line")
    }

    func testFlattenedDatasheetTableBecomesReadableCleanText() {
        let input = "Power Consumption Symbol Description Min Typ Max Unit VINMax Maximum input voltage from VIN pad 6 - 20 V VUSBMax Maximum input voltage from USB connector - 5.5 V PMax Maximum Power Consumption - - xx mA"

        let output = TangleTransformer().transform(input, kind: .cleanText)

        XCTAssertEqual(output, """
        Symbol\tDescription\tMin\tTyp\tMax\tUnit
        VINMax\tMaximum input voltage from VIN pad\t6\t-\t20\tV
        VUSBMax\tMaximum input voltage from USB connector\t\t-\t5.5\tV
        PMax\tMaximum Power Consumption\t-\t-\txx\tmA
        """)
    }

    func testFlattenedDatasheetTableBecomesMarkdown() {
        let input = "Power Consumption Symbol Description Min Typ Max Unit VINMax Maximum input voltage from VIN pad 6 - 20 V VUSBMax Maximum input voltage from USB connector - 5.5 V PMax Maximum Power Consumption - - xx mA"

        let output = TangleTransformer().transform(input, kind: .markdown)

        XCTAssertTrue(output.contains("| VINMax | Maximum input voltage from VIN pad | 6 | - | 20 | V |"))
        XCTAssertTrue(output.contains("| VUSBMax | Maximum input voltage from USB connector |  | - | 5.5 | V |"))
    }
}
