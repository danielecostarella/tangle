import CoreGraphics
import XCTest
@testable import TangleCore

final class ImageMarkdownFormatterTests: XCTestCase {
    func testFormatsOCRLinesAsConservativeMarkdown() {
        let lines = [
            OCRTextLine(text: "MARKET OUTLOOK", confidence: 0.98, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.08)),
            OCRTextLine(text: "Software platforms are changing mobility.", confidence: 0.96, boundingBox: CGRect(x: 0.1, y: 0.65, width: 0.8, height: 0.04)),
            OCRTextLine(text: "• Faster update cycles", confidence: 0.94, boundingBox: CGRect(x: 0.12, y: 0.52, width: 0.5, height: 0.04)),
            OCRTextLine(text: "• Better diagnostics", confidence: 0.93, boundingBox: CGRect(x: 0.12, y: 0.45, width: 0.5, height: 0.04))
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)

        XCTAssertEqual(output, """
        # MARKET OUTLOOK

        Software platforms are changing mobility.

        - Faster update cycles
        - Better diagnostics
        """)
    }

    func testReadingOrderSortsRowsBeforeColumns() {
        let lines = [
            OCRTextLine(text: "right", confidence: 0.9, boundingBox: CGRect(x: 0.7, y: 0.7, width: 0.2, height: 0.04)),
            OCRTextLine(text: "bottom", confidence: 0.9, boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.04)),
            OCRTextLine(text: "left", confidence: 0.9, boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.04))
        ]

        let output = ImageMarkdownFormatter().readingOrder(lines).map(\.text)

        XCTAssertEqual(output, ["left", "right", "bottom"])
    }

    func testReadingOrderProcessesDetectedColumnsSequentially() {
        let lines = [
            OCRTextLine(text: "Left 1", confidence: 0.9, boundingBox: CGRect(x: 0.08, y: 0.8, width: 0.25, height: 0.04)),
            OCRTextLine(text: "Right 1", confidence: 0.9, boundingBox: CGRect(x: 0.62, y: 0.8, width: 0.25, height: 0.04)),
            OCRTextLine(text: "Left 2", confidence: 0.9, boundingBox: CGRect(x: 0.08, y: 0.7, width: 0.25, height: 0.04)),
            OCRTextLine(text: "Right 2", confidence: 0.9, boundingBox: CGRect(x: 0.62, y: 0.7, width: 0.25, height: 0.04))
        ]

        let output = ImageMarkdownFormatter().readingOrder(lines).map(\.text)

        XCTAssertEqual(output, ["Left 1", "Left 2", "Right 1", "Right 2"])
    }

    func testDetectsGridAsMarkdownTable() {
        // Simulate a 3×3 table with bounding boxes matching a real spreadsheet layout
        let lines = [
            // Header row  (y ≈ 0.85)
            OCRTextLine(text: "Name",    confidence: 0.99, boundingBox: CGRect(x: 0.02, y: 0.84, width: 0.17, height: 0.05)),
            OCRTextLine(text: "Q1",      confidence: 0.99, boundingBox: CGRect(x: 0.22, y: 0.84, width: 0.17, height: 0.05)),
            OCRTextLine(text: "Q2",      confidence: 0.99, boundingBox: CGRect(x: 0.42, y: 0.84, width: 0.17, height: 0.05)),
            // Row 1  (y ≈ 0.73)
            OCRTextLine(text: "Alpha",   confidence: 0.98, boundingBox: CGRect(x: 0.02, y: 0.72, width: 0.17, height: 0.05)),
            OCRTextLine(text: "$1,200",  confidence: 0.98, boundingBox: CGRect(x: 0.22, y: 0.72, width: 0.17, height: 0.05)),
            OCRTextLine(text: "$1,500",  confidence: 0.98, boundingBox: CGRect(x: 0.42, y: 0.72, width: 0.17, height: 0.05)),
            // Row 2  (y ≈ 0.61)
            OCRTextLine(text: "Beta",    confidence: 0.97, boundingBox: CGRect(x: 0.02, y: 0.60, width: 0.17, height: 0.05)),
            OCRTextLine(text: "$900",    confidence: 0.97, boundingBox: CGRect(x: 0.22, y: 0.60, width: 0.17, height: 0.05)),
            OCRTextLine(text: "$1,100",  confidence: 0.97, boundingBox: CGRect(x: 0.42, y: 0.60, width: 0.17, height: 0.05)),
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)
        let rows = output.split(separator: "\n").map(String.init)

        XCTAssertTrue(rows[0].hasPrefix("| Name"), "First row should be header")
        XCTAssertTrue(rows[1].contains("---"), "Second row should be separator")
        XCTAssertTrue(rows[2].contains("Alpha"), "Third row should be first data row")
        XCTAssertEqual(rows.filter { $0.hasPrefix("|") }.count, 4, "2 data rows + 1 header + 1 separator")
    }

    func testTableCellsWithBoldFlagGetWrapped() {
        let lines = [
            OCRTextLine(text: "Product", confidence: 0.99, boundingBox: CGRect(x: 0.02, y: 0.84, width: 0.17, height: 0.05), isBold: true),
            OCRTextLine(text: "Sales",   confidence: 0.99, boundingBox: CGRect(x: 0.25, y: 0.84, width: 0.17, height: 0.05), isBold: true),
            OCRTextLine(text: "Widget",  confidence: 0.98, boundingBox: CGRect(x: 0.02, y: 0.72, width: 0.17, height: 0.05), isBold: false),
            OCRTextLine(text: "$4,200",  confidence: 0.98, boundingBox: CGRect(x: 0.25, y: 0.72, width: 0.17, height: 0.05), isBold: false),
            OCRTextLine(text: "Gadget",  confidence: 0.98, boundingBox: CGRect(x: 0.02, y: 0.60, width: 0.17, height: 0.05), isBold: false),
            OCRTextLine(text: "$3,100",  confidence: 0.98, boundingBox: CGRect(x: 0.25, y: 0.60, width: 0.17, height: 0.05), isBold: false),
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)

        XCTAssertTrue(output.contains("**Product**"), "Bold header cell should be wrapped")
        XCTAssertTrue(output.contains("**Sales**"),   "Bold header cell should be wrapped")
        XCTAssertFalse(output.contains("**Widget**"), "Regular cell should not be wrapped")
    }

    func testBoldTextWrappedInRegularParagraph() {
        let lines = [
            OCRTextLine(text: "Introduction",  confidence: 0.99,
                        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.4, height: 0.08), isBold: true),
            OCRTextLine(text: "Normal body text that continues here.", confidence: 0.97,
                        boundingBox: CGRect(x: 0.1, y: 0.65, width: 0.8, height: 0.04)),
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)
        let outputLines = output.split(separator: "\n").map(String.init)

        // "Introduction" is tall (ratio ~2) so it becomes a heading — headings are not bold-wrapped
        XCTAssertTrue(outputLines.contains { $0.hasPrefix("#") && $0.contains("Introduction") },
                      "Tall bold line should become a heading, not **wrapped**")
        XCTAssertFalse(output.contains("**Introduction**"), "Headings should not be bold-wrapped")
    }

    func testIrregularLayoutNotDetectedAsTable() {
        // A slide with title + bullets has irregular Y spacing → should NOT be a table
        let lines = [
            OCRTextLine(text: "TITLE",   confidence: 0.99, boundingBox: CGRect(x: 0.1, y: 0.85, width: 0.8, height: 0.08)),
            OCRTextLine(text: "Body one",confidence: 0.97, boundingBox: CGRect(x: 0.1, y: 0.65, width: 0.8, height: 0.04)),
            OCRTextLine(text: "• Item A",confidence: 0.96, boundingBox: CGRect(x: 0.1, y: 0.52, width: 0.5, height: 0.04)),
            OCRTextLine(text: "• Item B",confidence: 0.95, boundingBox: CGRect(x: 0.1, y: 0.44, width: 0.5, height: 0.04)),
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)

        XCTAssertFalse(output.contains("| "), "Irregular layout should not be formatted as a table")
        XCTAssertTrue(output.contains("- Item A"), "Bullets should still be formatted")
    }

    func testHeadingLevelsUseRelativeLineHeight() {
        let lines = [
            OCRTextLine(text: "Document Title", confidence: 0.98, boundingBox: CGRect(x: 0.1, y: 0.85, width: 0.8, height: 0.12)),
            OCRTextLine(text: "Section Heading", confidence: 0.96, boundingBox: CGRect(x: 0.1, y: 0.72, width: 0.8, height: 0.08)),
            OCRTextLine(text: "Small Heading", confidence: 0.94, boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.8, height: 0.07)),
            OCRTextLine(text: "Body text for median.", confidence: 0.93, boundingBox: CGRect(x: 0.1, y: 0.45, width: 0.8, height: 0.04)),
            OCRTextLine(text: "Another body line.", confidence: 0.93, boundingBox: CGRect(x: 0.1, y: 0.38, width: 0.8, height: 0.04)),
            OCRTextLine(text: "Final body line.", confidence: 0.93, boundingBox: CGRect(x: 0.1, y: 0.31, width: 0.8, height: 0.04))
        ]

        let output = ImageMarkdownFormatter().markdown(from: lines)

        let outputLines = output.split(separator: "\n").map(String.init)
        XCTAssertTrue(outputLines.contains("# Document Title"), "Expected H1 for largest text")
        XCTAssertTrue(outputLines.contains("## Section Heading"), "Expected H2 for mid-size text")
        XCTAssertTrue(outputLines.contains("### Small Heading"), "Expected H3 for slightly-larger text")
    }
}
