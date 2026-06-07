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

    func testReconstructsFlattenedDatasheetTable() {
        let input = "Power Consumption Symbol Description Min Typ Max Unit VINMax Maximum input voltage from VIN pad 6 - 20 V VUSBMax Maximum input voltage from USB connector - 5.5 V PMax Maximum Power Consumption - - xx mA"

        let output = TableConverter().convert(input, to: .markdown)

        XCTAssertEqual(output, """
        | Symbol | Description | Min | Typ | Max | Unit |
        | --- | --- | --- | --- | --- | --- |
        | VINMax | Maximum input voltage from VIN pad | 6 | - | 20 | V |
        | VUSBMax | Maximum input voltage from USB connector |  | - | 5.5 | V |
        | PMax | Maximum Power Consumption | - | - | xx | mA |
        """)
    }

    func testDoesNotInventDatasheetTableFromOrdinaryText() {
        let input = "The Symbol Description Min Typ Max Unit labels are discussed in this paragraph."

        XCTAssertNil(TableConverter().reconstructedDatasheetRows(in: input))
        XCTAssertEqual(TableConverter().convert(input, to: .markdown), input)
    }

    func testDoesNotTreatInconsistentCommaSeparatedProseAsTable() {
        let input = "A sentence, with a comma.\nAnother sentence, with, several commas."

        XCTAssertFalse(TableConverter().looksLikeTable(input))
    }
}
