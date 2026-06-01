import AppKit

enum TangleMenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let stem = NSBezierPath(roundedRect: NSRect(x: 7.4, y: 3, width: 3.2, height: 12), xRadius: 1.4, yRadius: 1.4)
        stem.fill()

        let top = NSBezierPath(roundedRect: NSRect(x: 3.2, y: 13, width: 11.6, height: 2.8), xRadius: 1.4, yRadius: 1.4)
        top.fill()

        drawWave(y: 5.5)
        drawWave(y: 2.7)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()

    private static func drawWave(y: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 3.5, y: y))
        path.curve(
            to: NSPoint(x: 14.5, y: y),
            controlPoint1: NSPoint(x: 6.2, y: y + 2.2),
            controlPoint2: NSPoint(x: 11.8, y: y - 2.2)
        )
        path.stroke()
    }
}
