import Foundation

public enum ParagraphPreservation: String, Codable, Sendable, CaseIterable {
    case conservative
    case balanced
    case aggressive
}

public struct TextCleaner: Sendable {
    public var paragraphPreservation: ParagraphPreservation

    public init(paragraphPreservation: ParagraphPreservation = .conservative) {
        self.paragraphPreservation = paragraphPreservation
    }

    public func clean(_ input: String) -> String {
        let normalized = repairHyphenatedLineBreaks(normalizeScalars(input))
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = removeRepeatedNoiseLines(from: normalized
            .components(separatedBy: "\n")
            .map { normalizeInlineWhitespace($0).trimmingCharacters(in: .whitespaces) })

        let paragraphs = splitIntoParagraphs(lines)
        let cleanedParagraphs = paragraphs.map(cleanParagraph)
        return cleanedParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeScalars(_ input: String) -> String {
        String(input.unicodeScalars.compactMap { scalar in
            if scalar == "\n" || scalar == "\r" || scalar == "\t" {
                return Character(scalar)
            }

            if scalar.properties.isDefaultIgnorableCodePoint {
                return nil
            }

            if CharacterSet.controlCharacters.contains(scalar) {
                return nil
            }

            if scalar == "\u{00A0}" || scalar == "\u{2007}" || scalar == "\u{202F}" {
                return " "
            }

            return Character(scalar)
        })
    }

    private func normalizeInlineWhitespace(_ line: String) -> String {
        line
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"[ ]{2,}"#, with: " ", options: .regularExpression)
    }

    private func repairHyphenatedLineBreaks(_ input: String) -> String {
        input.replacingOccurrences(
            of: #"([A-Za-zÀ-ÖØ-öø-ÿ])-\n([a-zà-öø-ÿ])"#,
            with: "$1$2",
            options: .regularExpression
        )
    }

    private func removeRepeatedNoiseLines(from lines: [String]) -> [String] {
        let counts = Dictionary(grouping: lines.filter { !$0.isEmpty }, by: { $0 })
            .mapValues(\.count)
        var seenRepeatedNoise = Set<String>()

        return lines.filter { line in
            if line.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil {
                return false
            }

            guard let count = counts[line], count >= 3 else { return true }
            guard line.count <= 80 else { return true }

            if seenRepeatedNoise.contains(line) {
                return false
            }

            seenRepeatedNoise.insert(line)
            return true
        }
    }

    private func splitIntoParagraphs(_ lines: [String]) -> [[String]] {
        var paragraphs: [[String]] = []
        var current: [String] = []

        for line in lines {
            if line.isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(line)
            }
        }

        if !current.isEmpty {
            paragraphs.append(current)
        }

        return paragraphs
    }

    private func cleanParagraph(_ lines: [String]) -> String {
        guard lines.count > 1 else { return lines.first ?? "" }

        if lines.contains(where: shouldPreserveLineBreak) {
            return lines.joined(separator: "\n")
        }

        switch paragraphPreservation {
        case .conservative:
            return lines.joined(separator: " ")
        case .balanced:
            return balancedJoinWrappedLines(lines)
        case .aggressive:
            return aggressivelyJoinWrappedLines(lines)
        }
    }

    private func shouldPreserveLineBreak(_ line: String) -> Bool {
        line.hasPrefix("#")
            || line.hasPrefix(">")
            || line.hasPrefix("- ")
            || line.hasPrefix("* ")
            || line.hasPrefix("+ ")
            || line.hasPrefix("|")
            || line.hasPrefix("```")
            || line.range(of: #"^(=|-){3,}$"#, options: .regularExpression) != nil
            || line.range(of: #"^[-*+]\s+"#, options: .regularExpression) != nil
            || line.range(of: #"^[•·▪‣]\s+"#, options: .regularExpression) != nil
            || line.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) != nil
    }

    private func balancedJoinWrappedLines(_ lines: [String]) -> String {
        var output = ""

        for line in lines {
            if output.isEmpty {
                output = line
                continue
            }

            if output.last == "-" {
                output.removeLast()
                output += line
            } else if output.last?.isHardBoundary == true || line.looksLikeHeading {
                output += "\n" + line
            } else {
                output += " " + line
            }
        }

        return output
    }

    private func aggressivelyJoinWrappedLines(_ lines: [String]) -> String {
        var output = ""

        for line in lines {
            if output.isEmpty {
                output = line
                continue
            }

            if output.last == "-" {
                output.removeLast()
                output += line
            } else if output.last?.isSentenceTerminator == true {
                output += "\n" + line
            } else {
                output += " " + line
            }
        }

        return output
    }
}

private extension Character {
    var isSentenceTerminator: Bool {
        self == "." || self == "!" || self == "?" || self == ":" || self == ";"
    }

    var isHardBoundary: Bool {
        self == "." || self == "!" || self == "?"
    }
}

private extension String {
    var looksLikeHeading: Bool {
        count <= 80
            && range(of: #"[.!?]$"#, options: .regularExpression) == nil
            && range(of: #"[A-Za-zÀ-ÖØ-öø-ÿ]"#, options: .regularExpression) != nil
    }
}
