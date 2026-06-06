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
