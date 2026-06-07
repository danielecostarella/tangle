# QA Results — 7 June 2026

Tested from commit after `v0.1.14` using locally generated fixtures from
`scripts/generate-qa-fixtures.swift`.

## Automated Matrix

| Case | Result | Notes |
| --- | --- | --- |
| Clipboard History retention, ordering, duplicate handling, search | PASS | Covered by Core tests |
| Clipboard History sensitive marker and password manager exclusion | PASS | Covered by privacy policy tests |
| Flattened technical PDF table (`Symbol / Description / Min / Typ / Max / Unit`) | PASS | Smart Detect reconstructs rows; Clean Text emits TSV; Markdown emits a table |
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
| Preview selectable PDF | PASS | Real app copy; PDF-style HTML routed through document cleanup when page markers exist |
| Preview scanned PDF | PASS | Real app copy; local OCR fallback |
| Preview multi-column PDF | PASS | Real app copy preserves left-to-right reading order |
| Preview native text table | PASS | Preview HTML exposes a table and Tangle emits Markdown |
| Preview footnotes | PARTIAL | Text retained, but Preview HTML does not expose the semantic reference |
| Adobe Acrobat selectable PDF | PASS | Real app copy; repeated margins removed |
| Adobe Acrobat rich document detection | PASS | RTF/PDF content with a plain-text fallback now routes to Markdown |
| Adobe Acrobat multiline RTF formatting | PASS | Markdown markers remain balanced; Acrobat may mark most copied text italic |
| Safari PDF viewer | INCONCLUSIVE | Synthetic Select All copies the local file URL, not PDF content |
| Chrome PDF viewer | INCONCLUSIVE | Synthetic Select All copies the local file URL, not PDF content |

## Native Application Matrix

Preview and Adobe Acrobat were tested end-to-end with real application clipboard
output after Accessibility permission was granted. Safari and Chrome remain
inconclusive because their PDF viewers keep Select All focused on the address bar
under synthetic keyboard input.

These cases remain manual:

- Selecting PDF body text in Safari's PDF viewer
- Selecting PDF body text in Chrome's PDF viewer
- Visual verification of the Clipboard History panel

## Fixes Found During QA

- Removed repeated PDF margins when PDFKit merges page numbers into footer text.
- Added scanned-PDF OCR regression coverage.
- Linked simple PDF footnote references and definitions.
- Prevented clipboard history privacy checks from rejecting normal URLs.
- Moved clipboard history privacy decisions into testable Core logic.
- Made `tangle markdown --clipboard` use the full PDF/RTF document pipeline.
- Made packaged app bundle versions derive from the Git release tag.
- Routed Preview-style copied PDF text through document cleanup before HTML.
- Routed RTF/PDF clipboard content with plain-text fallbacks to Markdown.
- Applied RTF inline formatting per line to prevent dangling Markdown markers.
