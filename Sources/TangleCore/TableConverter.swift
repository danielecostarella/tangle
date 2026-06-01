import Foundation

public enum TableOutputFormat: String, Sendable, CaseIterable {
    case markdown
    case csv
    case tsv
}

public struct TableConverter: Sendable {
    public init() {}

    public func convert(_ input: String, to format: TableOutputFormat) -> String {
        let rows = parseRows(input)
        guard !rows.isEmpty else { return input }

        switch format {
        case .markdown:
            return markdownTable(rows)
        case .csv:
            return rows.map { $0.map(csvEscape).joined(separator: ",") }.joined(separator: "\n")
        case .tsv:
            return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
        }
    }

    private func parseRows(_ input: String) -> [[String]] {
        input
            .split(whereSeparator: \.isNewline)
            .map { line in
                let text = String(line)
                let separator = text.contains("\t") ? "\t" : ","
                return text
                    .components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            .filter { $0.count > 1 }
    }

    private func markdownTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "" }
        let separator = Array(repeating: "---", count: header.count)
        let body = rows.dropFirst()
        return ([header, separator] + body).map { row in
            "| " + row.map(escapeMarkdownCell).joined(separator: " | ") + " |"
        }.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        return value
    }

    private func escapeMarkdownCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}
