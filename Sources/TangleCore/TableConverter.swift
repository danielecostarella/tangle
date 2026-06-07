import Foundation

public enum TableOutputFormat: String, Sendable, CaseIterable {
    case markdown
    case csv
    case tsv
}

public struct TableConverter: Sendable {
    public init() {}

    public func convert(_ input: String, to format: TableOutputFormat) -> String {
        let rows = rows(in: input)
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

    public func rows(in input: String) -> [[String]] {
        let structuredRows = input
            .split(whereSeparator: \.isNewline)
            .map { line in
                let text = String(line)
                let separator = text.contains("\t") ? "\t" : ","
                return text
                    .components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            .filter { $0.count > 1 }

        if structuredRows.count >= 2 {
            return structuredRows
        }

        return reconstructedDatasheetRows(in: input) ?? []
    }

    public func looksLikeTable(_ input: String) -> Bool {
        let parsedRows = rows(in: input)
        guard parsedRows.count >= 2, let columnCount = parsedRows.first?.count, columnCount > 1 else {
            return false
        }
        return parsedRows.allSatisfy { $0.count == columnCount }
    }

    public func reconstructedDatasheetRows(in input: String) -> [[String]]? {
        let text = input
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let headerPattern = #"\b(Symbol|Parameter)\s+Description\s+Min\s+Typ(?:ical)?\s+Max\s+Unit\b"#
        guard let headerRegex = try? NSRegularExpression(
            pattern: headerPattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let headerMatch = headerRegex.firstMatch(in: text, range: fullRange),
              let headerRange = Range(headerMatch.range, in: text) else {
            return nil
        }

        let header = text[headerRange]
            .split(separator: " ")
            .map(String.init)
        let body = String(text[headerRange.upperBound...])

        // Datasheets commonly flatten rows while retaining their compact numeric
        // columns. Parsing from those trailing columns keeps descriptions intact.
        let value = #"(?:-?\d+(?:\.\d+)?|[-–—]|[xX]{1,3}|N/?A)"#
        let unit = #"(?:V|mV|kV|A|mA|uA|µA|W|mW|kW|Ω|ohms?|Hz|kHz|MHz|GHz|°C|C|%)"#
        let rowPattern = #"([A-Za-z][A-Za-z0-9_.+/-]*)\s+(.+?)\s+(?:("# + value + #")\s+)?("#
            + value + #")\s+("# + value + #")\s+("# + unit + #")\b"#
        guard let rowRegex = try? NSRegularExpression(
            pattern: rowPattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let bodyRange = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = rowRegex.matches(in: body, range: bodyRange)
        guard matches.count >= 2 else { return nil }

        var rows: [[String]] = [header]
        var consumedLocation = 0
        for match in matches {
            let gap = NSRange(location: consumedLocation, length: match.range.location - consumedLocation)
            guard let gapRange = Range(gap, in: body),
                  body[gapRange].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let captures = (1..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: body) else {
                    return ""
                }
                return String(body[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard captures.count == 6 else { return nil }
            let symbol = captures[0]
            let description = captures[1]
            let minimum = captures[2]
            let typical = captures[3]
            let maximum = captures[4]
            let parsedUnit = captures[5]

            rows.append([
                symbol,
                description,
                minimum,
                typical,
                maximum,
                parsedUnit
            ])
            consumedLocation = NSMaxRange(match.range)
        }

        let trailingRange = NSRange(location: consumedLocation, length: bodyRange.length - consumedLocation)
        guard let trailingSwiftRange = Range(trailingRange, in: body),
              body[trailingSwiftRange].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return rows
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
