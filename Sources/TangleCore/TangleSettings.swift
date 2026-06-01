import Foundation

public struct TangleSettings: Codable, Equatable, Sendable {
    public var isHUDEnabled: Bool
    public var autoPasteAfterTransform: Bool
    public var paragraphPreservation: ParagraphPreservation
    public var allowedURLParameters: Set<String>
    public var blockedURLParameters: Set<String>

    public init(
        isHUDEnabled: Bool = true,
        autoPasteAfterTransform: Bool = false,
        paragraphPreservation: ParagraphPreservation = .balanced,
        allowedURLParameters: Set<String> = [],
        blockedURLParameters: Set<String> = URLCleaner.defaultBlockedParameters
    ) {
        self.isHUDEnabled = isHUDEnabled
        self.autoPasteAfterTransform = autoPasteAfterTransform
        self.paragraphPreservation = paragraphPreservation
        self.allowedURLParameters = allowedURLParameters
        self.blockedURLParameters = blockedURLParameters
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
