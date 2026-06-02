import Foundation

public enum TransformationKind: String, Sendable, CaseIterable {
    case cleanText
    case cleanURL
    case markdown
    case tableMarkdown
    case tableCSV
    case tableTSV
    case plainPaste
}

public struct TangleTransformer: Sendable {
    public var settings: TangleSettings

    public init(settings: TangleSettings = TangleSettings()) {
        self.settings = settings
    }

    public func transform(_ input: ClipboardContent, kind: TransformationKind) -> String {
        if case .markdown = kind, let html = input.html?.nonEmptyHTML {
            return MarkdownTransformer(
                preset: settings.markdownPreset,
                paragraphPreservation: settings.paragraphPreservation
            ).transform(html: html, fallbackText: input.text)
        }

        return transform(input.text, kind: kind)
    }

    public func transform(_ input: String, kind: TransformationKind) -> String {
        switch kind {
        case .cleanText, .plainPaste:
            return TextCleaner(paragraphPreservation: settings.paragraphPreservation).clean(input)
        case .cleanURL:
            return URLCleaner(
                blockedParameters: settings.blockedURLParameters,
                allowedParameters: settings.allowedURLParameters
            ).cleanURLs(in: input)
        case .markdown:
            return MarkdownTransformer(
                preset: settings.markdownPreset,
                paragraphPreservation: settings.paragraphPreservation
            ).transform(input)
        case .tableMarkdown:
            return TableConverter().convert(input, to: .markdown)
        case .tableCSV:
            return TableConverter().convert(input, to: .csv)
        case .tableTSV:
            return TableConverter().convert(input, to: .tsv)
        }
    }
}

private extension String {
    var nonEmptyHTML: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
