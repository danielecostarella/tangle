import Foundation

public struct TangleSettings: Codable, Equatable, Sendable {
    public var isHUDEnabled: Bool
    public var autoPasteAfterTransform: Bool
    public var paragraphPreservation: ParagraphPreservation
    public var markdownPreset: MarkdownPreset
    public var allowedURLParameters: Set<String>
    public var blockedURLParameters: Set<String>

    public init(
        isHUDEnabled: Bool = true,
        autoPasteAfterTransform: Bool = false,
        paragraphPreservation: ParagraphPreservation = .balanced,
        markdownPreset: MarkdownPreset = .llm,
        allowedURLParameters: Set<String> = [],
        blockedURLParameters: Set<String> = URLCleaner.defaultBlockedParameters
    ) {
        self.isHUDEnabled = isHUDEnabled
        self.autoPasteAfterTransform = autoPasteAfterTransform
        self.paragraphPreservation = paragraphPreservation
        self.markdownPreset = markdownPreset
        self.allowedURLParameters = allowedURLParameters
        self.blockedURLParameters = blockedURLParameters
    }

    private enum CodingKeys: String, CodingKey {
        case isHUDEnabled
        case autoPasteAfterTransform
        case paragraphPreservation
        case markdownPreset
        case allowedURLParameters
        case blockedURLParameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHUDEnabled) ?? true
        autoPasteAfterTransform = try container.decodeIfPresent(Bool.self, forKey: .autoPasteAfterTransform) ?? false
        paragraphPreservation = try container.decodeIfPresent(ParagraphPreservation.self, forKey: .paragraphPreservation) ?? .balanced
        markdownPreset = try container.decodeIfPresent(MarkdownPreset.self, forKey: .markdownPreset) ?? .llm
        allowedURLParameters = try container.decodeIfPresent(Set<String>.self, forKey: .allowedURLParameters) ?? []
        blockedURLParameters = try container.decodeIfPresent(Set<String>.self, forKey: .blockedURLParameters) ?? URLCleaner.defaultBlockedParameters
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "TangleSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> TangleSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(TangleSettings.self, from: data) else {
            return TangleSettings()
        }

        return settings
    }

    public func save(_ settings: TangleSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
