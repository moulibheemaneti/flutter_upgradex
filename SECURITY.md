# Security Policy

## Supported Versions

Only the latest minor release of `flutter_upgradex` receives security fixes.

| Version | Supported          |
| ------- | ------------------ |
| 0.4.x   | :white_check_mark: |
| < 0.4   | :x:                |

## Reporting a Vulnerability

`flutter_upgradex` is a local CLI tool that upgrades dependencies one at a time
by editing `pubspec.yaml` and running `flutter pub`/`flutter analyze` — it does
not handle authentication or store user data, though it does modify project
files and invoke the Flutter toolchain. If you believe you've found a
vulnerability (for example, unsafe shell execution, unintended file writes
outside the project, or a problem in a transitive dependency exposed via this
package), please **do not open a public issue**.

Report it privately via GitHub Security Advisories:

➡️ [Report a vulnerability](https://github.com/moulibheemaneti/flutter_upgradex/security/advisories/new)

You can expect:
- An acknowledgement within **7–14 days**.
- A status update within **30–45 days**.
- If accepted, a fix will land in the next patch release and you'll be credited in the release notes (unless you prefer to remain anonymous).
- If declined, you'll receive an explanation of why.
