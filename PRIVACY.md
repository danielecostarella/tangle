# Privacy

Tangle is designed as a local-first macOS utility.

## What Tangle Does

- Reads text from the macOS clipboard when you trigger a transformation.
- Transforms that text locally on your Mac.
- Writes the transformed text back to the macOS clipboard.
- Optionally simulates `Command` + `V` locally when auto-paste is enabled.

## What Tangle Does Not Do

- No telemetry.
- No analytics.
- No accounts.
- No cloud processing.
- No AI service calls.
- No network calls by default.
- No clipboard history upload.
- No background sync.

## Permissions

Clipboard-only transformations do not require special permissions beyond normal macOS clipboard access.

Auto-paste may require macOS Accessibility permission because it simulates a local paste command into the frontmost app. Tangle does not use this permission to inspect other apps.

## Data Storage

Tangle stores local settings with `UserDefaults`, including preferences such as HUD visibility, cleanup mode, Markdown preset, shortcut keys, and URL parameter lists.

Tangle does not store clipboard contents as history.
