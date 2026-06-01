import AppKit
import SwiftUI
import TangleCore

@main
struct TangleGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TangleAppModel()

    var body: some Scene {
        MenuBarExtra("Tangle", systemImage: "text.badge.checkmark") {
            Button("Clean Clipboard") {
                model.transformClipboard(.cleanText, message: "Clipboard cleaned")
            }
            .keyboardShortcut("c")

            Button("Clean URL") {
                model.transformClipboard(.cleanURL, message: "URL tracking removed")
            }
            .keyboardShortcut("u")

            Button("Convert to Markdown") {
                model.transformClipboard(.markdown, message: "Converted to Markdown")
            }
            .keyboardShortcut("m")

            Divider()

            Button("Convert Table to Markdown") {
                model.transformClipboard(.tableMarkdown, message: "Converted table")
            }

            Button("Convert Table to CSV") {
                model.transformClipboard(.tableCSV, message: "Converted table")
            }

            Divider()

            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApp.terminate(nil)
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

    private let clipboard = ClipboardClient()
    private let store = SettingsStore()

    init() {
        settings = store.load()
    }

    func transformClipboard(_ kind: TransformationKind, message: String) {
        do {
            let input = try clipboard.readText()
            let output = TangleTransformer(settings: settings).transform(input, kind: kind)
            try clipboard.writeText(output)
            statusMessage = settings.isHUDEnabled ? message : ""

            if settings.autoPasteAfterTransform {
                pasteIntoFrontmostApp()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
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
        Form {
            Toggle("Show HUD feedback", isOn: $model.settings.isHUDEnabled)
            Toggle("Auto-paste after transform", isOn: $model.settings.autoPasteAfterTransform)

            Picker("Paragraph preservation", selection: $model.settings.paragraphPreservation) {
                Text("Conservative").tag(ParagraphPreservation.conservative)
                Text("Balanced").tag(ParagraphPreservation.balanced)
                Text("Aggressive").tag(ParagraphPreservation.aggressive)
            }

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
