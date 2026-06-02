# Tangle

[![CI](https://github.com/danielecostarella/tangle/actions/workflows/ci.yml/badge.svg)](https://github.com/danielecostarella/tangle/actions/workflows/ci.yml)

Tangle is a lightweight, fast, privacy-first clipboard transformer for macOS.

It sits in the menu bar, reads the current text clipboard, applies predictable local transformations, and writes the result back to the clipboard. There is no telemetry, no account system, no cloud processing, and no network dependency in the app itself.

## Status

This repository currently contains the initial Swift package scaffold:

- `TangleCore`: local transformation logic, clipboard access, and settings persistence.
- `TangleGUI`: native SwiftUI menu bar app.
- `tangle`: command-line interface for scripting and automation.
- Unit tests for text cleanup and URL cleanup.

## Requirements

- macOS 14 or newer
- Swift 6 or newer
- Apple Silicon is the primary target for now

## Install

For the first unsigned preview release:

1. Download `Tangle.dmg` or `Tangle.zip` from the GitHub release.
2. Open the app.
3. If macOS blocks the first launch, use System Settings > Privacy & Security > Open Anyway.
4. Keep Tangle running in the menu bar.

The app is currently ad-hoc signed but not notarized. This is expected for preview releases; Developer ID signing and notarization are planned later.

If macOS says Tangle is damaged, remove the quarantine flag after copying the app to Applications:

```sh
xattr -dr com.apple.quarantine /Applications/Tangle.app
```

## First Run

Tangle has no Dock icon by default. Look for the Tangle icon in the menu bar.

Clipboard-only actions work locally without accounts or cloud services. If you enable Auto-paste, macOS may ask for Accessibility permission so Tangle can simulate `Command` + `V` into the frontmost app.

## Build

```sh
swift build
```

## Package

```sh
scripts/package-app.sh
```

The package script creates:

- `dist/Tangle.app`
- `dist/Tangle.zip`
- `dist/Tangle.dmg`

The current DMG and ZIP are unsigned and not notarized. Notarization and Homebrew distribution are intentionally postponed.

## Release

Push a version tag to create a draft prerelease with ZIP and DMG assets:

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Run the Menu Bar App

```sh
swift run TangleGUI
```

The app runs as a menu bar utility and hides its Dock icon at launch.

Current menu bar actions:

- Clean Clipboard: `Control` + `Option` + `Command` + `C`
- Clean URL: `Control` + `Option` + `Command` + `U`
- Convert to Markdown: `Control` + `Option` + `Command` + `M`
- Paste Cleaned Text: `Control` + `Option` + `Command` + `V`
- Convert Table to Markdown, CSV, or TSV

The settings window includes HUD feedback, auto-paste, cleanup mode, Markdown preset, preview/diff, shortcut customization, and URL parameter controls.

Clipboard-only shortcuts do not send text anywhere. Auto-paste simulates `Command` + `V` locally and may require macOS Accessibility permission.

Shortcut keys are customizable in Settings. The modifier chord is fixed to `Control` + `Option` + `Command` for this first release.

The Preview tab shows before/after clipboard text plus local character and approximate token savings. Token estimates are intentionally rough and never call external services.

## CLI

```sh
swift run tangle clean
swift run tangle clean --mode aggressive --stats
swift run tangle clean --clipboard
swift run tangle url
swift run tangle markdown
swift run tangle markdown --preset llm --stats
swift run tangle table --to markdown
swift run tangle table --to csv
pbpaste | swift run tangle url | pbcopy
cat notes.txt | swift run tangle clean
pbpaste | swift run tangle markdown --preset llm | pbcopy
```

When stdin is piped, the CLI reads stdin and writes stdout. With `--clipboard`, or when no stdin is piped, it reads and writes the macOS clipboard.

## Test

```sh
swift test
```

## Transformations

Implemented in this first version:

- Clean Text
  - Normalizes whitespace.
  - Removes safe invisible/control characters.
  - Collapses repeated blank lines.
  - Joins common wrapped paragraph text.
  - Repairs common PDF hyphenated line breaks.
  - Removes repeated short header/footer noise after the first occurrence.
- Clean URL
  - Removes common tracking parameters such as `utm_*`, `fbclid`, `gclid`, `mc_cid`, and `mc_eid`.
  - Preserves meaningful query parameters.
  - Supports multiple URLs in copied text.
- Markdown
  - Converts PDF/web text into conservative Markdown.
  - Normalizes bullet characters.
  - Converts underline headings and obvious all-caps headings.
  - Includes an `llm` preset for compact, token-conscious output.
- Table conversion
  - Converts TSV-like and CSV-like copied text to Markdown tables, CSV, or TSV.
  - Escapes quoted CSV values safely.

Still needs product hardening:

- Signed and notarized release artifacts
- Homebrew cask
- More long-form PDF and web fixtures

## Release Notes

### v0.1.2

- Improves cleanup for PDF text containing hidden hyphen/control characters.
- Adds a fixture based on software-defined vehicle report text copied from PDF.
- Preserves compounds such as `software-driven`, `hardware-led`, and `vehicle-wide` instead of collapsing them.

## PDF/Text to LLM Markdown

One of Tangle's core workflows is cleaning text copied from PDFs before sending it to an LLM:

```sh
pbpaste | swift run tangle markdown --preset llm --stats | pbcopy
```

This keeps the transformation local while reducing common token waste from wrapped lines, repeated page headers, page numbers, and inconsistent bullets.

## Privacy

Tangle is local-first by design:

- No telemetry
- No network calls by default
- No AI or cloud dependency
- No accounts
- No hidden background sync

## License

MIT
