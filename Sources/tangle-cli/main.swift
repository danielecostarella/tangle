import ArgumentParser
import Darwin
import Foundation
import TangleCore

@main
struct TangleCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tangle",
        abstract: "A local-first clipboard and text transformer for macOS.",
        subcommands: [
            Smart.self,
            Detect.self,
            Clean.self,
            CleanURL.self,
            Markdown.self,
            Image.self,
            Table.self
        ],
        defaultSubcommand: Clean.self
    )
}

struct Smart: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smart",
        abstract: "Detect clipboard or stdin content and apply the best local transformation."
    )

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Flag(help: "Print detected content kind and character savings to stderr.")
    var stats = false

    func run() throws {
        let content = try Input.readContent(useClipboard: clipboard)
        let detection = SmartClipboardDetector().detect(content)
        let output = try TangleTransformer().transformContent(content, kind: .smart)

        if stats {
            let message = "detected: \(detection.kind.rawValue), confidence: \(String(format: "%.2f", detection.confidence))\n"
            FileHandle.standardError.write(Data(message.utf8))
            Output.writeStats(input: content.text, output: output)
        }

        try Output.write(output, useClipboard: clipboard)
    }
}

struct Detect: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "detect",
        abstract: "Print the detected clipboard or stdin content type."
    )

    @Flag(help: "Read from the macOS clipboard.")
    var clipboard = false

    func run() throws {
        let content = try Input.readContent(useClipboard: clipboard)
        let detection = SmartClipboardDetector().detect(content)
        print("\(detection.kind.rawValue)\t\(detection.recommendedTransformation.rawValue)\t\(String(format: "%.2f", detection.confidence))")
    }
}

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Normalize messy text from stdin or the clipboard."
    )

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Option(help: "Paragraph cleanup mode: conservative, balanced, or aggressive.")
    var mode: CleanupMode = .balanced

    @Flag(help: "Print character savings to stderr.")
    var stats = false

    func run() throws {
        let input = try Input.read(useClipboard: clipboard)
        let output = TangleTransformer(
            settings: TangleSettings(paragraphPreservation: mode.paragraphPreservation)
        ).transform(input, kind: .cleanText)
        if stats {
            Output.writeStats(input: input, output: output)
        }
        try Output.write(output, useClipboard: clipboard)
    }
}

struct CleanURL: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "url",
        abstract: "Remove common tracking parameters from URLs."
    )

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Flag(help: "Print character savings to stderr.")
    var stats = false

    func run() throws {
        let input = try Input.read(useClipboard: clipboard)
        let output = URLCleaner().cleanURLs(in: input)
        if stats {
            Output.writeStats(input: input, output: output)
        }
        try Output.write(output, useClipboard: clipboard)
    }
}

struct Markdown: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "markdown",
        abstract: "Convert copied PDF or web text into clean Markdown."
    )

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Option(help: "Markdown preset: standard or llm.")
    var preset: MarkdownPresetOption = .llm

    @Option(help: "Paragraph cleanup mode: conservative, balanced, or aggressive.")
    var mode: CleanupMode = .balanced

    @Flag(help: "Print character savings to stderr.")
    var stats = false

    func run() throws {
        let transformer = TangleTransformer(
            settings: TangleSettings(
                paragraphPreservation: mode.paragraphPreservation,
                markdownPreset: preset.markdownPreset
            )
        )
        let input: String
        let output: String

        if clipboard {
            let content = try ClipboardClient().readContent()
            input = content.text
            output = try TangleTransformer(
                settings: TangleSettings(
                    paragraphPreservation: mode.paragraphPreservation,
                    markdownPreset: preset.markdownPreset
                )
            ).transformContent(content, kind: .markdown)
        } else {
            input = try Input.read(useClipboard: false)
            output = transformer.transform(input, kind: .markdown)
        }

        if stats {
            Output.writeStats(input: input, output: output)
        }
        try Output.write(output, useClipboard: clipboard)
    }
}

struct Table: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "table",
        abstract: "Convert copied tabular text to Markdown, CSV, or TSV."
    )

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Option(help: "Output format: markdown, csv, or tsv.")
    var to: TableFormatOption = .markdown

    func run() throws {
        let input = try Input.read(useClipboard: clipboard)
        let output = TableConverter().convert(input, to: to.tableOutputFormat)
        try Output.write(output, useClipboard: clipboard)
    }
}

