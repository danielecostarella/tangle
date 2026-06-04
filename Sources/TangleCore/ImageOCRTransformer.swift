import AppKit
import Foundation
import Vision

public enum ImageOCRError: Error, LocalizedError {
    case unreadableImage
    case noTextRecognized

    public var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "The clipboard image could not be read."
        case .noTextRecognized:
            return "No text was recognized in the image."
        }
    }
}

public struct OCRTextLine: Sendable, Equatable {
    public var text: String
    public var confidence: Float
    public var boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct ImageOCRTransformer: Sendable {
    public init() {}

    public func recognizeLines(in imageData: Data) throws -> [OCRTextLine] {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageOCRError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { observation -> OCRTextLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return OCRTextLine(text: text, confidence: candidate.confidence, boundingBox: observation.boundingBox)
            }

        let sortedLines = ImageMarkdownFormatter().readingOrder(lines)
        guard !sortedLines.isEmpty else { throw ImageOCRError.noTextRecognized }
        return sortedLines
    }

    public func extractText(from imageData: Data) throws -> String {
        let lines = try recognizeLines(in: imageData)
        return ImageMarkdownFormatter().plainText(from: lines)
    }

    public func extractMarkdown(from imageData: Data) throws -> String {
        let lines = try recognizeLines(in: imageData)
        return ImageMarkdownFormatter().markdown(from: lines)
    }
}

public struct ImageMarkdownFormatter: Sendable {
    public init() {}

    public func readingOrder(_ lines: [OCRTextLine]) -> [OCRTextLine] {
        lines.sorted { lhs, rhs in
            let yDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if yDelta > 0.015 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    public func plainText(from lines: [OCRTextLine]) -> String {
        readingOrder(lines)
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func markdown(from lines: [OCRTextLine]) -> String {
        let ordered = readingOrder(lines)
        guard !ordered.isEmpty else { return "" }

        let medianHeight = ordered.map(\.boundingBox.height).median
        let blocks = ordered.map { line in
            markdownLine(for: line, medianHeight: medianHeight)
        }

        return joinMarkdownBlocks(blocks)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markdownLine(for line: OCRTextLine, medianHeight: CGFloat) -> String {
        let text = normalizeOCRText(line.text)

        if text.range(of: #"^([•·▪▫‣⁃-])\s+"#, options: .regularExpression) != nil {
            return "- " + text.replacingOccurrences(
                of: #"^([•·▪▫‣⁃-])\s+"#,
                with: "",
                options: .regularExpression
            )
        }

        if text.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) != nil {
            return text
        }

        if looksLikeHeading(text, height: line.boundingBox.height, medianHeight: medianHeight) {
            return "## \(text)"
        }

        return text
    }

    private func joinMarkdownBlocks(_ blocks: [String]) -> String {
        var output: [String] = []

        for block in blocks where !block.isEmpty {
            let previous = output.last ?? ""
            let needsBlankLine = block.hasPrefix("## ")
                || previous.hasPrefix("## ")
                || (block.hasPrefix("- ") != previous.hasPrefix("- "))

            if needsBlankLine, !previous.isEmpty {
                output.append("")
            }

            output.append(block)
        }

        return output.joined(separator: "\n")
    }

    private func normalizeOCRText(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"[\u{00A0}\t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeHeading(_ text: String, height: CGFloat, medianHeight: CGFloat) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard (1...10).contains(words.count),
              !text.hasSuffix("."),
              text.count >= 4 else {
            return false
        }

        if medianHeight > 0, height >= medianHeight * 1.25 {
            return true
        }

        let letters = text.filter(\.isLetter)
        guard letters.count >= 4 else { return false }
        let uppercaseLetters = letters.filter(\.isUppercase)
        return Double(uppercaseLetters.count) / Double(max(letters.count, 1)) > 0.75
    }
}

private extension Array where Element == CGFloat {
    var median: CGFloat {
        guard !isEmpty else { return 0 }
        let sorted = sorted()
        let middle = count / 2

        if count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }
}
