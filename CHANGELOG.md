# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0](https://github.com/moulibheemaneti/flutter_upgradex/compare/flutter_upgradex-v0.0.1...flutter_upgradex-v0.1.0) (2026-06-27)


### Features

* detect fvm and auto-gitignore log file at runtime ([#2](https://github.com/moulibheemaneti/flutter_upgradex/issues/2)) ([c5fc7f8](https://github.com/moulibheemaneti/flutter_upgradex/commit/c5fc7f8d28f301aa3a5ea29843fd393c72128d63))

## [0.0.1] - 2026-06-27

### Added
- **Safe dependency upgrader**: Walks through every hosted dependency in `pubspec.yaml`, upgrades each to its latest pub.dev version, and runs `flutter analyze` after each one.
- **Automatic rollback**: If `flutter analyze` fails after an upgrade, the package is automatically rolled back to its previous version and the project is restored to a passing state.
- **Failure log**: If any packages fail, `flutter_upgradex_logs.txt` is written listing every rolled-back package.
- **`PubspecUtils`**: Testable utility class for reading and modifying `pubspec.yaml` constraints.
