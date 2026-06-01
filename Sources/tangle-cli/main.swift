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
            Clean.self,
            CleanURL.self,
            Markdown.self,
            Table.self
        ],
        defaultSubcommand: Clean.self
    )
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
        let output = TextCleaner(paragraphPreservation: mode.paragraphPreservation).clean(input)
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
        let input = try Input.read(useClipboard: clipboard)
        let output = MarkdownTransformer(
            preset: preset.markdownPreset,
            paragraphPreservation: mode.paragraphPreservation
        ).transform(input)
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

enum Input {
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
