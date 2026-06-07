import AppKit
import Foundation
import PDFKit

public struct DocumentMarkdownTransformer: Sendable {
    public init() {}

    public func looksLikeExtractedPDFText(_ text: String) -> Bool {
        let pageMarkers = text.matches(
            #"(?i)\bpage\s+\d+(?:\s+of\s+\d+)?\b"#
        )
        guard pageMarkers >= 2 else { return false }

        let normalizedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).pageMarginIdentity }
            .filter { !$0.isEmpty && $0.count <= 120 }
        let repeatedLineCount = Dictionary(grouping: normalizedLines, by: { $0 })
            .values
            .filter { $0.count >= 2 }
            .count
        return repeatedLineCount >= 1
    }

    public func transformExtractedPDFText(
        _ text: String,
        preset: MarkdownPreset,
        paragraphPreservation: ParagraphPreservation
    ) -> String {
        let pages = splitExtractedPDFTextIntoPages(text)
        let cleaned = removeRepeatedPageMargins(from: pages)
            .map { $0.joined(separator: "\n") }
            .joined(separator: "\n\n")

        return MarkdownTransformer(
            preset: preset,
            paragraphPreservation: paragraphPreservation,
            inferUnmarkedHeadings: false
        ).transform(structurePDFText(cleaned))
    }

    public func transformPDF(data: Data, preset: MarkdownPreset, paragraphPreservation: ParagraphPreservation) -> String? {
        guard let text = extractPDFText(data: data) else { return nil }

        return MarkdownTransformer(
            preset: preset,
            paragraphPreservation: paragraphPreservation,
            inferUnmarkedHeadings: false
        ).transform(structurePDFText(text))
    }

    public func extractPDFText(data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }

        let pageLines = (0..<document.pageCount).compactMap { index -> [String]? in
            guard let text = document.page(at: index)?.string else { return nil }
            return text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let cleanedPages = removeRepeatedPageMargins(from: pageLines)
        let text = cleanedPages
            .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return text
    }

    public func rasterizedPDFPages(data: Data, maximumPages: Int = 20) -> [Data] {
        guard let document = PDFDocument(data: data) else { return [] }

        return (0..<min(document.pageCount, maximumPages)).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let width: CGFloat = 1_800
            let height = max(width * bounds.height / max(bounds.width, 1), 1)
            let image = page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
            return image.tiffRepresentation
        }
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

    private func removeRepeatedPageMargins(from pages: [[String]]) -> [[String]] {
        guard pages.count >= 2 else { return pages }

        let marginLines = pages.flatMap { page -> Set<String> in
            let nonEmpty = page.filter { !$0.isEmpty }
            return Set((Array(nonEmpty.prefix(3)) + Array(nonEmpty.suffix(3))).map(\.pageMarginIdentity))
        }
        let counts = Dictionary(grouping: marginLines, by: { $0 }).mapValues(\.count)
        let repeated = Set<String>(counts.compactMap { line, count in
            guard count >= 2, !line.isEmpty, line.count <= 120 else { return nil }
            return line
        })

        return pages.map { page in
            page.filter { line in
                if line.range(of: #"^(page\s+)?\d+(\s+of\s+\d+)?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    return false
                }
                return !repeated.contains(line.pageMarginIdentity)
            }
        }
    }

    private func splitExtractedPDFTextIntoPages(_ text: String) -> [[String]] {
        let lines = text.components(separatedBy: .newlines)
        var pages: [[String]] = [[]]

        for line in lines {
            pages[pages.count - 1].append(line)
            if line.range(
                of: #"\bpage\s+\d+(?:\s+of\s+\d+)?\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                pages.append([])
            }
        }

        return pages.filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }

    private func structurePDFText(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let firstContentIndex = lines.firstIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return lines.enumerated().map { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return "" }

            if index == firstContentIndex,
               line.isLikelyPDFTitle(nextLine: lines.dropFirst(index + 1).first) {
                return "# " + line
            }

            if let match = line.firstMatch(of: /^(\d+(?:\.\d+)*)[.)]?\s+(.+)$/) {
                let depth = match.1.split(separator: ".").count
                let heading = String(match.2)
                if heading.count <= 100, !heading.hasSuffix(".") {
                    return String(repeating: "#", count: min(depth + 1, 4)) + " " + heading
                }
            }

            if let match = line.firstMatch(of: /^(\d+)[.)]\s+(.+)$/),
               String(match.2).count > 20 {
                return "[^\(match.1)]: \(match.2)"
            }

            return line.replacingOccurrences(
                of: #"([.!?])(\d{1,3})$"#,
                with: "$1[^$2]",
                options: .regularExpression
            )
        }.joined(separator: "\n")
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
        if text.contains("\n") {
            return text
                .components(separatedBy: "\n")
                .map { line in
                    line.isEmpty ? "" : applyInlineMarkdown(line, attributes: attributes)
                }
                .joined(separator: "\n")
        }

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
    func matches(_ pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.numberOfMatches(in: self, range: range)
    }

    var pageMarginIdentity: String {
        replacingOccurrences(
            of: #"\bpage\s+\d+(?:\s+of\s+\d+)?\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    }

    func isLikelyPDFTitle(nextLine: String?) -> Bool {
        let words = split(whereSeparator: \.isWhitespace)
        guard count >= 3,
              count <= 120,
              words.count <= 12,
              !hasSuffix("."),
              !hasPrefix("#"),
              !contains(",") else {
            return false
        }

        let isAllCaps = uppercased() == self
        let followedByBlankLine = nextLine?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        return isAllCaps || followedByBlankLine
    }

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
