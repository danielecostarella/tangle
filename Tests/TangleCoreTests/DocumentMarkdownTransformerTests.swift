import AppKit
import PDFKit
import XCTest
@testable import TangleCore

final class DocumentMarkdownTransformerTests: XCTestCase {
    func testRTFMarkdownPreservesBoldAndLinks() throws {
        let attributed = NSMutableAttributedString(string: "Rich link")
        attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 4))
        attributed.addAttribute(.link, value: "https://example.com/?utm_source=x&id=42", range: NSRange(location: 5, length: 4))
        let data = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        let content = ClipboardContent(text: "", rtfData: data)
        let markdown = try TangleTransformer().transformContent(content, kind: .markdown)
        let plainText = try TangleTransformer().transformContent(content, kind: .smartText)

        XCTAssertEqual(markdown, "**Rich** [link](https://example.com/?id=42)")
        XCTAssertEqual(plainText, "Rich link")
    }

    func testPDFMarkdownUsesTextLayer() throws {
        let data = try makeTextPDF("REPORT TITLE\n\nText copied\nfrom a PDF.")
        let content = ClipboardContent(text: "", pdfData: data)
        let markdown = try TangleTransformer(settings: TangleSettings(markdownPreset: .llm)).transformContent(content, kind: .markdown)

        XCTAssertEqual(markdown, """
        ## Report Title
        Text copied from a PDF.
        """)
    }

    func testSmartDetectsDocumentClipboard() {
        let content = ClipboardContent(text: "", rtfData: Data([0x7b, 0x5c, 0x72, 0x74, 0x66]))
        let detection = SmartClipboardDetector().detect(content)

        XCTAssertEqual(detection.kind, .document)
        XCTAssertEqual(detection.recommendedTransformation, .markdown)
    }

    private func makeTextPDF(_ text: String) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw XCTSkip("Unable to create PDF context")
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSString(string: text).draw(
            in: CGRect(x: 72, y: 620, width: 460, height: 120),
            withAttributes: [.font: NSFont.systemFont(ofSize: 18)]
        )
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        return data as Data
    }
}
