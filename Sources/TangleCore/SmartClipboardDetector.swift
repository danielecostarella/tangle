import Foundation

public enum DetectedClipboardContentKind: String, Sendable, Codable, CaseIterable {
    case image
    case document
    case richHTML
    case url
    case table
    case code
    case markdown
    case text
}

public struct SmartClipboardDetection: Sendable, Equatable {
    public var kind: DetectedClipboardContentKind
    public var confidence: Double
    public var recommendedTransformation: TransformationKind

    public init(
        kind: DetectedClipboardContentKind,
        confidence: Double,
        recommendedTransformation: TransformationKind
    ) {
        self.kind = kind
        self.confidence = confidence
        self.recommendedTransformation = recommendedTransformation
    }
}

public struct SmartClipboardDetector: Sendable {
    public init() {}

    public func detect(_ content: ClipboardContent) -> SmartClipboardDetection {
        if let html = content.html?.trimmingCharacters(in: .whitespacesAndNewlines), !html.isEmpty {
            return SmartClipboardDetection(kind: .richHTML, confidence: 0.95, recommendedTransformation: .markdown)
        }

        if content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, content.hasRichDocument {
            return SmartClipboardDetection(kind: .document, confidence: 0.85, recommendedTransformation: .markdown)
        }

        if content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, content.hasImage {
            return SmartClipboardDetection(kind: .image, confidence: 0.9, recommendedTransformation: .imageMarkdown)
        }

        return detect(content.text)
    }

    public func detect(_ text: String) -> SmartClipboardDetection {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if isURLFocused(trimmed) {
            return SmartClipboardDetection(kind: .url, confidence: 0.9, recommendedTransformation: .cleanURL)
        }

        if looksLikeTable(trimmed) {
            return SmartClipboardDetection(kind: .table, confidence: 0.85, recommendedTransformation: .tableMarkdown)
        }

        if looksLikeCode(trimmed) {
            return SmartClipboardDetection(kind: .code, confidence: 0.75, recommendedTransformation: .markdown)
        }

        if looksLikeMarkdown(trimmed) {
            return SmartClipboardDetection(kind: .markdown, confidence: 0.7, recommendedTransformation: .markdown)
        }

        return SmartClipboardDetection(kind: .text, confidence: 0.55, recommendedTransformation: .cleanText)
    }

    private func isURLFocused(_ text: String) -> Bool {
        guard !text.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"\]]+"#) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return false }

        let urlCharacterCount = matches.reduce(0) { $0 + $1.range.length }
        return Double(urlCharacterCount) / Double(max(text.utf16.count, 1)) > 0.65
    }

    private func looksLikeTable(_ text: String) -> Bool {
        let rows = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard rows.count >= 2 else { return false }

        let separator: Character? = rows.contains { $0.contains("\t") } ? "\t" : ","
        let columnCounts = rows.map { row in
            separator.map { row.split(separator: $0, omittingEmptySubsequences: false).count } ?? 0
        }

        guard let first = columnCounts.first, first > 1 else { return false }
        return columnCounts.allSatisfy { $0 == first }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let indicators = [
            #"(?m)^\s*(import|class|struct|func|let|var|const|async|await)\b"#,
            #"[{};]"#,
            #"(?m)^\s*```"#
        ]

        return indicators.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private func looksLikeMarkdown(_ text: String) -> Bool {
        let indicators = [
            #"(?m)^#{1,6}\s+\S"#,
            #"(?m)^[-*+]\s+\S"#,
            #"\[[^\]]+\]\([^)]+\)"#,
            #"(?m)^\|.+\|$"#
        ]

        return indicators.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
