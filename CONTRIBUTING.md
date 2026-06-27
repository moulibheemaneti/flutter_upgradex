# Contributing to flutter_upgradex

## Setup

```sh
git clone https://github.com/moulibheemaneti/flutter_upgradex.git
cd flutter_upgradex
dart pub get
dart run dart_husky install
```

The last command installs the git hooks defined in `dart_husky.yaml`.

## Before every commit

The pre-commit hook runs automatically:

```
dart format --set-exit-if-changed .   # formatting
dart analyze                          # static analysis
dart test                             # full test suite
```

Fix any failures before committing — the hook will block the commit if any of them exit non-zero.

## Commit messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/). The commit-msg hook enforces it.

```
<type>: <lowercase subject>
```

Allowed types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, `build`, `ci`, `perf`, `revert`, `wip`, `release`.

Examples:

```
feat: support path and git dep detection
fix: handle missing pubspec.yaml gracefully
docs: document rollback behaviour
wip: scaffold pub.dev version fetcher
```

Breaking changes: add `!` after the type, e.g. `feat!: redesign upgrade loop`.

## Pull requests

PR titles must follow the same convention — a CI check validates them automatically.

Keep each PR focused on one concern. If you are fixing a bug and spotting unrelated cleanup, open a separate PR for the cleanup.

## Running the tool locally

```sh
dart run bin/main.dart
```

Or activate from source:

```sh
dart pub global activate --source path .
flutter_upgradex
```
