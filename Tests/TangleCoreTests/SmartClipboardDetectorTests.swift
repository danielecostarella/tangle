import XCTest
@testable import TangleCore

final class SmartClipboardDetectorTests: XCTestCase {
    func testDetectsRichHTMLAsMarkdown() {
        let content = ClipboardContent(text: "Plain text", html: "<h1>Title</h1>")
        let detection = SmartClipboardDetector().detect(content)

        XCTAssertEqual(detection.kind, .richHTML)
        XCTAssertEqual(detection.recommendedTransformation, .markdown)
    }

    func testDetectsImageClipboardAsImageMarkdown() {
        let content = ClipboardContent(text: "", imageData: Data([0x00, 0x01]))
        let detection = SmartClipboardDetector().detect(content)

        XCTAssertEqual(detection.kind, .image)
        XCTAssertEqual(detection.recommendedTransformation, .imageMarkdown)
        XCTAssertEqual(detection.confidence, 0.9)
    }

    func testDetectsURLFocusedClipboard() {
        let detection = SmartClipboardDetector().detect("https://example.com/?utm_source=x&id=42")

        XCTAssertEqual(detection.kind, .url)
        XCTAssertEqual(detection.recommendedTransformation, .cleanURL)
    }

    func testDetectsTabularClipboard() {
        let detection = SmartClipboardDetector().detect("""
        Name\tScore
        Alpha\t42
        Beta\t17
        """)

        XCTAssertEqual(detection.kind, .table)
        XCTAssertEqual(detection.recommendedTransformation, .tableMarkdown)
    }

    func testSmartTransformRoutesToDetectedTransformation() {
        let output = TangleTransformer().transform("""
        Name\tScore
        Alpha\t42
        """, kind: .smart)

        XCTAssertEqual(output, """
        | Name | Score |
        | --- | --- |
        | Alpha | 42 |
        """)
    }

    func testDetectsFlattenedDatasheetTable() {
        let input = "Power Consumption Symbol Description Min Typ Max Unit VINMax Maximum input voltage from VIN pad 6 - 20 V VUSBMax Maximum input voltage from USB connector - 5.5 V PMax Maximum Power Consumption - - xx mA"

        let detection = SmartClipboardDetector().detect(input)

        XCTAssertEqual(detection.kind, .table)
        XCTAssertEqual(detection.recommendedTransformation, .tableMarkdown)
    }
}
