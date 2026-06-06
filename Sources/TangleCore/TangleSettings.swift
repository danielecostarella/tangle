import Foundation

public enum TangleShortcutAction: String, Codable, Sendable, CaseIterable {
    case clipboardHistory
    case quickTransformPicker
    case cleanClipboard
    case cleanURL
    case markdown
    case pasteCleanedText

    public var label: String {
        switch self {
        case .clipboardHistory:
            return "Clipboard History"
        case .quickTransformPicker:
            return "Quick Transform Picker"
        case .cleanClipboard:
            return "Paste Clean Text"
        case .cleanURL:
            return "Clean URL"
        case .markdown:
            return "Paste Markdown"
        case .pasteCleanedText:
            return "Paste Cleaned Text"
        }
    }
}

public enum TangleShortcutKey: String, Codable, Sendable, CaseIterable {
    case c
    case u
    case m
    case v
    case x
    case b
    case k
    case p

    public var displayName: String {
        "⌃⌥⌘" + rawValue.uppercased()
    }
}

public struct TangleSettings: Codable, Equatable, Sendable {
    public var isHUDEnabled: Bool
    public var autoPasteAfterTransform: Bool
    public var autoTransformOnCopy: Bool
    public var autoTransformConfidenceThreshold: Double
    public var clipboardHistoryEnabled: Bool
    public var clipboardHistoryLimit: Int
    public var ocrMinimumConfidence: Float
    public var ocrRecognitionLanguages: [String]
    public var paragraphPreservation: ParagraphPreservation
    public var markdownPreset: MarkdownPreset
    public var shortcutKeys: [TangleShortcutAction: TangleShortcutKey]
    public var allowedURLParameters: Set<String>
    public var blockedURLParameters: Set<String>

    public init(
        isHUDEnabled: Bool = true,
        autoPasteAfterTransform: Bool = false,
        autoTransformOnCopy: Bool = false,
        autoTransformConfidenceThreshold: Double = 0.75,
        clipboardHistoryEnabled: Bool = false,
        clipboardHistoryLimit: Int = 20,
        ocrMinimumConfidence: Float = 0.35,
        ocrRecognitionLanguages: [String] = ["en-US", "it-IT"],
        paragraphPreservation: ParagraphPreservation = .balanced,
        markdownPreset: MarkdownPreset = .llm,
        shortcutKeys: [TangleShortcutAction: TangleShortcutKey] = TangleSettings.defaultShortcutKeys,
        allowedURLParameters: Set<String> = [],
        blockedURLParameters: Set<String> = URLCleaner.defaultBlockedParameters
    ) {
        self.isHUDEnabled = isHUDEnabled
        self.autoPasteAfterTransform = autoPasteAfterTransform
        self.autoTransformOnCopy = autoTransformOnCopy
        self.autoTransformConfidenceThreshold = autoTransformConfidenceThreshold
        self.clipboardHistoryEnabled = clipboardHistoryEnabled
        self.clipboardHistoryLimit = clipboardHistoryLimit
        self.ocrMinimumConfidence = ocrMinimumConfidence
        self.ocrRecognitionLanguages = ocrRecognitionLanguages
        self.paragraphPreservation = paragraphPreservation
        self.markdownPreset = markdownPreset
        self.shortcutKeys = shortcutKeys
        self.allowedURLParameters = allowedURLParameters
        self.blockedURLParameters = blockedURLParameters
    }

    private enum CodingKeys: String, CodingKey {
        case isHUDEnabled
        case autoPasteAfterTransform
        case autoTransformOnCopy
        case autoTransformConfidenceThreshold
        case clipboardHistoryEnabled
        case clipboardHistoryLimit
        case ocrMinimumConfidence
        case ocrRecognitionLanguages
        case paragraphPreservation
        case markdownPreset
        case shortcutKeys
        case allowedURLParameters
        case blockedURLParameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHUDEnabled) ?? true
        autoPasteAfterTransform = try container.decodeIfPresent(Bool.self, forKey: .autoPasteAfterTransform) ?? false
        autoTransformOnCopy = try container.decodeIfPresent(Bool.self, forKey: .autoTransformOnCopy) ?? false
        autoTransformConfidenceThreshold = try container.decodeIfPresent(Double.self, forKey: .autoTransformConfidenceThreshold) ?? 0.75
        clipboardHistoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .clipboardHistoryEnabled) ?? false
        clipboardHistoryLimit = try container.decodeIfPresent(Int.self, forKey: .clipboardHistoryLimit) ?? 20
        ocrMinimumConfidence = try container.decodeIfPresent(Float.self, forKey: .ocrMinimumConfidence) ?? 0.35
        ocrRecognitionLanguages = try container.decodeIfPresent([String].self, forKey: .ocrRecognitionLanguages) ?? ["en-US", "it-IT"]
        paragraphPreservation = try container.decodeIfPresent(ParagraphPreservation.self, forKey: .paragraphPreservation) ?? .balanced
        markdownPreset = try container.decodeIfPresent(MarkdownPreset.self, forKey: .markdownPreset) ?? .llm
        shortcutKeys = try container.decodeIfPresent([TangleShortcutAction: TangleShortcutKey].self, forKey: .shortcutKeys) ?? TangleSettings.defaultShortcutKeys
        allowedURLParameters = try container.decodeIfPresent(Set<String>.self, forKey: .allowedURLParameters) ?? []
        blockedURLParameters = try container.decodeIfPresent(Set<String>.self, forKey: .blockedURLParameters) ?? URLCleaner.defaultBlockedParameters
    }

    public static let defaultShortcutKeys: [TangleShortcutAction: TangleShortcutKey] = [
        .clipboardHistory: .b,
        .quickTransformPicker: .p,
        .cleanClipboard: .c,
        .cleanURL: .u,
        .markdown: .m,
        .pasteCleanedText: .v
    ]
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
