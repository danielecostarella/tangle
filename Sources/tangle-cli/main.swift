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
            CleanURL.self
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

    func run() throws {
        let input = try Input.read(useClipboard: clipboard)
        let output = TextCleaner().clean(input)
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

    func run() throws {
        let input = try Input.read(useClipboard: clipboard)
        let output = URLCleaner().cleanURLs(in: input)
        try Output.write(output, useClipboard: clipboard)
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
}

private extension Data {
    var asUTF8String: String {
        String(data: self, encoding: .utf8) ?? ""
    }
}
