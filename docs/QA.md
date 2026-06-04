# Tangle QA

This checklist covers manual release testing that unit tests cannot fully prove yet, especially app-to-app clipboard behavior.

## Before Testing

- Install the latest `Tangle.app` from `dist/` or the GitHub release.
- Launch Tangle and confirm the menu bar icon is visible.
- Keep Auto-paste disabled unless the case explicitly asks for it.
- Open Settings and keep HUD enabled so transformation feedback is visible.
- Confirm Auto-transform on copy starts disabled by default.

## Auto-transform on Copy

Auto-transform on copy is intentionally opt-in. It should transform only when Smart Detect is confident, and it must never call network services.

### Web Article to Markdown

1. Enable Auto-transform on copy.
2. Set confidence to `0.75`.
3. In Safari, Chrome, or Arc, copy a web article section that includes a heading, paragraph, bold text, and a link.
4. Paste into TextEdit in plain-text mode or a code editor.

Expected:

- The pasted result is Markdown-like text.
- Headings are preserved as Markdown headings when browser HTML exposes them.
- Links become Markdown links when available.
- HUD reports an auto-transform.
- The Tangle menu offers Restore Original Clipboard.

Repeat in at least two browsers before a public release.

### Tracked URL

1. Enable Auto-transform on copy.
2. Copy this URL:

   ```text
   https://example.com/report?id=42&utm_source=newsletter&utm_medium=email&gclid=test
   ```

3. Paste into a text editor.

Expected:

- Tracking parameters are removed.
- Meaningful parameters such as `id=42` remain.
- The final URL is:

   ```text
   https://example.com/report?id=42
   ```

### PDF Text

1. Enable Auto-transform on copy.
2. Open a PDF in Preview.
3. Copy a paragraph with wrapped lines or hyphenated line breaks.
4. Paste into a text editor.

Expected:

- Obvious wrapped lines are joined.
- Hyphenated line breaks are repaired when safe.
- Paragraph boundaries remain readable.

### Table

1. Enable Auto-transform on copy.
2. Copy a small table from Numbers, a spreadsheet, or a webpage.
3. Paste into a text editor.

Expected:

- Smart Detect should prefer a table transformation when the clipboard is clearly tabular.
- The result should be readable Markdown table text.
- CSV/TSV-specific outputs should still be tested through the menu or CLI.

### Code Bypass

1. Enable Auto-transform on copy.
2. Copy a Swift or shell code block from an editor or website.
3. Paste into a text editor.

Expected:

- Tangle should not silently transform code-like clipboard content.
- Formatting may still be whatever the source app placed on the clipboard, but Tangle should not rewrite it.

### Password-like Bypass

1. Enable Auto-transform on copy.
2. Copy a short secret-like string with no spaces, at least one digit, and at least one symbol, for example:

   ```text
   Abcd1234!
   ```

3. Paste into a text editor.

Expected:

- Tangle should not silently transform it.
- No HUD should claim an auto-transform.

### Restore Original Clipboard

1. Enable Auto-transform on copy.
2. Copy content that Tangle transforms.
3. Open the menu bar menu and choose Restore Original Clipboard.
4. Paste into a text editor.

Expected:

- The original clipboard text is restored.
- Restore Original Clipboard disappears after restore.

## Quick Transform Picker

1. Copy a web article, URL, table, and PDF paragraph in separate runs.
2. Open Quick Transform Picker with `Control` + `Option` + `Command` + `P`.
3. Move through the transform list.
4. Apply a recommended transform.

Expected:

- The panel opens as a floating utility window.
- Before/after panes show a useful preview.
- Recommended transform is selected for high-confidence content.
- Apply writes the chosen output to the clipboard.
- Cancel closes the panel without changing the clipboard.

## Image OCR

1. Copy a screenshot or image that contains a short heading, paragraph, and bullet list.
2. Choose Extract Text from Image.
3. Paste into a text editor.
4. Copy the same image again.
5. Choose Convert Image to Markdown.
6. Paste into a Markdown editor or text editor.

Expected:

- OCR runs locally and does not require network access.
- Extract Text from Image writes readable plain text.
- Convert Image to Markdown emits conservative Markdown.
- Obvious headings and bullets are preserved when Vision recognizes them clearly.
- If no text is recognized, Tangle shows an error instead of clearing useful clipboard text silently.

Repeat once with a screenshot from a slide and once with a scanned/PDF image crop.

## Auto-paste Smoke Test

1. Enable Auto-paste.
2. Grant Accessibility permission when macOS asks.
3. Copy messy text.
4. Use Paste Cleaned Text into Notes or TextEdit.

Expected:

- Tangle cleans the clipboard.
- The frontmost app receives the cleaned text.
- If Accessibility permission is missing, Tangle surfaces the permission path instead of failing silently.

## Release Gate

Before tagging a release:

- `swift test` passes locally.
- `scripts/package-app.sh` creates `dist/Tangle.app`, `dist/Tangle.zip`, and `dist/Tangle.dmg`.
- GitHub CI passes on `main`.
- GitHub Release workflow uploads both `Tangle.zip` and `Tangle.dmg`.
- At least the Web Article, Tracked URL, Code Bypass, and Restore Original Clipboard manual cases above have been tested on the release candidate.
