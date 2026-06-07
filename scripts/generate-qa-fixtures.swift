#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".qa-fixtures", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let pageSize = CGSize(width: 612, height: 792)
let bodyFont = NSFont.systemFont(ofSize: 12)
let headingFont = NSFont.boldSystemFont(ofSize: 20)
let smallFont = NSFont.systemFont(ofSize: 9)

func draw(_ text: String, in rect: CGRect, font: NSFont = bodyFont) {
    NSString(string: text).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: NSColor.black
        ]
    )
}

func makePDF(named name: String, pages: [() -> Void]) throws {
    let url = outputDirectory.appendingPathComponent(name)
    var mediaBox = CGRect(origin: .zero, size: pageSize)
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "TangleQA", code: 1)
    }

    for page in pages {
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        page()
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
    }
    context.closePDF()
}

try makePDF(named: "text-layer.pdf", pages: [
    {
        draw("TANGLE QA REPORT", in: CGRect(x: 72, y: 700, width: 460, height: 30), font: headingFont)
        draw("1 Overview", in: CGRect(x: 72, y: 655, width: 460, height: 25), font: headingFont)
        draw(
            "This selectable paragraph is deliberately wrapped across several lines. "
                + "Tangle should preserve the paragraph while repairing the line wrapping.",
            in: CGRect(x: 72, y: 555, width: 360, height: 80)
        )
        draw("TANGLE QA REPORT", in: CGRect(x: 72, y: 30, width: 180, height: 15), font: smallFont)
        draw("Page 1 of 2", in: CGRect(x: 470, y: 30, width: 80, height: 15), font: smallFont)
    },
    {
        draw("TANGLE QA REPORT", in: CGRect(x: 72, y: 700, width: 460, height: 30), font: headingFont)
        draw("1.1 Details", in: CGRect(x: 72, y: 655, width: 460, height: 25), font: headingFont)
        draw("A second page verifies repeated header and footer removal.", in: CGRect(x: 72, y: 600, width: 420, height: 40))
        draw("TANGLE QA REPORT", in: CGRect(x: 72, y: 30, width: 180, height: 15), font: smallFont)
        draw("Page 2 of 2", in: CGRect(x: 470, y: 30, width: 80, height: 15), font: smallFont)
    }
])

try makePDF(named: "complex-layout.pdf", pages: [
    {
        draw("MULTI-COLUMN REPORT", in: CGRect(x: 72, y: 710, width: 468, height: 30), font: headingFont)
        draw("LEFT COLUMN\nAlpha begins the left column.\nBeta remains on the left.\nGamma closes the left column.", in: CGRect(x: 72, y: 510, width: 210, height: 170))
        draw("RIGHT COLUMN\nOne begins the right column.\nTwo remains on the right.\nThree closes the right column.", in: CGRect(x: 330, y: 510, width: 210, height: 170))
    },
    {
        draw("TABLE AND FOOTNOTES", in: CGRect(x: 72, y: 710, width: 468, height: 30), font: headingFont)
        draw("Product", in: CGRect(x: 72, y: 650, width: 120, height: 20), font: NSFont.boldSystemFont(ofSize: 12))
        draw("Q1", in: CGRect(x: 240, y: 650, width: 80, height: 20), font: NSFont.boldSystemFont(ofSize: 12))
        draw("Q2", in: CGRect(x: 360, y: 650, width: 80, height: 20), font: NSFont.boldSystemFont(ofSize: 12))
        draw("Widget A", in: CGRect(x: 72, y: 615, width: 120, height: 20))
        draw("42", in: CGRect(x: 240, y: 615, width: 80, height: 20))
        draw("51", in: CGRect(x: 360, y: 615, width: 80, height: 20))
        draw("Widget B", in: CGRect(x: 72, y: 580, width: 120, height: 20))
        draw("38", in: CGRect(x: 240, y: 580, width: 80, height: 20))
        draw("49", in: CGRect(x: 360, y: 580, width: 80, height: 20))
        draw("Revenue increased significantly.1", in: CGRect(x: 72, y: 500, width: 400, height: 30))
        draw("1. Values are illustrative and locally generated.", in: CGRect(x: 72, y: 80, width: 400, height: 20), font: smallFont)
    }
])

let scanImage = NSImage(size: pageSize)
scanImage.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: pageSize).fill()
draw("SCANNED PAGE", in: CGRect(x: 72, y: 700, width: 460, height: 30), font: headingFont)
draw("This page has no PDF text layer.\nApple Vision should recognize this sentence.\n• Local OCR\n• Private processing", in: CGRect(x: 72, y: 520, width: 460, height: 150), font: NSFont.systemFont(ofSize: 18))
scanImage.unlockFocus()

guard let tiff = scanImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "TangleQA", code: 2)
}
try png.write(to: outputDirectory.appendingPathComponent("scanned-page.png"))

try makePDF(named: "scanned.pdf", pages: [
    {
        scanImage.draw(in: CGRect(origin: .zero, size: pageSize))
    }
])

print(outputDirectory.path)
