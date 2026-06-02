import Foundation
import SwiftSoup

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
        let markdown = (try? DOMMarkdownRenderer().render(html)) ?? ""
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
}

public extension MarkdownTransformer {
    func transform(html: String, fallbackText: String) -> String {
        HTMLMarkdownTransformer(
            preset: preset,
            paragraphPreservation: paragraphPreservation
        ).transform(html: html, fallbackText: fallbackText)
    }
}

private struct DOMMarkdownRenderer {
    func render(_ html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        try document.select("script, style, noscript, svg").remove()

        let root: Element = document.body() ?? document
        return try renderChildren(of: root)
            .compactedMarkdown
    }

    private func renderChildren(of node: Node) throws -> String {
        try node.childNodesCopy()
            .map(renderBlockNode)
            .joined(separator: "\n")
            .compactedMarkdown
    }

    private func renderBlockNode(_ node: Node) throws -> String {
        if let text = node as? TextNode {
            return normalizeInlineWhitespace(text.getWholeText())
        }

        guard let element = node as? Element else { return "" }
        let tag = element.tagNameNormal()

        switch tag {
        case "html", "body":
            return try renderChildren(of: element)
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 2
            let text = try renderInlineChildren(of: element)
            return text.isEmpty ? "" : "\n\n" + String(repeating: "#", count: level) + " " + text + "\n\n"
        case "p":
            return try block(renderInlineChildren(of: element))
        case "div", "section", "article", "main", "header", "footer", "aside":
            return try block(renderChildren(of: element))
        case "br":
            return "\n"
        case "pre":
            return try renderCodeBlock(element)
        case "ul":
            return try renderList(element, ordered: false, depth: 0)
        case "ol":
            return try renderList(element, ordered: true, depth: 0)
        case "blockquote":
            return try renderBlockquote(element)
        case "table":
            return try renderTable(element)
        case "hr":
            return "\n\n---\n\n"
        default:
            return try renderInlineNode(element)
        }
    }

    private func renderInlineChildren(of node: Node) throws -> String {
        try node.childNodesCopy()
            .map(renderInlineNode)
            .joined()
            .normalizedInlineMarkdown
    }

    private func renderInlineNode(_ node: Node) throws -> String {
        if let text = node as? TextNode {
            return normalizeInlineWhitespace(text.getWholeText())
        }

        guard let element = node as? Element else { return "" }
        let tag = element.tagNameNormal()

        switch tag {
        case "br":
            return "\n"
        case "strong", "b":
            return try wrapInline(element, marker: "**")
        case "em", "i":
            return try wrapInline(element, marker: "*")
        case "a":
            return try renderLink(element)
        case "code", "kbd", "samp":
            return try renderInlineCode(element)
        case "img":
            let alt = try element.attr("alt").trimmingCharacters(in: .whitespacesAndNewlines)
            return alt.isEmpty ? "" : alt
        case "script", "style", "noscript", "svg":
            return ""
        default:
            return try renderInlineChildren(of: element)
        }
    }

    private func wrapInline(_ element: Element, marker: String) throws -> String {
        let content = try renderInlineChildren(of: element)
        return content.isEmpty ? "" : marker + content + marker
    }

    private func renderLink(_ element: Element) throws -> String {
        let label = try renderInlineChildren(of: element)
        let href = try element.attr("href")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !href.isEmpty else { return label }

        let cleanedURL = URLCleaner().cleanURLs(in: href)
        if label == cleanedURL {
            return cleanedURL
        }

        return "[\(label)](\(cleanedURL.escapedMarkdownURL))"
    }

    private func renderInlineCode(_ element: Element) throws -> String {
        let content = try element.text(trimAndNormaliseWhitespace: false)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return "" }

        let marker = content.contains("`") ? "``" : "`"
        return marker + content + marker
    }

    private func renderCodeBlock(_ element: Element) throws -> String {
        let codeElement = try element.select("code").first()
        let content = try (codeElement ?? element)
            .text(trimAndNormaliseWhitespace: false)
            .trimmingCharacters(in: .newlines)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        return "\n\n```\n\(content)\n```\n\n"
    }

    private func renderList(_ element: Element, ordered: Bool, depth: Int) throws -> String {
        var lines: [String] = []
        var index = 1

        for child in element.children().array() where child.tagNameNormal() == "li" {
            let item = try renderListItem(child, ordered: ordered, index: index, depth: depth)
            if !item.isEmpty {
                lines.append(item)
            }
            index += 1
        }

        return lines.joined(separator: "\n")
    }

    private func renderListItem(_ element: Element, ordered: Bool, index: Int, depth: Int) throws -> String {
        var inlineParts: [String] = []
        var nestedLists: [String] = []

        for child in element.childNodesCopy() {
            if let childElement = child as? Element {
                switch childElement.tagNameNormal() {
                case "ul":
                    nestedLists.append(try renderList(childElement, ordered: false, depth: depth + 1))
                    continue
                case "ol":
                    nestedLists.append(try renderList(childElement, ordered: true, depth: depth + 1))
                    continue
                case "p":
                    inlineParts.append(try renderInlineChildren(of: childElement))
                    continue
                default:
                    break
                }
            }

            inlineParts.append(try renderInlineNode(child))
        }

        let text = inlineParts.joined(separator: " ").normalizedInlineMarkdown
        let indent = String(repeating: "  ", count: depth)
        let marker = ordered ? "\(index)." : "-"
        var output = text.isEmpty ? "" : "\(indent)\(marker) \(text)"

        let nested = nestedLists
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if !nested.isEmpty {
            output += output.isEmpty ? nested : "\n" + nested
        }

        return output
    }

    private func renderBlockquote(_ element: Element) throws -> String {
        let content = try renderChildren(of: element)
            .compactedMarkdown
        guard !content.isEmpty else { return "" }

        let quoted = content
            .components(separatedBy: "\n")
            .map { line in line.isEmpty ? ">" : "> " + line }
            .joined(separator: "\n")
        return "\n\n\(quoted)\n\n"
    }

    private func renderTable(_ element: Element) throws -> String {
        let rows = try element.select("tr").array().compactMap { row -> [String]? in
            let cells = try row.select("th, td").array().map { cell in
                try renderInlineChildren(of: cell)
            }
            return cells.isEmpty ? nil : cells
        }
        guard !rows.isEmpty else { return "" }

        let width = rows.map(\.count).max() ?? 0
        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, width - row.count))
        }
        let tsv = normalizedRows
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
        return "\n\n" + TableConverter().convert(tsv, to: .markdown) + "\n\n"
    }

    private func block(_ content: String) -> String {
        let text = content.compactedMarkdown
        return text.isEmpty ? "" : "\n\n\(text)\n\n"
    }

    private func normalizeInlineWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"[ \t\n]+"#, with: " ", options: .regularExpression)
    }
}

private extension String {
    var escapedMarkdownURL: String {
        replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: " ", with: "%20")
    }

    var normalizedInlineMarkdown: String {
        replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #" ?\n ?"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var compactedMarkdown: String {
        replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
