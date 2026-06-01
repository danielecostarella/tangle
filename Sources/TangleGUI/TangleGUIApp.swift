import AppKit
import SwiftUI
import TangleCore

@main
struct TangleGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TangleAppModel()

    var body: some Scene {
        MenuBarExtra("Tangle", systemImage: "text.badge.checkmark") {
            Button {
                model.transformClipboard(.cleanText, message: "Clipboard cleaned")
            } label: {
                Label("Clean Clipboard", systemImage: "wand.and.sparkles")
            }
            .keyboardShortcut("c")

            Button {
                model.transformClipboard(.cleanURL, message: "URL tracking removed")
            } label: {
                Label("Clean URL", systemImage: "link")
            }
            .keyboardShortcut("u")

            Button {
                model.transformClipboard(.markdown, message: "Converted to Markdown")
            } label: {
                Label("Convert to Markdown", systemImage: "text.quote")
            }
            .keyboardShortcut("m")

            Button {
                model.transformClipboard(.plainPaste, message: "Plain text ready")
            } label: {
                Label("Paste Cleaned Text", systemImage: "doc.on.clipboard")
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
        }
    }

    @Published var statusMessage = ""
    @Published var lastCharacterSavings: Int?

    private let clipboard = ClipboardClient()
    private let hud = HUDController()
    private let store = SettingsStore()

    init() {
        settings = store.load()
    }

    func transformClipboard(_ kind: TransformationKind, message: String) {
        do {
            let input = try clipboard.readText()
            let output = TangleTransformer(settings: settings).transform(input, kind: kind)
            try clipboard.writeText(output)

            let savings = input.count - output.count
            lastCharacterSavings = savings
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

struct SettingsView: View {
    @ObservedObject var model: TangleAppModel

    var body: some View {
        TabView {
            Form {
                Section("Behavior") {
                    Toggle("HUD", isOn: $model.settings.isHUDEnabled)
                    Toggle("Auto-paste", isOn: $model.settings.autoPasteAfterTransform)
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
            }
            .tabItem {
                Label("General", systemImage: "slider.horizontal.3")
            }

            Form {
                Section("URL Parameters") {
                    LabeledContent("Blocked", value: "\(model.settings.blockedURLParameters.count)")
                    LabeledContent("Allowed", value: "\(model.settings.allowedURLParameters.count)")

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
        .frame(width: 440, height: 280)
    }
}
