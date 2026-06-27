# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-06-27

### Added
- **Safe dependency upgrader**: Walks through every hosted dependency in `pubspec.yaml`, upgrades each to its latest pub.dev version, and runs `flutter analyze` after each one.
- **Automatic rollback**: If `flutter analyze` fails after an upgrade, the package is automatically rolled back to its previous version and the project is restored to a passing state.
- **Failure log**: If any packages fail, `flutter_upgradex_logs.txt` is written listing every rolled-back package.
- **`PubspecUtils`**: Testable utility class for reading and modifying `pubspec.yaml` constraints.
