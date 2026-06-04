import AppKit
import ApplicationServices
import SwiftUI
import TangleCore

@main
struct TangleGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TangleAppModel()

    var body: some Scene {
        MenuBarExtra {
            Button {
                model.showQuickTransformPicker()
            } label: {
                Label("Quick Transform Picker    \(model.shortcutDisplay(for: .quickTransformPicker))", systemImage: "rectangle.and.text.magnifyingglass")
            }
            .keyboardShortcut("p")

            Button {
                model.transformClipboard(.smart, message: "Smart transform complete")
            } label: {
                Label("Smart Transform", systemImage: "sparkles")
            }

            Button {
                model.transformClipboard(.cleanText, message: "Clipboard cleaned")
            } label: {
                Label("Clean Clipboard    \(model.shortcutDisplay(for: .cleanClipboard))", systemImage: "wand.and.sparkles")
            }
            .keyboardShortcut("c")

            Button {
                model.transformClipboard(.cleanURL, message: "URL tracking removed")
            } label: {
                Label("Clean URL    \(model.shortcutDisplay(for: .cleanURL))", systemImage: "link")
            }
            .keyboardShortcut("u")

            Button {
                model.transformClipboard(.markdown, message: "Converted to Markdown")
            } label: {
                Label("Convert to Markdown    \(model.shortcutDisplay(for: .markdown))", systemImage: "text.quote")
            }
            .keyboardShortcut("m")

            Button {
                model.transformClipboard(.imageText, message: "Text extracted from image")
            } label: {
                Label("Extract Text from Image", systemImage: "text.viewfinder")
            }

            Button {
                model.transformClipboard(.imageMarkdown, message: "Image converted to Markdown")
            } label: {
                Label("Convert Image to Markdown", systemImage: "photo.badge.checkmark")
            }

            Button {
                model.transformClipboard(.plainPaste, message: "Plain text ready")
            } label: {
                Label("Paste Cleaned Text    \(model.shortcutDisplay(for: .pasteCleanedText))", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v")

            Divider()

            Menu("Convert Table") {
                Button("Markdown") {
                    model.transformClipboard(.tableMarkdown, message: "Converted table")
                }

                Button("CSV") {
                    model.transformClipboard(.tableCSV, message: "Converted table")
                }

                Button("TSV") {
                    model.transformClipboard(.tableTSV, message: "Converted table")
                }
            }

            Divider()

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if model.canRestoreOriginalClipboard {
                Button {
                    model.restoreOriginalClipboard()
                } label: {
                    Label("Restore Original Clipboard", systemImage: "arrow.uturn.backward")
                }
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: TangleMenuBarIcon.image)
                .accessibilityLabel("Tangle")
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
final class TangleAppModel: ObservableObject {
    @Published var settings: TangleSettings {
        didSet {
            store.save(settings)
            registerShortcuts()
            configurePasteboardPolling()
        }
    }

    @Published var statusMessage = ""
    @Published var lastCharacterSavings: Int?
    @Published var lastPreview: TransformPreview?
    @Published var canRestoreOriginalClipboard = false

    private let clipboard = ClipboardClient()
    private let hud = HUDController()
    private let shortcuts = GlobalShortcutManager()
    private let store = SettingsStore()
    private let quickTransformPanel = QuickTransformPanelController()
    private var pasteboardPollTimer: Timer?
    private var observedPasteboardChangeCount = NSPasteboard.general.changeCount
    private var originalClipboardBeforeAutoTransform: String?

    init() {
        settings = store.load()
        registerShortcuts()
        configurePasteboardPolling()
    }

    func transformClipboard(_ kind: TransformationKind, message: String) {
        do {
            let input = try clipboard.readContent()
            let output = try TangleTransformer(settings: settings).transformContent(input, kind: kind)
            try clipboard.writeText(output)

            let savings = input.text.count - output.count
            lastCharacterSavings = savings
            lastPreview = TransformPreview(kind: kind, input: input.previewText, output: output)
            statusMessage = statusText(message: message, savings: savings)

            if settings.isHUDEnabled {
                hud.show(message: statusMessage)
            }

            if settings.autoPasteAfterTransform {
                pasteIntoFrontmostApp()
            }
        } catch {
            statusMessage = error.localizedDescription
            lastCharacterSavings = nil

            if settings.isHUDEnabled {
                hud.show(message: statusMessage, isError: true)
            }
        }
    }

    func showQuickTransformPicker() {
        quickTransformPanel.show(model: self)
    }

    func quickTransformOptions() async throws -> QuickTransformState {
        let input = try clipboard.readContent()
        let detection = SmartClipboardDetector().detect(input)
        let settings = settings

        return try await Task.detached(priority: .userInitiated) {
            let kinds: [TransformationKind] = [
                .smart,
                .cleanText,
                .cleanURL,
                .markdown,
                .imageText,
                .imageMarkdown,
                .tableMarkdown,
                .tableCSV,
                .tableTSV,
                .plainPaste
            ]
            let transformer = TangleTransformer(settings: settings)
            let imageOCRLines = try input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? input.imageData.map {
                    try ImageOCRTransformer(
                        minimumConfidence: settings.ocrMinimumConfidence,
                        recognitionLanguages: settings.ocrRecognitionLanguages
                    ).recognizeLines(in: $0)
                }
                : nil
            let imageFormatter = ImageMarkdownFormatter()
            let options = try kinds.map { kind in
                let output: String
                if let imageOCRLines {
                    switch kind {
                    case .smart, .imageMarkdown:
                        output = imageFormatter.markdown(from: imageOCRLines)
                    case .imageText:
                        output = imageFormatter.plainText(from: imageOCRLines)
                    default:
                        output = try transformer.transformContent(input, kind: kind)
                    }
                } else {
                    output = try transformer.transformContent(input, kind: kind)
                }

                return QuickTransformOption(
                    kind: kind,
                    input: input,
                    output: output,
                    isRecommended: kind == detection.recommendedTransformation || (kind == .smart && detection.confidence >= 0.75)
                )
            }

            return QuickTransformState(detection: detection, options: options)
        }.value
    }

    func applyQuickTransform(_ option: QuickTransformOption) {
        do {
            try clipboard.writeText(option.output)
            observedPasteboardChangeCount = NSPasteboard.general.changeCount
            lastCharacterSavings = option.stats.characterDelta
            lastPreview = TransformPreview(kind: option.kind, input: option.input.previewText, output: option.output)
            statusMessage = statusText(message: "\(option.kind.displayName) applied", savings: option.stats.characterDelta)
            quickTransformPanel.close()

            if settings.isHUDEnabled {
                hud.show(message: statusMessage)
            }

            if settings.autoPasteAfterTransform {
                pasteIntoFrontmostApp()
            }
        } catch {
            statusMessage = error.localizedDescription
            if settings.isHUDEnabled {
                hud.show(message: statusMessage, isError: true)
            }
        }
    }

    func cancelQuickTransform() {
        quickTransformPanel.close()
    }

    func restoreOriginalClipboard() {
        guard let originalClipboardBeforeAutoTransform else { return }

        do {
            try clipboard.writeText(originalClipboardBeforeAutoTransform)
            observedPasteboardChangeCount = NSPasteboard.general.changeCount
            self.originalClipboardBeforeAutoTransform = nil
            canRestoreOriginalClipboard = false
            statusMessage = "Original clipboard restored"
            if settings.isHUDEnabled {
                hud.show(message: statusMessage)
            }
        } catch {
            statusMessage = error.localizedDescription
            if settings.isHUDEnabled {
                hud.show(message: statusMessage, isError: true)
            }
        }
    }

    func resetURLParameters() {
        settings.allowedURLParameters = []
        settings.blockedURLParameters = URLCleaner.defaultBlockedParameters
    }

    func copyPreviewOutput() {
        guard let lastPreview else { return }

        do {
            try clipboard.writeText(lastPreview.output)
            statusMessage = "Preview output copied"
            if settings.isHUDEnabled {
                hud.show(message: statusMessage)
            }
        } catch {
            statusMessage = error.localizedDescription
            if settings.isHUDEnabled {
                hud.show(message: statusMessage, isError: true)
            }
        }
    }

    func shortcutDisplay(for action: TangleShortcutAction) -> String {
        (settings.shortcutKeys[action] ?? TangleSettings.defaultShortcutKeys[action] ?? .c).displayName
    }

    func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    private func registerShortcuts() {
        shortcuts.register(shortcutKeys: settings.shortcutKeys) {
            self.showQuickTransformPicker()
        } cleanClipboard: {
            self.transformClipboard(.cleanText, message: "Clipboard cleaned")
        } cleanURL: {
            self.transformClipboard(.cleanURL, message: "URL tracking removed")
        } markdown: {
            self.transformClipboard(.markdown, message: "Converted to Markdown")
        } pasteCleanedText: {
            self.transformClipboard(.plainPaste, message: "Plain text ready")
        }
    }

    private func configurePasteboardPolling() {
        pasteboardPollTimer?.invalidate()
        pasteboardPollTimer = nil

        guard settings.autoTransformOnCopy else { return }

        observedPasteboardChangeCount = NSPasteboard.general.changeCount
        pasteboardPollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handlePasteboardChangeIfNeeded()
            }
        }
    }

    private func handlePasteboardChangeIfNeeded() {
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != observedPasteboardChangeCount else { return }
        observedPasteboardChangeCount = changeCount

        guard settings.autoTransformOnCopy,
              let content = try? clipboard.readContent() else {
            return
        }

        let detection = SmartClipboardDetector().detect(content)
        guard shouldAutoTransform(content: content, detection: detection) else { return }

        guard detection.kind != .image else { return }

        let output = TangleTransformer(settings: settings).transform(content, kind: detection.recommendedTransformation)
        guard output != content.text else { return }

        do {
            originalClipboardBeforeAutoTransform = content.text
            canRestoreOriginalClipboard = true
            try clipboard.writeText(output)
            observedPasteboardChangeCount = NSPasteboard.general.changeCount

            let stats = TransformationStats(input: content.text, output: output)
            lastCharacterSavings = stats.characterDelta
            lastPreview = TransformPreview(kind: detection.recommendedTransformation, input: content.previewText, output: output)
            statusMessage = statusText(message: "Auto-transformed \(detection.kind.rawValue)", savings: stats.characterDelta)

            if settings.isHUDEnabled {
                hud.show(message: statusMessage)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func shouldAutoTransform(content: ClipboardContent, detection: SmartClipboardDetection) -> Bool {
        let text = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 20,
              detection.confidence >= settings.autoTransformConfidenceThreshold,
              detection.kind != .code,
              !text.looksLikePasswordFragment,
              !Self.passwordManagerBundleIdentifiers.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") else {
            return false
        }

        return true
    }

    private func statusText(message: String, savings: Int) -> String {
        guard savings != 0 else { return message }

        if savings > 0 {
            return "\(message) · \(savings) chars saved"
        }

        return "\(message) · \(abs(savings)) chars added"
    }

    private func pasteIntoFrontmostApp() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private extension TangleAppModel {
    static let passwordManagerBundleIdentifiers: Set<String> = [
        "com.1password.1password",
        "com.1password.1password7",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.getdropbox.DropboxPasswordManager",
        "com.keepassx.keepassxc"
    ]
}

private extension ClipboardContent {
    var previewText: String {
        if !text.isEmpty {
            return text
        }

        if hasImage {
            return "[Image clipboard]"
        }

        return ""
    }
}

private extension String {
    var looksLikePasswordFragment: Bool {
        guard !contains(where: \.isWhitespace),
              count >= 8,
              range(of: #"[0-9]"#, options: .regularExpression) != nil,
              range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil else {
            return false
        }

        return true
    }
}

struct TransformPreview: Equatable {
    let kind: TransformationKind
    let input: String
    let output: String
    let stats: TransformationStats

    init(kind: TransformationKind, input: String, output: String) {
        self.kind = kind
        self.input = input
        self.output = output
        stats = TransformationStats(input: input, output: output)
    }
}

struct QuickTransformState: Sendable {
    let detection: SmartClipboardDetection
    let options: [QuickTransformOption]
}

struct QuickTransformOption: Identifiable, Sendable {
    var id: TransformationKind { kind }
    let kind: TransformationKind
    let input: ClipboardContent
    let output: String
    let isRecommended: Bool
    let stats: TransformationStats

    init(kind: TransformationKind, input: ClipboardContent, output: String, isRecommended: Bool) {
        self.kind = kind
        self.input = input
        self.output = output
        self.isRecommended = isRecommended
        stats = TransformationStats(input: input.previewText, output: output)
    }
}

@MainActor
final class QuickTransformPanelController {
    private var panel: NSPanel?

    func show(model: TangleAppModel) {
        let view = QuickTransformPickerView(model: model)
        let hostingController = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Tangle Quick Transform"
        panel.level = .floating
        panel.center()
        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

struct QuickTransformPickerView: View {
    @ObservedObject var model: TangleAppModel
    @State private var state: QuickTransformState?
    @State private var selectedKind: TransformationKind = .smart
    @State private var errorMessage: String?

    private var selectedOption: QuickTransformOption? {
        state?.options.first { $0.kind == selectedKind }
            ?? state?.options.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let errorMessage {
                ContentUnavailableView("No Clipboard Preview", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let state, let selectedOption {
                HStack(alignment: .top, spacing: 14) {
                    optionsList(state.options)
                        .frame(width: 280)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(optionStatsLine(selectedOption))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            PreviewContentPane(title: "Before", option: selectedOption, text: truncated(selectedOption.input.previewText))
                            PreviewTextPane(title: "After", text: truncated(selectedOption.output))
                        }
                    }
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        model.cancelQuickTransform()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Apply") {
                        model.applyQuickTransform(selectedOption)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(minWidth: 820, minHeight: 520)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Transform")
                .font(.title2.weight(.semibold))
            if let state {
                Text("Detected \(state.detection.kind.rawValue) · confidence \(state.detection.confidence.formatted(.number.precision(.fractionLength(2))))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Preview the current clipboard before applying a transformation.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func optionsList(_ options: [QuickTransformOption]) -> some View {
        List(options, selection: $selectedKind) { option in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(option.kind.displayName)
                        .font(.headline)
                    if option.isRecommended {
                        Text("recommended")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(optionStatsLine(option))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(option.kind)
        }
    }

    private func load() {
        Task {
            do {
                let state = try await model.quickTransformOptions()
                self.state = state
                selectedKind = state.options.first(where: \.isRecommended)?.kind ?? state.options.first?.kind ?? .smart
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func optionStatsLine(_ option: QuickTransformOption) -> String {
        let charWord = option.stats.characterDelta >= 0 ? "saved" : "added"
        let tokenWord = option.stats.estimatedTokenDelta >= 0 ? "saved" : "added"
        return "\(abs(option.stats.characterDelta)) chars \(charWord) · ~\(abs(option.stats.estimatedTokenDelta)) tokens \(tokenWord)"
    }

    private func truncated(_ text: String) -> String {
        guard text.count > 5_000 else { return text }
        return String(text.prefix(5_000)) + "\n\n[Preview truncated]"
    }
}

struct SettingsView: View {
    @ObservedObject var model: TangleAppModel

    var body: some View {
        TabView {
            Form {
                Section("Behavior") {
                    Toggle("HUD", isOn: $model.settings.isHUDEnabled)
                    Toggle("Auto-paste", isOn: $model.settings.autoPasteAfterTransform)
                    Toggle("Auto-transform on copy", isOn: $model.settings.autoTransformOnCopy)

                    if model.settings.autoPasteAfterTransform {
                        AccessibilityPermissionView(model: model)
                    }

                    if model.settings.autoTransformOnCopy {
                        VStack(alignment: .leading, spacing: 6) {
                            Slider(
                                value: $model.settings.autoTransformConfidenceThreshold,
                                in: 0.75...0.95,
                                step: 0.05
                            )

                            Text("Silent mode runs only when Tangle is confident, skips code-like and password-like clipboard content, and can restore the original clipboard from the menu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Confidence: \(model.settings.autoTransformConfidenceThreshold.formatted(.number.precision(.fractionLength(2))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Transformations") {
                    Picker("Text cleanup", selection: $model.settings.paragraphPreservation) {
                        Text("Conservative").tag(ParagraphPreservation.conservative)
                        Text("Balanced").tag(ParagraphPreservation.balanced)
                        Text("Aggressive").tag(ParagraphPreservation.aggressive)
                    }

                    Picker("Markdown", selection: $model.settings.markdownPreset) {
                        Text("LLM").tag(MarkdownPreset.llm)
                        Text("Standard").tag(MarkdownPreset.standard)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Slider(
                            value: Binding {
                                Double(model.settings.ocrMinimumConfidence)
                            } set: { newValue in
                                model.settings.ocrMinimumConfidence = Float(newValue)
                            },
                            in: 0.1...0.9,
                            step: 0.05
                        )

                        Text("OCR confidence: \(Double(model.settings.ocrMinimumConfidence).formatted(.number.precision(.fractionLength(2))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField(
                        "OCR languages",
                        text: Binding {
                            model.settings.ocrRecognitionLanguages.joined(separator: ", ")
                        } set: { newValue in
                            let languages = newValue
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            model.settings.ocrRecognitionLanguages = languages.isEmpty ? ["en-US", "it-IT"] : languages
                        }
                    )
                }

                Section("Status") {
                    Text(model.statusMessage.isEmpty ? "Ready" : model.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Section("Global Shortcuts") {
                    ShortcutPicker(action: .quickTransformPicker, model: model)
                    ShortcutPicker(action: .cleanClipboard, model: model)
                    ShortcutPicker(action: .cleanURL, model: model)
                    ShortcutPicker(action: .markdown, model: model)
                    ShortcutPicker(action: .pasteCleanedText, model: model)
                }
            }
            .tabItem {
                Label("General", systemImage: "slider.horizontal.3")
            }

            PreviewView(model: model)
                .tabItem {
                    Label("Preview", systemImage: "rectangle.split.2x1")
                }

            Form {
                Section("URL Parameters") {
                    ParameterListEditor(
                        title: "Blocked",
                        parameters: $model.settings.blockedURLParameters
                    )

                    ParameterListEditor(
                        title: "Allowed",
                        parameters: $model.settings.allowedURLParameters
                    )

                    Button("Reset Defaults") {
                        model.resetURLParameters()
                    }
                }
            }
            .tabItem {
                Label("URL", systemImage: "link")
            }
        }
        .padding(24)
        .frame(width: 680, height: 520)
    }
}

struct AccessibilityPermissionView: View {
    @ObservedObject var model: TangleAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(model.isAccessibilityTrusted ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)

                Text(model.isAccessibilityTrusted ? "Accessibility allowed" : "Accessibility required")
                    .font(.headline)
            }

            Text(model.isAccessibilityTrusted ? "Auto-paste can send the transformed clipboard to the frontmost app." : "Auto-paste needs permission to simulate Command-V locally.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Request Permission") {
                    model.requestAccessibilityPermission()
                }

                Button("Open Settings") {
                    model.openAccessibilitySettings()
                }
            }
        }
    }
}

struct PreviewView: View {
    @ObservedObject var model: TangleAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = model.lastPreview {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.kind.displayName)
                            .font(.headline)
                        Text(statsLine(preview.stats))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Copy Output") {
                        model.copyPreviewOutput()
                    }
                }

                HStack(spacing: 12) {
                    PreviewTextPane(title: "Before", text: preview.input)
                    PreviewTextPane(title: "After", text: preview.output)
                }
            } else {
                ContentUnavailableView(
                    "No Preview Yet",
                    systemImage: "rectangle.split.2x1",
                    description: Text("Run a transformation from the menu to compare clipboard input and output.")
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func statsLine(_ stats: TransformationStats) -> String {
        let charWord = stats.characterDelta >= 0 ? "saved" : "added"
        let tokenWord = stats.estimatedTokenDelta >= 0 ? "saved" : "added"
        return "\(abs(stats.characterDelta)) chars \(charWord) · ~\(abs(stats.estimatedTokenDelta)) tokens \(tokenWord)"
    }
}

struct PreviewTextPane: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ScrollView {
                Text(text.isEmpty ? " " : text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 240)
            .background(Color(nsColor: .textBackgroundColor))
            .border(.separator)
        }
    }
}

struct PreviewContentPane: View {
    let title: String
    let option: QuickTransformOption
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ScrollView {
                if option.input.hasImage, let imageData = option.input.imageData, let image = NSImage(data: imageData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(10)
                } else {
                    Text(text.isEmpty ? " " : text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
            .frame(minHeight: 240)
            .background(Color(nsColor: .textBackgroundColor))
            .border(.separator)
        }
    }
}

struct ShortcutPicker: View {
    let action: TangleShortcutAction
    @ObservedObject var model: TangleAppModel

    var body: some View {
        Picker(action.label, selection: shortcutBinding) {
            ForEach(TangleShortcutKey.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
    }

    private var shortcutBinding: Binding<TangleShortcutKey> {
        Binding {
            model.settings.shortcutKeys[action] ?? TangleSettings.defaultShortcutKeys[action] ?? .c
        } set: { newValue in
            model.settings.shortcutKeys[action] = newValue
        }
    }
}

private extension TransformationKind {
    var displayName: String {
        switch self {
        case .smart:
            return "Smart Transform"
        case .cleanText:
            return "Clean Clipboard"
        case .cleanURL:
            return "Clean URL"
        case .markdown:
            return "Convert to Markdown"
        case .imageText:
            return "Extract Text from Image"
        case .imageMarkdown:
            return "Convert Image to Markdown"
        case .tableMarkdown:
            return "Convert Table to Markdown"
        case .tableCSV:
            return "Convert Table to CSV"
        case .tableTSV:
            return "Convert Table to TSV"
        case .plainPaste:
            return "Paste Cleaned Text"
        }
    }
}

struct ParameterListEditor: View {
    let title: String
    @Binding var parameters: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            TextEditor(text: textBinding)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 96)
                .border(.separator)

            Text("\(parameters.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var textBinding: Binding<String> {
        Binding {
            parameters.sorted().joined(separator: "\n")
        } set: { value in
            parameters = Set(
                value
                    .components(separatedBy: CharacterSet(charactersIn: ",\n\t "))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        }
    }
}
