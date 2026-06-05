import AppKit
import Foundation
import PDFKit

public struct DocumentMarkdownTransformer: Sendable {
    public init() {}

    public func transformPDF(data: Data, preset: MarkdownPreset, paragraphPreservation: ParagraphPreservation) -> String? {
        guard let text = extractPDFText(data: data) else { return nil }

        return MarkdownTransformer(
            preset: preset,
            paragraphPreservation: paragraphPreservation
        ).transform(text)
    }

    public func extractPDFText(data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }

        let pageTexts = (0..<document.pageCount).compactMap { index in
            document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let text = pageTexts
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return text
    }

    public func transformRTF(data: Data, preset: MarkdownPreset, paragraphPreservation: ParagraphPreservation) -> String? {
        guard let attributed = attributedString(fromRTF: data) else { return nil }

        let markdown = attributedMarkdown(attributed)
        guard !markdown.isEmpty else { return nil }

        switch preset {
        case .standard:
            return markdown
        case .llm:
            return markdown.tangleCompactedMarkdown
        }
    }

    public func extractRTFText(data: Data) -> String? {
        guard let attributed = attributedString(fromRTF: data) else { return nil }
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func attributedString(fromRTF data: Data) -> NSAttributedString? {
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            return nil
        }

        return attributed
    }

    private func attributedMarkdown(_ attributed: NSAttributedString) -> String {
        var output = ""
        let fullRange = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let substring = attributed.attributedSubstring(from: range).string
            guard !substring.isEmpty else { return }

            let escaped = substring.normalizedRTFFragment
            let formatted = applyInlineMarkdown(escaped, attributes: attributes)
            output += formatted
        }

        return output
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .tangleCompactedMarkdown
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyInlineMarkdown(_ text: String, attributes: [NSAttributedString.Key: Any]) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }

        let font = attributes[.font] as? NSFont
        let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
        let isBold = traits.contains(.boldFontMask)
        let isItalic = traits.contains(.italicFontMask)

        let linkedText: String
        if let url = attributes[.link] as? URL {
            linkedText = "[\(text)](\(URLCleaner().cleanURLs(in: url.absoluteString).tangleEscapedMarkdownURL))"
        } else if let urlString = attributes[.link] as? String, !urlString.isEmpty {
            linkedText = "[\(text)](\(URLCleaner().cleanURLs(in: urlString).tangleEscapedMarkdownURL))"
        } else {
            linkedText = text
        }

        if isBold && isItalic { return "***\(linkedText)***" }
        if isBold { return "**\(linkedText)**" }
        if isItalic { return "_\(linkedText)_" }
        return linkedText
    }
}

private extension String {
    var normalizedRTFFragment: String {
        replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
    }

    var tangleEscapedMarkdownURL: String {
        replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: " ", with: "%20")
    }

    var tangleCompactedMarkdown: String {
        replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
