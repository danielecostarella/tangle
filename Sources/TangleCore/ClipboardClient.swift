import AppKit
import Foundation

public enum ClipboardError: Error, LocalizedError {
    case noTextOnClipboard
    case noSupportedContentOnClipboard
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .noTextOnClipboard:
            return "No text was found on the clipboard."
        case .noSupportedContentOnClipboard:
            return "No text or image was found on the clipboard."
        case .writeFailed:
            return "The transformed text could not be written to the clipboard."
        }
    }
}

public struct ClipboardClient: Sendable {
    public init() {}

    public func readContent() throws -> ClipboardContent {
        let pasteboard = NSPasteboard.general
        let text = pasteboard.string(forType: .string) ?? ""

        let html = pasteboard.string(forType: .html)
            ?? pasteboard.string(forType: NSPasteboard.PasteboardType("public.html"))

        let pdfData = pasteboard.data(forType: .pdf)
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("com.adobe.pdf"))
        let rtfData = pasteboard.data(forType: .rtf)
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.rtf"))
        let imageData = pasteboard.tangleImageData()
        guard !text.isEmpty || html != nil || pdfData != nil || rtfData != nil || imageData != nil else {
            throw ClipboardError.noSupportedContentOnClipboard
        }

        return ClipboardContent(text: text, html: html, pdfData: pdfData, rtfData: rtfData, imageData: imageData)
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
    public var pdfData: Data?
    public var rtfData: Data?
    public var imageData: Data?

    public init(text: String, html: String? = nil, pdfData: Data? = nil, rtfData: Data? = nil, imageData: Data? = nil) {
        self.text = text
        self.html = html
        self.pdfData = pdfData
        self.rtfData = rtfData
        self.imageData = imageData
    }

    public var hasImage: Bool {
        imageData != nil
    }

    public var hasRichDocument: Bool {
        pdfData != nil || rtfData != nil
    }
}

private extension NSPasteboard {
    func tangleImageData() -> Data? {
        let preferredTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]

        for type in preferredTypes {
            if let data = data(forType: type), !data.isEmpty {
                return data
            }
        }

        return NSImage(pasteboard: self)?.tiffRepresentation
    }
}
