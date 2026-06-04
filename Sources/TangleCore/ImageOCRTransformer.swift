import AppKit
import Foundation
import Vision

public enum ImageOCRError: Error, LocalizedError {
    case unreadableImage
    case noTextRecognized
    case noImageOnClipboard

    public var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "The clipboard image could not be read."
        case .noTextRecognized:
            return "No text was recognized in the image."
        case .noImageOnClipboard:
            return "No image was found on the clipboard."
        }
    }
}

public struct OCRTextLine: Sendable, Equatable {
    public var text: String
    public var confidence: Float
    public var boundingBox: CGRect
    public var isBold: Bool
    public var isItalic: Bool

    public init(
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        isBold: Bool = false,
        isItalic: Bool = false
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.isBold = isBold
        self.isItalic = isItalic
    }
}

public struct ImageOCRTransformer: Sendable {
    public var minimumConfidence: Float
    public var recognitionLanguages: [String]

    public init(minimumConfidence: Float = 0.35, recognitionLanguages: [String] = ["en-US", "it-IT"]) {
        self.minimumConfidence = minimumConfidence
        self.recognitionLanguages = recognitionLanguages
    }

    public func recognizeLines(in imageData: Data) throws -> [OCRTextLine] {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageOCRError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        // Collect qualifying observations
        let qualifying = (request.results ?? []).compactMap { obs -> (obs: VNRecognizedTextObservation, text: String, confidence: Float)? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, candidate.confidence >= minimumConfidence else { return nil }
            return (obs, text, candidate.confidence)
        }

        // Compute pixel density for each observation (proxy for stroke width → bold)
        let densities: [CGFloat] = qualifying.map {
            textPixelDensity(in: cgImage, normalizedBox: $0.obs.boundingBox)
        }
        let medianDensity = densities.median
        // Only flag bold when there is enough contrast variation in the image
        let boldThreshold: CGFloat = medianDensity > 0.02 ? medianDensity * 1.5 : .infinity

        let lines = qualifying.enumerated().map { i, pair in
            OCRTextLine(
                text: pair.text,
                confidence: pair.confidence,
                boundingBox: pair.obs.boundingBox,
                isBold: densities[i] > boldThreshold,
                isItalic: false
            )
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

    // MARK: - Bold detection via pixel density

    /// Returns the fraction of pixels that belong to the text (dark-on-light or light-on-dark).
    /// Higher density relative to the document median signals bolder strokes.
    private func textPixelDensity(in image: CGImage, normalizedBox: CGRect) -> CGFloat {
        let iw = image.width
        let ih = image.height

        // Vision uses bottom-left origin; CGImage uses top-left
        let cx = max(0, Int((normalizedBox.minX * CGFloat(iw)).rounded()))
        let cy = max(0, Int(((1.0 - normalizedBox.maxY) * CGFloat(ih)).rounded()))
        let cw = max(1, min(Int((normalizedBox.width * CGFloat(iw)).rounded()), iw - cx))
        let ch = max(1, min(Int((normalizedBox.height * CGFloat(ih)).rounded()), ih - cy))

        guard let cropped = image.cropping(to: CGRect(x: cx, y: cy, width: cw, height: ch)) else { return 0 }

        let gray = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: cw, height: ch,
            bitsPerComponent: 8, bytesPerRow: cw,
            space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cw, height: ch))
        guard let ptr = ctx.data else { return 0 }

        let bytes = ptr.assumingMemoryBound(to: UInt8.self)
        let total = cw * ch
        var dark = 0
        for i in 0..<total where bytes[i] < 128 { dark += 1 }

        // Normalize for both dark-on-light and light-on-dark text
        let darkFraction = CGFloat(dark) / CGFloat(total)
        return min(darkFraction, 1.0 - darkFraction)
    }
}

// MARK: - Markdown formatting

public struct ImageMarkdownFormatter: Sendable {
    public init() {}

    // MARK: Reading order

