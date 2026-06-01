import Foundation

public enum MarkdownPreset: String, Sendable, CaseIterable {
    case standard
    case llm
}

public struct MarkdownTransformer: Sendable {
    public var preset: MarkdownPreset
    public var paragraphPreservation: ParagraphPreservation

    public init(
        preset: MarkdownPreset = .standard,
        paragraphPreservation: ParagraphPreservation = .balanced
    ) {
        self.preset = preset
        self.paragraphPreservation = paragraphPreservation
    }

    public func transform(_ input: String) -> String {
        let cleaned = TextCleaner(paragraphPreservation: paragraphPreservation).clean(input)
        let lines = cleaned.components(separatedBy: "\n")
        let markdown = normalizeMarkdownLines(lines).joined(separator: "\n")

        switch preset {
        case .standard:
            return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        case .llm:
            return compactForLLM(markdown)
        }
    }

    private func normalizeMarkdownLines(_ lines: [String]) -> [String] {
        var output: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            if index + 1 < lines.count {
                let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if isUnderlineHeading(next), !line.isEmpty {
                    output.append((next.first == "=" ? "# " : "## ") + normalizedHeading(line))
                    index += 2
                    continue
                }
            }

            output.append(normalizeLine(line))
            index += 1
        }

        return collapseBlankLines(output)
    }

    private func normalizeLine(_ line: String) -> String {
        if line.range(of: #"^[•·▪‣]\s+"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(
                of: #"^[•·▪‣]\s+"#,
                with: "- ",
                options: .regularExpression
            )
        }

        if line.range(of: #"^[–—]\s+"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(
                of: #"^[–—]\s+"#,
                with: "- ",
                options: .regularExpression
            )
        }

        if line.looksLikePlainHeading {
            return "## " + line.capitalizedHeading
        }

        return line
    }

    private func normalizedHeading(_ line: String) -> String {
        line.looksLikePlainHeading ? line.capitalizedHeading : line
    }

    private func isUnderlineHeading(_ line: String) -> Bool {
        line.range(of: #"^(=|-){3,}$"#, options: .regularExpression) != nil
    }

    private func collapseBlankLines(_ lines: [String]) -> [String] {
        var output: [String] = []
        var previousWasBlank = false

        for line in lines {
            let isBlank = line.isEmpty
            if isBlank && previousWasBlank {
                continue
            }

            output.append(line)
            previousWasBlank = isBlank
        }

        return output
    }

    private func compactForLLM(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var looksLikePlainHeading: Bool {
        count >= 3
            && count <= 70
            && uppercased() == self
            && range(of: #"[A-ZÀ-ÖØ-Þ]"#, options: .regularExpression) != nil
            && range(of: #"^\d+$"#, options: .regularExpression) == nil
    }

    var capitalizedHeading: String {
        split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                guard let first = lower.first else { return "" }
                return first.uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }
}
