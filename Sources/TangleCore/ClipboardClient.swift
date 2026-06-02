import AppKit
import Foundation

public enum ClipboardError: Error, LocalizedError {
    case noTextOnClipboard
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .noTextOnClipboard:
            return "No text was found on the clipboard."
        case .writeFailed:
            return "The transformed text could not be written to the clipboard."
        }
    }
}

public struct ClipboardClient: Sendable {
    public init() {}

    public func readContent() throws -> ClipboardContent {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else {
            throw ClipboardError.noTextOnClipboard
        }

        let html = pasteboard.string(forType: .html)
            ?? pasteboard.string(forType: NSPasteboard.PasteboardType("public.html"))

        return ClipboardContent(text: text, html: html)
    }

    public func readText() throws -> String {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            throw ClipboardError.noTextOnClipboard
        }

        return text
    }

    public func writeText(_ text: String) throws {
        NSPasteboard.general.clearContents()
        let didWrite = NSPasteboard.general.setString(text, forType: .string)

        if !didWrite {
            throw ClipboardError.writeFailed
        }
    }
}

public struct ClipboardContent: Sendable {
    public var text: String
    public var html: String?

    public init(text: String, html: String? = nil) {
        self.text = text
        self.html = html
    }
}
