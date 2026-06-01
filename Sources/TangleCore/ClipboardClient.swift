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
