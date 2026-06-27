# flutter_upgradex

**Upgrade your Flutter dependencies one by one — safely.**

`flutter upgradex` walks through every dependency in your `pubspec.yaml`, upgrades each one to its latest version on [pub.dev](https://pub.dev), and runs `flutter analyze` after each upgrade. If a package breaks your project, it's automatically rolled back and logged — so you always end up with a working `pubspec.yaml`.

---

## Why?

`flutter pub upgrade` upgrades everything at once. When something breaks, you have no idea *which* package caused it.

`flutter_upgradex` does it one at a time, validates each step, and keeps only the upgrades that pass.

---

## Installation

```sh
dart pub global activate flutter_upgradex
```

That's it. No config files, no project setup.

---

## Usage

From the root of your Flutter project:

```sh
flutter upgradex
```

For each dependency, it will:

1. Upgrade to the latest version available on pub.dev
2. Run `flutter analyze`
   - **Passes** → keep the upgrade, move on
   - **Fails** → roll back to the original version and log the error

---

## What it covers

| Scope                | Upgraded? |
| -------------------- | --------- |
| `dependencies`       | ✅        |
| `dev_dependencies`   | ✅        |
| Transitive / overrides | Planned for a future release |

---

## Output

After a run you'll have:

- **`pubspec.yaml`** — with all safe upgrades applied
- **`flutter_upgradex_logs.txt`** — created only if at least one package failed, listing the package name and the error it produced

---

## Requirements

- Flutter installed and on your PATH
- A valid `pubspec.yaml` in the current directory

---

## Note

`flutter analyze` catches static analysis errors only. A package that passes may still affect runtime behaviour or tests — review your upgrades before shipping.

---

## License

MIT
