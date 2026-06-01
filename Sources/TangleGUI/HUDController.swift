import AppKit

@MainActor
final class HUDController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(message: String, isError: Bool = false) {
        dismissTask?.cancel()

        let panel = panel ?? makePanel()
        self.panel = panel

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = isError ? .systemRed : .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 76))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
        ])

        panel.contentView = effect
        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(1.7))
            guard !Task.isCancelled, let panel else { return }
            self?.hide(panel)
        }
    }

    private func hide(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - panel.frame.height - 36
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
