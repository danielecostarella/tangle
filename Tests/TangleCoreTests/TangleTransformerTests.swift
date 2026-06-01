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
}
