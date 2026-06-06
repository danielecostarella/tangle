# Tangle

[![CI](https://github.com/danielecostarella/tangle/actions/workflows/ci.yml/badge.svg)](https://github.com/danielecostarella/tangle/actions/workflows/ci.yml)

Tangle is a lightweight, fast, privacy-first clipboard transformer for macOS.

It sits in the menu bar. Copy anything — text, a screenshot, an image, Excel cells, a web page — press a shortcut, and get clean Markdown or plain text back in your clipboard instantly. No cloud, no account, no setup.

## What's Inside

- `TangleCore`: local transformation logic, clipboard access, and settings persistence.
- `TangleGUI`: native SwiftUI menu bar app.
- `tangle`: command-line interface for scripting and automation.
- 66 unit tests covering text cleanup, URL cleaning, Markdown conversion, smart detection, image OCR formatting, PDF/RTF clipboard extraction, clipboard history, table detection, and bold formatting.

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

## What Tangle Is For

Tangle is useful when the content you copied is technically correct, but annoying to paste somewhere else.

Common examples:

- You copy text from a PDF and it arrives with broken lines, repeated headers, page numbers, and strange spacing.
- You copy a web article and want clean Markdown with headings, links, bold text, and lists.
- You copy a long URL and want to remove tracking parameters before sharing it.
- You copy a table from a webpage or spreadsheet and want Markdown, CSV, or TSV.
- You copy a screenshot of a spreadsheet or presentation and want a structured Markdown table.
- You copy a screenshot or image and want local OCR text or Markdown — with headings, bullets, and bold correctly detected.
- You want to paste plain text into Mail, Slack, Notes, Notion, or an editor without bringing along formatting.
- You want to reduce token waste before pasting copied material into an LLM.

## How It Works

The two primary actions cover the most common cases automatically:

**Paste Markdown** (`⌃⌥⌘M`) detects what is on the clipboard and produces the best Markdown output:
- Image or screenshot → Apple Vision OCR → Markdown with headings, bullets, tables, and bold
- PDF or RTF clipboard data → local text-layer extraction before OCR
- Rich HTML (web page, email) → clean Markdown preserving structure
- Table text or screenshot of a table → Markdown table
- URL → cleaned URL with tracking parameters removed
- Plain text → cleaned text

**Paste Clean Text** (`⌃⌥⌘C`) does the same but always produces plain text:
- Image or screenshot → Apple Vision OCR → plain text
- PDF or RTF clipboard data → local text extraction
- Any text → whitespace normalized, line breaks repaired, PDF artifacts removed
- URL → cleaned URL

For advanced use, **Quick Transform Picker** (`⌃⌥⌘P`) shows a before/after preview of every available transformation and lets you choose one before applying it.

**Clipboard History** (`⌃⌥⌘B`) is an optional, session-only list of recently copied text. It is disabled by default, never written to disk, excludes images, respects macOS concealed/transient clipboard markers, and skips known password managers and password-like content.

## Everyday Examples

### Clean Up Text From a PDF

Copy text from a PDF, then press **`⌃⌥⌘C`** (Paste Clean Text).

Before:
```text
Software-defined vehi-
cles are shifting the industry
from hardware-led products
to software-driven platforms.
```

After:
```text
Software-defined vehicles are shifting the industry from hardware-led products to software-driven platforms.
```

### Turn a Web Page Selection Into Markdown

Copy part of a web page, then press **`⌃⌥⌘M`** (Paste Markdown).

```markdown
## Market Outlook: next-generation mobility

The **mobility sector** is changing quickly as software, services, and infrastructure converge.

Read the [industry report](https://example.com/reports/mobility-outlook).
```

### Convert a Screenshot of a Spreadsheet

Copy a screenshot of an Excel table, then press **`⌃⌥⌘M`** (Paste Markdown).

```markdown
| Product  | Q1      | Q2      | Q3      | Q4      |
| ---      | ---     | ---     | ---     | ---     |
| Widget A | $12,400 | $15,200 | $18,900 | $22,100 |
| Widget B | $8,700  | $9,100  | $11,300 | $14,500 |
| TOTAL    | $21,100 | $24,300 | $30,200 | $36,600 |
```

Tangle detects the grid structure from the Vision bounding boxes and reconstructs the table automatically.

### Extract Text and Formatting From an Image

Copy a screenshot of a presentation slide, then press **`⌃⌥⌘M`**.

```markdown
# QUARTERLY RESULTS

Revenue grew 23% year-over-year

- Product ARR: $42M (+31%)
- Enterprise customers: 1,240
- Net Revenue Retention: 118%
```

Tangle uses Apple Vision locally: no image leaves your Mac. Heading levels (H1/H2/H3) are inferred from relative font size. Bold text is detected from stroke width. Bullet characters are normalized.

### Share a Cleaner URL

Copy a URL with tracking parameters, then press **`⌃⌥⌘M`** or **`⌃⌥⌘U`** (Clean URL).

Before:
```text
https://example.com/article?utm_source=google&utm_medium=cpc&gclid=abc&id=42
```

After:
```text
https://example.com/article?id=42
```

## OCR Language Support

Tangle uses Apple Vision for on-device OCR. The default languages are **English** and **Italian** (`en-US, it-IT`).

The following language codes are supported (configurable in Settings → Transformations → OCR languages):

| Language | Code |
| --- | --- |
| English | `en-US` |
| Italian | `it-IT` |
| French | `fr-FR` |
| German | `de-DE` |
| Spanish | `es-ES` |
| Portuguese | `pt-BR` |
| Chinese Simplified | `zh-Hans` |
| Chinese Traditional | `zh-Hant` |
| Japanese | `ja-JP` |
| Korean | `ko-KR` |
| Russian | `ru-RU` |
| Ukrainian | `uk-UA` |
| Arabic | `ar-SA` |
| Thai | `th-TH` |
| Vietnamese | `vi-VN` |

Enter multiple codes separated by commas. Best results come from specifying only the languages present in your images.

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

## Release

Push a version tag to create a public release with ZIP and DMG assets:

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Run the Menu Bar App

```sh
swift run TangleGUI
```

The app runs as a menu bar utility and hides its Dock icon at launch.

Menu bar actions:

- **Paste Markdown**: `⌃⌥⌘M` — smart Markdown output for any clipboard content
- **Paste Clean Text**: `⌃⌥⌘C` — smart plain text output for any clipboard content
- **Quick Transform Picker**: `⌃⌥⌘P` — preview all transforms before applying
- **Clipboard History**: `⌃⌥⌘B` — search and restore session-only clipboard text
- **Clean URL**: `⌃⌥⌘U` — strip tracking parameters only

Shortcuts are customizable in Settings. The modifier chord (`⌃⌥⌘`) is fixed for this release.

The Quick Transform Picker shows a recommended transformation, estimated character and token savings, and a before/after preview — including an image thumbnail when the clipboard contains a screenshot.

The Settings window includes: HUD feedback, auto-paste, auto-transform on copy, session-only clipboard history, cleanup mode, Markdown preset, OCR confidence threshold, OCR language list, shortcut customization, and URL parameter controls.

Auto-paste simulates `⌘V` locally and requires macOS Accessibility permission. Auto-transform on copy is off by default; when enabled it skips code-like and password-like content.

## CLI

```sh
swift run tangle smart
swift run tangle smart --stats
swift run tangle detect
swift run tangle clean
swift run tangle clean --mode aggressive --stats
swift run tangle clean --clipboard
swift run tangle url
swift run tangle markdown
swift run tangle markdown --preset llm --stats
swift run tangle image --clipboard --to markdown
swift run tangle image screenshot.png --to text
swift run tangle image screenshot.png --to markdown --languages en-US,it-IT --confidence 0.35
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

Manual QA checklists live in [`docs/QA.md`](docs/QA.md).

## Transformations

### Smart

**Paste Markdown** and **Paste Clean Text** detect clipboard content type and route automatically:

- Image-only clipboard → Apple Vision OCR
- PDF/RTF clipboard → local text-layer extraction
- Rich HTML clipboard → HTML-to-Markdown or HTML-to-text
- URL-heavy clipboard → URL tracker removal
- Table-like clipboard → Markdown table or clean text
- Plain text → text cleanup

### Image OCR

- Uses Apple Vision locally; no image leaves your Mac.
- Outputs plain text or Markdown with detected structure.
- Reconstructs table grids from bounding box spatial analysis.
- Detects heading levels (H1/H2/H3) from relative font size.
- Detects bold text from pixel stroke density.
- Handles two-column layouts by processing columns sequentially.
- Configurable recognition languages and minimum confidence threshold.
- Correct error when invoked with no image on clipboard.

### Clean Text

- Normalizes whitespace.
- Removes safe invisible/control characters.
- Collapses repeated blank lines.
- Joins common wrapped paragraph text.
- Repairs common PDF hyphenated line breaks.
- Preserves basic email structure.
- Removes repeated short header/footer noise.

### Markdown

- Converts PDF/web text to conservative Markdown.
- Reads PDF and RTF clipboard data locally when available, avoiding OCR when a text layer exists.
- Removes repeated PDF page headers, footers, and page numbers before conversion.
- Infers conservative heading hierarchy from numbered PDF sections.
- Falls back to local Apple Vision OCR for scanned PDFs without a usable text layer.
- Reads browser clipboard HTML to preserve headings, links, bold, italic, lists, quotes, code blocks, and tables.
- Uses SwiftSoup for DOM-based HTML parsing.
- Cleans tracking parameters from converted links.
- Includes an `llm` preset for compact, token-conscious output.

### Clean URL

- Removes common tracking parameters (`utm_*`, `fbclid`, `gclid`, `mc_cid`, `mc_eid`, and more).
- Preserves meaningful query parameters.
- Supports multiple URLs in a single clipboard.

### Table Conversion (CLI / Quick Picker)

- Converts TSV-like and CSV-like text to Markdown, CSV, or TSV.

Open issues and planned improvements are tracked on [GitHub Issues](https://github.com/danielecostarella/tangle/issues).

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