struct Image: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Extract local OCR text from an image file or clipboard image."
    )

    @Argument(help: "Optional image path. Omit with --clipboard to read the macOS clipboard image.")
    var path: String?

    @Flag(help: "Read from and write back to the macOS clipboard.")
    var clipboard = false

    @Option(help: "Output format: text or markdown.")
    var to: ImageOutputOption = .markdown

    @Option(help: "Minimum OCR confidence, from 0.0 to 1.0.")
    var confidence: Float = 0.35

    @Option(help: "Comma-separated OCR languages, for example en-US,it-IT.")
    var languages = "en-US,it-IT"

    @Flag(help: "Print character count to stderr.")
    var stats = false

    func run() throws {
        let imageData: Data

        if clipboard || path == nil {
            let content = try ClipboardClient().readContent()
            guard let clipboardImageData = content.imageData else {
                throw ClipboardError.noSupportedContentOnClipboard
            }
            imageData = clipboardImageData
        } else if let path {
            imageData = try Data(contentsOf: URL(fileURLWithPath: path))
        } else {
            throw ClipboardError.noSupportedContentOnClipboard
        }

        let recognitionLanguages = languages
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let transformer = ImageOCRTransformer(
            minimumConfidence: confidence,
            recognitionLanguages: recognitionLanguages.isEmpty ? ["en-US", "it-IT"] : recognitionLanguages
        )
        let output: String
        switch to {
        case .text:
            output = try transformer.extractText(from: imageData)
        case .markdown:
            output = try transformer.extractMarkdown(from: imageData)
        }

        if stats {
            let message = "output: \(output.count) chars\n"
            FileHandle.standardError.write(Data(message.utf8))
        }

        try Output.write(output, useClipboard: clipboard)
    }
}

enum CleanupMode: String, ExpressibleByArgument {
    case conservative
    case balanced
    case aggressive

    var paragraphPreservation: ParagraphPreservation {
        switch self {
        case .conservative:
            return .conservative
        case .balanced:
            return .balanced
        case .aggressive:
            return .aggressive
        }
    }
}

enum MarkdownPresetOption: String, ExpressibleByArgument {
    case standard
    case llm

    var markdownPreset: TangleCore.MarkdownPreset {
        switch self {
        case .standard:
            return .standard
        case .llm:
            return .llm
        }
    }
}

enum TableFormatOption: String, ExpressibleByArgument {
    case markdown
    case csv
    case tsv

    var tableOutputFormat: TableOutputFormat {
        switch self {
        case .markdown:
            return .markdown
        case .csv:
            return .csv
        case .tsv:
            return .tsv
        }
    }
}

enum ImageOutputOption: String, ExpressibleByArgument {
    case text
    case markdown
}

enum Input {
    static func readContent(useClipboard: Bool) throws -> ClipboardContent {
        if useClipboard || isatty(STDIN_FILENO) != 0 {
            return try ClipboardClient().readContent()
        }

        return ClipboardContent(text: FileHandle.standardInput.readDataToEndOfFile().asUTF8String)
    }

    static func read(useClipboard: Bool) throws -> String {
        if useClipboard || isatty(STDIN_FILENO) != 0 {
            return try ClipboardClient().readText()
        }

        return FileHandle.standardInput.readDataToEndOfFile().asUTF8String
    }
}

enum Output {
    static func write(_ output: String, useClipboard: Bool) throws {
        if useClipboard {
            try ClipboardClient().writeText(output)
        } else {
            FileHandle.standardOutput.write(Data(output.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    static func writeStats(input: String, output: String) {
        let saved = input.count - output.count
        let percent = input.isEmpty ? 0 : (Double(saved) / Double(input.count)) * 100
        let message = String(
            format: "input: %d chars, output: %d chars, saved: %d chars (%.1f%%)\n",
            input.count,
            output.count,
            saved,
            percent
        )
        FileHandle.standardError.write(Data(message.utf8))
    }
}

private extension Data {
    var asUTF8String: String {
        String(data: self, encoding: .utf8) ?? ""
    }
}
