# Contributing

Thanks for helping make Tangle better.

## Principles

- Keep transformations predictable and conservative.
- Prefer local-only behavior.
- Avoid telemetry, accounts, cloud processing, and hidden network calls.
- Add tests for transformation changes.
- Keep the menu bar app lightweight and macOS-native.

## Development

```sh
swift build
swift test
swift run TangleGUI
```

## Packaging

```sh
scripts/package-app.sh
```

This creates `dist/Tangle.app`, `dist/Tangle.zip`, and `dist/Tangle.dmg`.

## Pull Requests

For transformation changes, include:

- Input examples.
- Expected output.
- Unit tests or fixtures.

For UI changes, keep the app keyboard-first and avoid adding heavy dependencies.
