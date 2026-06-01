import XCTest
@testable import TangleCore

final class TableConverterTests: XCTestCase {
    func testConvertsTSVToMarkdownTable() {
        let input = """
        Name\tRole
        Tangle\tClipboard utility
        """

        let output = TableConverter().convert(input, to: .markdown)

        XCTAssertEqual(output, """
        | Name | Role |
        | --- | --- |
        | Tangle | Clipboard utility |
        """)
    }

    func testEscapesCSVValues() {
        let input = """
        Name\tDescription
        Tangle\tFast, local, "native"
        """

        let output = TableConverter().convert(input, to: .csv)

        XCTAssertEqual(output, "Name,Description\nTangle,\"Fast, local, \"\"native\"\"\"")
    }
}
