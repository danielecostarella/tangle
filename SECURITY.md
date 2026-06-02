# Security

## Reporting Issues

Please report security or privacy issues privately to the repository owner.

Avoid posting sensitive clipboard examples publicly. If a transformation bug needs sample input, reduce it to a minimal synthetic reproduction.

## Scope

Tangle is a local macOS utility. Security-sensitive areas include:

- Clipboard read/write behavior.
- Auto-paste behavior.
- Accessibility permission handling.
- Release packaging.
- Any future network-related code.

## Privacy Expectations

Tangle should not add telemetry, analytics, accounts, cloud processing, or network calls by default.
