import Foundation

public enum TransformationKind: String, Sendable, CaseIterable {
    case smart
    case cleanText
    case cleanURL
    case markdown
    case imageText
    case imageMarkdown
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
        (try? transformContent(input, kind: kind)) ?? input.text
    }

    public func transformContent(_ input: ClipboardContent, kind: TransformationKind) throws -> String {
        if case .smart = kind {
            return try transformContent(input, kind: SmartClipboardDetector().detect(input).recommendedTransformation)
        }

        if case .markdown = kind, let html = input.html?.nonEmptyHTML {
            return MarkdownTransformer(
                preset: settings.markdownPreset,
                paragraphPreservation: settings.paragraphPreservation
            ).transform(html: html, fallbackText: input.text)
        }

        if case .imageText = kind, let imageData = input.imageData {
            return try imageOCRTransformer.extractText(from: imageData)
        }

        if case .imageMarkdown = kind, let imageData = input.imageData {
            return try imageOCRTransformer.extractMarkdown(from: imageData)
        }

        return transform(input.text, kind: kind)
    }

    public func transform(_ input: String, kind: TransformationKind) -> String {
        if case .smart = kind {
            let content = ClipboardContent(text: input)
            return transform(content, kind: SmartClipboardDetector().detect(content).recommendedTransformation)
        }

        switch kind {
        case .smart:
            return transform(input, kind: .cleanText)
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
        case .imageText, .imageMarkdown:
            return input
        case .tableMarkdown:
            return TableConverter().convert(input, to: .markdown)
        case .tableCSV:
            return TableConverter().convert(input, to: .csv)
        case .tableTSV:
            return TableConverter().convert(input, to: .tsv)
        }
    }
}

private extension TangleTransformer {
    var imageOCRTransformer: ImageOCRTransformer {
        ImageOCRTransformer(
            minimumConfidence: settings.ocrMinimumConfidence,
            recognitionLanguages: settings.ocrRecognitionLanguages
        )
    }
}

private extension String {
    var nonEmptyHTML: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
