import Foundation

public enum TransformationKind: String, Sendable, CaseIterable {
    case smart          // Smart markdown (image → OCR MD, HTML → MD, table → MD, text → clean)
    case smartText      // Smart plain text (image → OCR text, HTML → stripped, text → clean)
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

        if case .smartText = kind {
            // Image-only clipboard → OCR plain text
            if input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let imageData = input.imageData {
                return try imageOCRTransformer.extractText(from: imageData)
            }
            if input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let documentText = documentPlainText(from: input) {
                return documentText
            }
            // Detect the text content type directly (ignoring HTML) so that TSV
            // from Excel stays as TSV even when the clipboard also carries an HTML table.
            let textKind = SmartClipboardDetector().detect(input.text).kind
            switch textKind {
            case .url:
                return transform(input.text, kind: .cleanURL)
            case .table:
                return TableConverter().convert(input.text, to: .tsv)
            default:
                return TextCleaner(paragraphPreservation: settings.paragraphPreservation).clean(input.text)
            }
        }

        if case .markdown = kind,
           DocumentMarkdownTransformer().looksLikeExtractedPDFText(input.text) {
            return DocumentMarkdownTransformer().transformExtractedPDFText(
                input.text,
                preset: settings.markdownPreset,
                paragraphPreservation: settings.paragraphPreservation
            )
        }

        if case .markdown = kind, let html = input.html?.nonEmptyHTML {
            return MarkdownTransformer(
                preset: settings.markdownPreset,
                paragraphPreservation: settings.paragraphPreservation
            ).transform(html: html, fallbackText: input.text)
        }

        if case .markdown = kind, let documentMarkdown = documentMarkdown(from: input) {
            return documentMarkdown
        }

        if case .markdown = kind,
           input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let imageData = input.imageData {
            return try imageOCRTransformer.extractMarkdown(from: imageData)
        }

        if case .imageText = kind {
            guard let imageData = input.imageData else { throw ImageOCRError.noImageOnClipboard }
            return try imageOCRTransformer.extractText(from: imageData)
        }

        if case .imageMarkdown = kind {
            guard let imageData = input.imageData else { throw ImageOCRError.noImageOnClipboard }
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
        case .smart, .smartText:
            return transform(input, kind: .cleanText)
        case .cleanText, .plainPaste:
            if TableConverter().reconstructedDatasheetRows(in: input) != nil {
                return TableConverter().convert(input, to: .tsv)
            }
            return TextCleaner(paragraphPreservation: settings.paragraphPreservation).clean(input)
        case .cleanURL:
            return URLCleaner(
                blockedParameters: settings.blockedURLParameters,
                allowedParameters: settings.allowedURLParameters
            ).cleanURLs(in: input)
        case .markdown:
            if TableConverter().looksLikeTable(input) {
                return TableConverter().convert(input, to: .markdown)
            }
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

    func documentMarkdown(from input: ClipboardContent) -> String? {
        let transformer = DocumentMarkdownTransformer()
        if let rtfData = input.rtfData,
           let markdown = transformer.transformRTF(
            data: rtfData,
            preset: settings.markdownPreset,
            paragraphPreservation: settings.paragraphPreservation
           ) {
            return markdown
        }

        if let pdfData = input.pdfData,
           let markdown = transformer.transformPDF(
            data: pdfData,
            preset: settings.markdownPreset,
            paragraphPreservation: settings.paragraphPreservation
           ) {
            return markdown
        }

        if let pdfData = input.pdfData {
            let pages = transformer.rasterizedPDFPages(data: pdfData)
            let markdownPages = pages.compactMap { try? imageOCRTransformer.extractMarkdown(from: $0) }
            if !markdownPages.isEmpty {
                return markdownPages.joined(separator: "\n\n---\n\n")
            }
        }

        return nil
    }

    func documentPlainText(from input: ClipboardContent) -> String? {
        let transformer = DocumentMarkdownTransformer()
        if let rtfData = input.rtfData,
           let text = transformer.extractRTFText(data: rtfData) {
            return TextCleaner(paragraphPreservation: settings.paragraphPreservation).clean(text)
        }

        if let pdfData = input.pdfData,
           let text = transformer.extractPDFText(data: pdfData) {
            return TextCleaner(paragraphPreservation: settings.paragraphPreservation).clean(text)
        }

        return nil
    }
}

private extension String {
    var nonEmptyHTML: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