    public func readingOrder(_ lines: [OCRTextLine]) -> [OCRTextLine] {
        let sorted = lines.sorted { lhs, rhs in
            let yDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if yDelta > 0.015 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        let columns = columnClusters(in: sorted)
        guard columns.count > 1 else { return sorted }

        return columns.flatMap { column in
            column.sorted { lhs, rhs in
                let yDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                if yDelta > 0.015 { return lhs.boundingBox.midY > rhs.boundingBox.midY }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
        }
    }

    // MARK: Plain text

    public func plainText(from lines: [OCRTextLine]) -> String {
        readingOrder(lines)
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Markdown

    public func markdown(from lines: [OCRTextLine]) -> String {
        guard !lines.isEmpty else { return "" }

        // Table detection runs on raw lines before column-splitting readingOrder
        if let tableMarkdown = tryFormatAsTable(lines) {
            return tableMarkdown
        }

        let ordered = readingOrder(lines)
        guard !ordered.isEmpty else { return "" }

        let medianHeight = ordered.map(\.boundingBox.height).median
        let blocks = ordered.map { markdownLine(for: $0, medianHeight: medianHeight) }
        return joinMarkdownBlocks(blocks).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Table detection

    private struct TableRow {
        var cells: [OCRTextLine]
        var midY: CGFloat
    }

    private func tryFormatAsTable(_ lines: [OCRTextLine]) -> String? {
        guard lines.count >= 4 else { return nil }

        // Cells that span more than 40% of the image width are paragraph text, not table cells
        let avgCellWidth = lines.map(\.boundingBox.width).reduce(0, +) / CGFloat(lines.count)
        guard avgCellWidth < 0.40 else { return nil }

        let rows = clusterIntoTableRows(lines)
        guard rows.count >= 2 else { return nil }

        let cellCounts = rows.map { $0.cells.count }
        guard let targetColumns = cellCounts.mode, targetColumns >= 2 else { return nil }

        // At least 60 % of rows must have the expected column count
        let consistent = cellCounts.filter { abs($0 - targetColumns) <= 1 }.count
        guard Double(consistent) / Double(rows.count) >= 0.60 else { return nil }

        // For 2-column layouts, require short cells to distinguish tables from
        // newspaper-style two-column text (which has sentence-length observations).
        if targetColumns < 3 {
            let maxWordsInAnyCell = lines
                .map { $0.text.split(whereSeparator: \.isWhitespace).count }
                .max() ?? 0
            guard maxWordsInAnyCell <= 5 else { return nil }
        }

        // Row Y-spacing should be roughly uniform (CV < 0.5) — rules out irregular text blocks
        let yValues = rows.map(\.midY)
        let gaps = zip(yValues, yValues.dropFirst()).map { abs($0 - $1) }
        guard !gaps.isEmpty else { return nil }
        let meanGap = gaps.reduce(0, +) / CGFloat(gaps.count)
        guard meanGap > 0 else { return nil }
        let variance = gaps.map { pow($0 - meanGap, 2) }.reduce(0, +) / CGFloat(gaps.count)
        let cv = sqrt(variance) / meanGap
        guard cv < 0.55 else { return nil }

        // Build column anchors using the largest X-gaps
        let allX = rows.flatMap { $0.cells.map(\.boundingBox.midX) }.sorted()
        let anchors = columnAnchors(from: allX, count: targetColumns)
        guard anchors.count >= 2 else { return nil }

        // Assign each cell to the nearest column slot
        let grid: [[OCRTextLine?]] = rows.map { row in
            var slots = [OCRTextLine?](repeating: nil, count: anchors.count)
            for cell in row.cells {
                if let col = anchors.enumerated()
                    .min(by: { abs($0.element - cell.boundingBox.midX) < abs($1.element - cell.boundingBox.midX) })?
                    .offset {
                    slots[col] = cell
                }
            }
            return slots
        }

        return renderMarkdownTable(grid, columnCount: anchors.count)
    }

    private func clusterIntoTableRows(_ lines: [OCRTextLine]) -> [TableRow] {
        let sorted = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        let medH = lines.map(\.boundingBox.height).median
        let threshold = max(medH * 0.5, 0.015)

        var rows: [TableRow] = []
        var current: [OCRTextLine] = []
        var currentY: CGFloat = sorted.first?.boundingBox.midY ?? 0

        for line in sorted {
            if abs(line.boundingBox.midY - currentY) <= threshold {
                current.append(line)
            } else {
                if !current.isEmpty {
                    let midY = current.map(\.boundingBox.midY).reduce(0, +) / CGFloat(current.count)
                    rows.append(TableRow(
                        cells: current.sorted { $0.boundingBox.minX < $1.boundingBox.minX },
                        midY: midY
                    ))
                }
                current = [line]
                currentY = line.boundingBox.midY
            }
        }
        if !current.isEmpty {
            let midY = current.map(\.boundingBox.midY).reduce(0, +) / CGFloat(current.count)
            rows.append(TableRow(
                cells: current.sorted { $0.boundingBox.minX < $1.boundingBox.minX },
                midY: midY
            ))
        }
        return rows
    }

    private func columnAnchors(from sortedX: [CGFloat], count: Int) -> [CGFloat] {
        guard sortedX.count >= count, count >= 2 else { return sortedX }

        // Find the count-1 largest gaps and use them as cluster boundaries
        let gaps = zip(sortedX, sortedX.dropFirst())
            .enumerated()
            .map { (idx: $0.offset, gap: $0.element.1 - $0.element.0) }
            .sorted { $0.gap > $1.gap }

        let splitAt = Set(gaps.prefix(count - 1).map { $0.idx + 1 }).sorted()
        var anchors: [CGFloat] = []
        var start = 0
        for split in splitAt + [sortedX.count] {
            let cluster = Array(sortedX[start..<split])
            if !cluster.isEmpty {
                anchors.append(cluster.reduce(0, +) / CGFloat(cluster.count))
            }
            start = split
        }
        return anchors.sorted()
    }

    private func renderMarkdownTable(_ grid: [[OCRTextLine?]], columnCount: Int) -> String {
        guard !grid.isEmpty else { return "" }

        func cellText(_ cell: OCRTextLine?) -> String {
            guard let cell else { return "" }
            let t = normalizeOCRText(cell.text)
            return applyInlineFormatting(t, isBold: cell.isBold, isItalic: cell.isItalic)
        }

        var output: [String] = []
        for (rowIdx, row) in grid.enumerated() {
            let cells = (0..<columnCount).map { j -> String in
                cellText(j < row.count ? row[j] : nil)
            }
            output.append("| " + cells.joined(separator: " | ") + " |")
            if rowIdx == 0 {
                let sep = [String](repeating: "---", count: columnCount)
                output.append("| " + sep.joined(separator: " | ") + " |")
            }
        }
        return output.joined(separator: "\n")
    }

    // MARK: - Line formatting

    private func markdownLine(for line: OCRTextLine, medianHeight: CGFloat) -> String {
        let text = normalizeOCRText(line.text)

        if text.range(of: #"^([•·▪▫‣⁃-])\s+"#, options: .regularExpression) != nil {
            let content = text.replacingOccurrences(
                of: #"^([•·▪▫‣⁃-])\s+"#, with: "", options: .regularExpression
            )
            return "- " + applyInlineFormatting(content, isBold: line.isBold, isItalic: line.isItalic)
        }

        if text.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) != nil {
            return text
        }

        if let level = headingLevel(for: text, height: line.boundingBox.height, medianHeight: medianHeight) {
            return "\(String(repeating: "#", count: level)) \(text)"
        }

        return applyInlineFormatting(text, isBold: line.isBold, isItalic: line.isItalic)
    }

    private func applyInlineFormatting(_ text: String, isBold: Bool, isItalic: Bool) -> String {
        guard !text.isEmpty else { return text }
        if isBold && isItalic { return "***\(text)***" }
        if isBold { return "**\(text)**" }
        if isItalic { return "_\(text)_" }
        return text
    }

    private func joinMarkdownBlocks(_ blocks: [String]) -> String {
        var output: [String] = []
        for block in blocks where !block.isEmpty {
            let previous = output.last ?? ""
            let needsBlankLine = block.isMarkdownHeading
                || previous.isMarkdownHeading
                || (block.hasPrefix("- ") != previous.hasPrefix("- "))
            if needsBlankLine, !previous.isEmpty { output.append("") }
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

    private func headingLevel(for text: String, height: CGFloat, medianHeight: CGFloat) -> Int? {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard (1...10).contains(words.count),
              !text.hasSuffix("."),
              text.count >= 4 else { return nil }

        let letters = text.filter(\.isLetter)
        let isAllCaps = letters.count >= 4 &&
            Double(letters.filter(\.isUppercase).count) / Double(letters.count) > 0.75

        if medianHeight > 0, height >= medianHeight * 1.25 {
            let ratio = height / medianHeight
            if ratio >= 2.0 || (ratio >= 1.3 && isAllCaps) { return 1 }
            if ratio >= 1.3 { return 2 }
            return 3
        }

        guard letters.count >= 4, words.count >= 2 else { return nil }
        return isAllCaps ? 2 : nil
    }

    private func columnClusters(in lines: [OCRTextLine]) -> [[OCRTextLine]] {
        guard lines.count >= 4 else { return [lines] }

        let sortedByX = lines.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        let largestGap = zip(sortedByX, sortedByX.dropFirst())
            .map { lhs, rhs in
                (gap: rhs.boundingBox.minX - lhs.boundingBox.maxX,
                 splitX: (lhs.boundingBox.maxX + rhs.boundingBox.minX) / 2)
            }
            .max { $0.gap < $1.gap }

        guard let largestGap, largestGap.gap > 0.15 else { return [lines] }

        let left = lines.filter { $0.boundingBox.midX < largestGap.splitX }
        let right = lines.filter { $0.boundingBox.midX >= largestGap.splitX }
        guard left.count >= 2, right.count >= 2 else { return [lines] }
        return [left, right]
    }
}

// MARK: - Private extensions

private extension String {
    var isMarkdownHeading: Bool {
        range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
    }
}

private extension Array where Element == CGFloat {
    var median: CGFloat {
        guard !isEmpty else { return 0 }
        let s = sorted()
        let m = count / 2
        return count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
    }
}

private extension Array where Element == Int {
    var mode: Int? {
        reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key
    }
}
