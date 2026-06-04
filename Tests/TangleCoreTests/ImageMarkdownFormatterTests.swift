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
        ## MARKET OUTLOOK

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
}
