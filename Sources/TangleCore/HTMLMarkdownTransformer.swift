import Foundation

public struct HTMLMarkdownTransformer: Sendable {
    public var preset: MarkdownPreset
    public var paragraphPreservation: ParagraphPreservation

    public init(
        preset: MarkdownPreset = .standard,
        paragraphPreservation: ParagraphPreservation = .balanced
    ) {
        self.preset = preset
        self.paragraphPreservation = paragraphPreservation
    }

    public func transform(html: String, fallbackText: String) -> String {
        let markdown = convert(html)
        guard !markdown.isEmpty else {
            return MarkdownTransformer(
                preset: preset,
                paragraphPreservation: paragraphPreservation
            ).transform(fallbackText)
        }

        switch preset {
        case .standard:
            return markdown
        case .llm:
            return markdown.compactedMarkdown
        }
    }

    private func convert(_ html: String) -> String {
        var document = html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .removingMatches(for: #"(?is)<!--.*?-->"#)
            .removingMatches(for: #"(?is)<(script|style|noscript|svg)\b[^>]*>.*?</\1>"#)

        document = document.replacingMatches(for: #"(?is)<h([1-6])\b[^>]*>(.*?)</h\1>"#) { match in
            guard let level = Int(match.group(1)) else { return "" }
            let text = match.group(2).inlineMarkdown
            guard !text.isEmpty else { return "" }
            return "\n\n" + String(repeating: "#", count: level) + " " + text + "\n\n"
        }

        document = document.replacingMatches(for: #"(?is)<li\b[^>]*>(.*?)</li>"#) { match in
            let text = match.group(1).inlineMarkdown
            return text.isEmpty ? "\n" : "\n- \(text)\n"
        }

        document = document
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?i)</?(p|div|section|article|main|header|footer|aside|blockquote|ul|ol|table|tr|td|th)\b[^>]*>"#,
                with: "\n\n",
                options: .regularExpression
            )

        let lines = document
            .components(separatedBy: "\n")
            .map { $0.inlineMarkdown }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return lines.collapsingMarkdownBlankLines()
    }
}

public extension MarkdownTransformer {
    func transform(html: String, fallbackText: String) -> String {
        HTMLMarkdownTransformer(
            preset: preset,
            paragraphPreservation: paragraphPreservation
        ).transform(html: html, fallbackText: fallbackText)
    }
}

private extension String {
    var inlineMarkdown: String {
        var text = self

        text = text.replacingMatches(for: #"(?is)<a\b([^>]*)>(.*?)</a>"#) { match in
            let attributes = match.group(1)
            let label = match.group(2).inlineMarkdown
            guard let url = attributes.htmlAttribute(named: "href")?.decodedHTMLEntities,
                  !url.isEmpty,
                  !label.isEmpty else {
                return label
            }

            let cleanedURL = URLCleaner().cleanURLs(in: url)
            if label == cleanedURL {
                return cleanedURL
            }

            return "[\(label)](\(cleanedURL.escapedMarkdownURL))"
        }

        text = text.replacingMatches(for: #"(?is)<(strong|b)\b[^>]*>(.*?)</\1>"#) { match in
            let content = match.group(2).inlineMarkdown
            return content.isEmpty ? "" : "**\(content)**"
        }

        text = text.replacingMatches(for: #"(?is)<(em|i)\b[^>]*>(.*?)</\1>"#) { match in
            let content = match.group(2).inlineMarkdown
            return content.isEmpty ? "" : "*\(content)*"
        }

        return text
            .replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
            .decodedHTMLEntities
            .replacingOccurrences(of: #"[ \t\n]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removingMatches(for pattern: String) -> String {
        replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    func replacingMatches(for pattern: String, transform: (RegexMatch) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }

        let nsString = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length)).reversed()
        var output = self

        for match in matches {
            let replacement = transform(RegexMatch(match: match, source: nsString))
            if let range = Range(match.range, in: output) {
                output.replaceSubrange(range, with: replacement)
            }
        }

        return output
    }

    func htmlAttribute(named name: String) -> String? {
        let pattern = #"(?i)\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }

        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            if range.location != NSNotFound {
                return nsString.substring(with: range)
            }
        }

        return nil
    }

    var decodedHTMLEntities: String {
        var text = replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        text = text.replacingMatches(for: #"&#(\d+);"#) { match in
            guard let value = UInt32(match.group(1)),
                  let scalar = UnicodeScalar(value) else {
                return match.group(0)
            }
            return String(Character(scalar))
        }

        text = text.replacingMatches(for: #"&#x([0-9a-fA-F]+);"#) { match in
            guard let value = UInt32(match.group(1), radix: 16),
                  let scalar = UnicodeScalar(value) else {
                return match.group(0)
            }
            return String(Character(scalar))
        }

        return text
    }

    var escapedMarkdownURL: String {
        replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: " ", with: "%20")
    }

    var compactedMarkdown: String {
        replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func collapsingMarkdownBlankLines() -> String {
        var output: [String] = []
        var previousWasBlank = false

        for line in self {
            let isBlank = line.isEmpty
            if isBlank && previousWasBlank {
                continue
            }

            output.append(line)
            previousWasBlank = isBlank
        }

        return output
            .joined(separator: "\n")
            .compactedMarkdown
    }
}

private struct RegexMatch {
    var match: NSTextCheckingResult
    var source: NSString

    func group(_ index: Int) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return source.substring(with: range)
    }
}
