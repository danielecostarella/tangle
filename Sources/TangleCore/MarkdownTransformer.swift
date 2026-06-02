import Foundation

public enum MarkdownPreset: String, Codable, Sendable, CaseIterable {
    case standard
    case llm
}

public struct MarkdownTransformer: Sendable {
    public var preset: MarkdownPreset
    public var paragraphPreservation: ParagraphPreservation
    private let protectedHeadingMarker = "\u{E000}"

    public init(
        preset: MarkdownPreset = .standard,
        paragraphPreservation: ParagraphPreservation = .balanced
    ) {
        self.preset = preset
        self.paragraphPreservation = paragraphPreservation
    }

    public func transform(_ input: String) -> String {
        let structuredInput = protectWebHeadings(in: input)
        let cleaned = TextCleaner(paragraphPreservation: paragraphPreservation).clean(structuredInput)
        let lines = cleaned.components(separatedBy: "\n")
        let markdown = normalizeMarkdownLines(lines).joined(separator: "\n")

        switch preset {
        case .standard:
            return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        case .llm:
            return compactForLLM(markdown)
        }
    }

    private func protectWebHeadings(in input: String) -> String {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var output: [String] = []

        for index in lines.indices {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            let previous = previousNonEmptyLine(before: index, in: lines)
            let next = nextNonEmptyLine(after: index, in: lines)

            if line.looksLikeWebHeading(previous: previous, next: next) {
                if output.last?.isEmpty == false {
                    output.append("")
                }
                output.append(protectedHeadingMarker + line)
                output.append("")
            } else {
                output.append(lines[index])
            }
        }

        return output.joined(separator: "\n")
    }

    private func previousNonEmptyLine(before index: Int, in lines: [String]) -> String? {
        guard index > lines.startIndex else { return nil }

        for lineIndex in stride(from: index - 1, through: lines.startIndex, by: -1) {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                return line
            }
        }

        return nil
    }

    private func nextNonEmptyLine(after index: Int, in lines: [String]) -> String? {
        guard index < lines.index(before: lines.endIndex) else { return nil }

        for lineIndex in lines.index(after: index)..<lines.endIndex {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                return line
            }
        }

        return nil
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

        return joinProseLines(collapseBlankLines(output))
    }

    private func normalizeLine(_ line: String) -> String {
        if line.hasPrefix(protectedHeadingMarker) {
            return "### " + line.dropFirst(protectedHeadingMarker.count)
        }

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

    private func joinProseLines(_ lines: [String]) -> [String] {
        var output: [String] = []

        for line in lines {
            guard let previous = output.last,
                  !previous.isEmpty,
                  !line.isEmpty,
                  previous.isMarkdownProse,
                  line.isMarkdownProse else {
                output.append(line)
                continue
            }

            output[output.count - 1] = previous + " " + line
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

    func looksLikeWebHeading(previous: String?, next: String?) -> Bool {
        let line = trimmingCharacters(in: .whitespaces)
        guard line.count >= 4,
              line.count <= 95,
              next?.isEmpty == false,
              line.range(of: #"[A-Za-zÀ-ÖØ-öø-ÿ]"#, options: .regularExpression) != nil,
              line.range(of: #"https?://"#, options: .regularExpression) == nil,
              line.range(of: #"[.!?]$"#, options: .regularExpression) == nil,
              next?.range(of: #"^(=|-){3,}$"#, options: .regularExpression) == nil,
              !line.looksLikePlainHeading,
              !line.hasWeakContinuationEnding,
              !line.hasPrefix("#"),
              !line.hasPrefix("- "),
              !line.hasPrefix("* "),
              !line.hasPrefix("+ "),
              !line.hasPrefix(">"),
              !line.contains(" | "),
              !(line.contains(",") && !line.contains(":")) else {
            return false
        }

        if line.contains(":") {
            return line.first?.isUppercase == true
        }

        if let previous, previous.range(of: #"[.!?]$"#, options: .regularExpression) == nil, !previous.isEmpty {
            return false
        }

        return line.first?.isUppercase == true
            && line.split(separator: " ").count <= 12
    }

    var hasWeakContinuationEnding: Bool {
        guard let lastWord = split(separator: " ").last else { return false }

        let word = String(lastWord)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
        let weakEndings: Set<String> = [
            "a", "an", "and", "as", "at", "by", "for", "from", "in", "of", "on", "or", "the", "to", "with",
            "da", "del", "della", "delle", "dei", "degli", "di", "e", "gli", "i", "il", "in", "la", "le",
            "lo", "o", "per", "su", "tra", "un", "una"
        ]

        return weakEndings.contains(word)
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

    var isMarkdownProse: Bool {
        !hasPrefix("#")
            && !hasPrefix("- ")
            && !hasPrefix("* ")
            && !hasPrefix("+ ")
            && !hasPrefix("> ")
            && !hasPrefix("|")
            && !hasPrefix("```")
    }
}
