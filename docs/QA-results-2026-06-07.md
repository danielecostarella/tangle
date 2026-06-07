# QA Results — 7 June 2026

Tested from commit after `v0.1.14` using locally generated fixtures from
`scripts/generate-qa-fixtures.swift`.

## Automated Matrix

| Case | Result | Notes |
| --- | --- | --- |
| Clipboard History retention, ordering, duplicate handling, search | PASS | Covered by Core tests |
| Clipboard History sensitive marker and password manager exclusion | PASS | Covered by privacy policy tests |
| Clipboard History password/API token exclusion | PASS | Password-like strings and common token prefixes skipped |
| Clipboard History URL retention | PASS | URLs with query parameters are not mistaken for secrets |
| PDF clipboard detection | PASS | Detected as `document`, routed to Markdown |
| PDF selectable text layer | PASS | Wrapped prose repaired |
| PDF repeated header/footer and page number removal | PASS | Handles page numbers merged into margin text |
| PDF numbered heading hierarchy | PASS | Numbered sections become conservative heading levels |
| PDF scanned page OCR fallback | PASS | Apple Vision output preserves heading, prose, and bullets |
| PDF multi-column text layer | PASS | Fixture preserves left column before right column |
| PDF simple footnote reference and definition | PASS | Emits Markdown footnote syntax |
| PDF native text table | PARTIAL | Values retained, but PDFKit exposes them as flat text |
| CLI Markdown with PDF/RTF clipboard | PASS | CLI now uses the same document pipeline as the GUI |

## Native Application Matrix

Preview, Safari, Google Chrome, and Adobe Acrobat are installed. Automated
copy-selection tests could not run because macOS denied Accessibility permission
to `osascript` for synthetic `Command-A` / `Command-C` events.

These cases remain manual:

- Copying a selection from Preview
- Copying from Safari's PDF viewer
- Copying from Chrome's PDF viewer
- Copying from Adobe Acrobat
- Visual verification of the Clipboard History panel

## Fixes Found During QA

- Removed repeated PDF margins when PDFKit merges page numbers into footer text.
- Added scanned-PDF OCR regression coverage.
- Linked simple PDF footnote references and definitions.
- Prevented clipboard history privacy checks from rejecting normal URLs.
- Moved clipboard history privacy decisions into testable Core logic.
- Made `tangle markdown --clipboard` use the full PDF/RTF document pipeline.
- Made packaged app bundle versions derive from the Git release tag.
