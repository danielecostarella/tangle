# Tangle

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

## Build

```sh
swift build
```

## Run the Menu Bar App

```sh
swift run TangleGUI
```

The app runs as a menu bar utility and hides its Dock icon at launch.

## CLI

```sh
swift run tangle clean
swift run tangle clean --clipboard
swift run tangle url
pbpaste | swift run tangle url | pbcopy
cat notes.txt | swift run tangle clean
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
- Clean URL
  - Removes common tracking parameters such as `utm_*`, `fbclid`, `gclid`, `mc_cid`, and `mc_eid`.
  - Preserves meaningful query parameters.
  - Supports multiple URLs in copied text.

Scaffolded for iteration:

- Markdown normalization
- Table conversion to Markdown, CSV, and TSV
- Settings persistence
- Menu bar actions
- Optional paste-after-transform behavior

## Privacy

Tangle is local-first by design:

- No telemetry
- No network calls by default
- No AI or cloud dependency
- No accounts
- No hidden background sync

## License

MIT
