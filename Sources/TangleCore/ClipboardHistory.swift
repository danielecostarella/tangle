import Foundation

public struct ClipboardHistoryItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let capturedAt: Date

    public init(id: UUID = UUID(), text: String, capturedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
    }

    public var preview: String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ClipboardHistory: Sendable {
    public private(set) var items: [ClipboardHistoryItem] = []
    public var limit: Int {
        didSet {
            limit = Self.validatedLimit(limit)
            trimToLimit()
        }
    }

    public init(limit: Int = 20) {
        self.limit = Self.validatedLimit(limit)
    }

    @discardableResult
    public mutating func record(_ text: String, capturedAt: Date = Date()) -> ClipboardHistoryItem? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 250_000 else { return nil }

        if items.first?.text == normalized {
            return nil
        }

        items.removeAll { $0.text == normalized }
        let item = ClipboardHistoryItem(text: normalized, capturedAt: capturedAt)
        items.insert(item, at: 0)
        trimToLimit()
        return item
    }

    public mutating func clear() {
        items.removeAll()
    }

    public func search(_ query: String) -> [ClipboardHistoryItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    private static func validatedLimit(_ limit: Int) -> Int {
        min(max(limit, 5), 100)
    }

    private mutating func trimToLimit() {
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
    }
}

public struct ClipboardHistoryPrivacyPolicy: Sendable {
    public init() {}

    public func shouldRecord(
        text: String,
        isSensitive: Bool = false,
        sourceBundleIdentifier: String? = nil
    ) -> Bool {
        guard !isSensitive,
              !Self.passwordManagerBundleIdentifiers.contains(sourceBundleIdentifier ?? "") else {
            return false
        }

        if text.looksLikeURL {
            return true
        }

        guard !text.looksLikeSecretFragment else { return false }
        return true
    }

    public static let passwordManagerBundleIdentifiers: Set<String> = [
        "com.1password.1password",
        "com.1password.1password7",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.getdropbox.DropboxPasswordManager",
        "com.keepassx.keepassxc"
    ]
}

private extension String {
    var looksLikeURL: Bool {
        guard let url = URL(string: self),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    var looksLikeSecretFragment: Bool {
        guard !contains(where: \.isWhitespace), count >= 8 else { return false }

        let hasDigit = range(of: #"[0-9]"#, options: .regularExpression) != nil
        let hasSymbol = range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil
        let knownSecretPrefix = range(
            of: #"^(sk-|ghp_|github_pat_|xox[baprs]-|AKIA|eyJ)"#,
            options: .regularExpression
        ) != nil
        return knownSecretPrefix || (hasDigit && hasSymbol)
    }
}
