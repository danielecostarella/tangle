import XCTest
@testable import TangleCore

final class ClipboardHistoryTests: XCTestCase {
    func testKeepsNewestItemsWithinLimit() {
        var history = ClipboardHistory(limit: 5)

        for number in 1...7 {
            history.record("Item \(number)")
        }

        XCTAssertEqual(history.items.map(\.text), ["Item 7", "Item 6", "Item 5", "Item 4", "Item 3"])
    }

    func testMovesDuplicateToFrontWithoutKeepingCopies() {
        var history = ClipboardHistory()
        history.record("First")
        history.record("Second")
        history.record("First")

        XCTAssertEqual(history.items.map(\.text), ["First", "Second"])
    }

    func testRejectsEmptyAndOversizedItems() {
        var history = ClipboardHistory()

        XCTAssertNil(history.record("   "))
        XCTAssertNil(history.record(String(repeating: "x", count: 250_001)))
        XCTAssertTrue(history.items.isEmpty)
    }

    func testSearchIsCaseInsensitive() {
        var history = ClipboardHistory()
        history.record("Quarterly Report")
        history.record("Meeting notes")

        XCTAssertEqual(history.search("REPORT").map(\.text), ["Quarterly Report"])
    }

    func testPrivacyPolicyRejectsSensitiveAndPasswordManagerContent() {
        let policy = ClipboardHistoryPrivacyPolicy()

        XCTAssertFalse(policy.shouldRecord(text: "normal text", isSensitive: true))
        XCTAssertFalse(policy.shouldRecord(text: "normal text", sourceBundleIdentifier: "com.1password.1password"))
        XCTAssertFalse(policy.shouldRecord(text: "Abcd1234!"))
        XCTAssertFalse(policy.shouldRecord(text: "sk-proj-exampletoken"))
        XCTAssertTrue(policy.shouldRecord(text: "A normal clipboard paragraph."))
        XCTAssertTrue(policy.shouldRecord(text: "https://example.com/report?id=42"))
    }
}
