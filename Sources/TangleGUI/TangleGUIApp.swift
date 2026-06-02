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
                model.transformClipboard(.plainPaste, message: "Plain text ready")
            } label: {
                Label("Paste Cleaned Text    \(model.shortcutDisplay(for: .pasteCleanedText))", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v")

            Divider()

            Button {
                model.transformClipboard(.tableMarkdown, message: "Converted table")
            } label: {
                Label("Convert Table to Markdown", systemImage: "tablecells")
            }

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
        }
    }

    @Published var statusMessage = ""
    @Published var lastCharacterSavings: Int?
    @Published var lastPreview: TransformPreview?

    private let clipboard = ClipboardClient()
    private let hud = HUDController()
    private let shortcuts = GlobalShortcutManager()
    private let store = SettingsStore()

    init() {
        settings = store.load()
        registerShortcuts()
    }

    func transformClipboard(_ kind: TransformationKind, message: String) {
        do {
            let input = try clipboard.readText()
            let output = TangleTransformer(settings: settings).transform(input, kind: kind)
            try clipboard.writeText(output)

            let savings = input.count - output.count
            lastCharacterSavings = savings
            lastPreview = TransformPreview(kind: kind, input: input, output: output)
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
            self.transformClipboard(.cleanText, message: "Clipboard cleaned")
        } cleanURL: {
            self.transformClipboard(.cleanURL, message: "URL tracking removed")
        } markdown: {
            self.transformClipboard(.markdown, message: "Converted to Markdown")
        } pasteCleanedText: {
            self.transformClipboard(.plainPaste, message: "Plain text ready")
        }
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

struct SettingsView: View {
    @ObservedObject var model: TangleAppModel

    var body: some View {
        TabView {
            Form {
                Section("Behavior") {
                    Toggle("HUD", isOn: $model.settings.isHUDEnabled)
                    Toggle("Auto-paste", isOn: $model.settings.autoPasteAfterTransform)

                    if model.settings.autoPasteAfterTransform {
                        AccessibilityPermissionView(model: model)
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
                }

                Section("Status") {
                    Text(model.statusMessage.isEmpty ? "Ready" : model.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Section("Global Shortcuts") {
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
        case .cleanText:
            return "Clean Clipboard"
        case .cleanURL:
            return "Clean URL"
        case .markdown:
            return "Convert to Markdown"
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
