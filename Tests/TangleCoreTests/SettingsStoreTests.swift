import XCTest
@testable import TangleCore

final class SettingsStoreTests: XCTestCase {
    func testLoadsDefaultsWhenNothingWasSaved() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.load(), TangleSettings())
    }

    func testSavesAndLoadsSettings() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        let settings = TangleSettings(
            isHUDEnabled: false,
            autoPasteAfterTransform: true,
            paragraphPreservation: .aggressive,
            markdownPreset: .standard,
            allowedURLParameters: ["id"],
            blockedURLParameters: ["utm_source"]
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesOlderSettingsWithoutMarkdownPreset() throws {
        let json = """
        {
          "isHUDEnabled": false,
          "autoPasteAfterTransform": true,
          "paragraphPreservation": "conservative",
          "allowedURLParameters": ["id"],
          "blockedURLParameters": ["utm_source"]
        }
        """

        let settings = try JSONDecoder().decode(TangleSettings.self, from: Data(json.utf8))

        XCTAssertFalse(settings.isHUDEnabled)
        XCTAssertTrue(settings.autoPasteAfterTransform)
        XCTAssertEqual(settings.paragraphPreservation, .conservative)
        XCTAssertEqual(settings.markdownPreset, .llm)
        XCTAssertEqual(settings.allowedURLParameters, ["id"])
        XCTAssertEqual(settings.blockedURLParameters, ["utm_source"])
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "TangleSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
