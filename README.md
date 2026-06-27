<div align="center">

# flutter_upgradex

**Upgrade your Flutter dependencies one by one — safely.**

[![pub version](https://img.shields.io/pub/v/flutter_upgradex.svg?style=flat-square&color=0175C2&labelColor=1a1a2e)](https://pub.dev/packages/flutter_upgradex)
[![pub points](https://img.shields.io/pub/points/flutter_upgradex?style=flat-square&color=0175C2&labelColor=1a1a2e)](https://pub.dev/packages/flutter_upgradex/score)
[![license](https://img.shields.io/badge/license-MIT-0175C2?style=flat-square&labelColor=1a1a2e)](LICENSE)
[![dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-0175C2?style=flat-square&labelColor=1a1a2e)](https://dart.dev)

No guesswork. No broken builds.  
Just run `flutter upgradex` and let every dependency upgrade itself — safely.

</div>

---

## Why flutter_upgradex?

`flutter pub upgrade` upgrades everything at once. When something breaks, you have no idea *which* package caused it.

`flutter_upgradex` does it one at a time:

```
✦ Upgrades each dependency individually — pinpoints exactly what breaks
✦ Runs flutter analyze after every upgrade — catches issues immediately
✦ Auto-rollback — broken packages revert to their original version
✦ Failure log — every rollback is recorded with the error that caused it
✦ FVM aware — works with flutter or fvm flutter automatically
✦ Zero config — install once, run from any Flutter project
```

---

## Installation

```sh
dart pub global activate flutter_upgradex
```

That's it. No config files, no project setup.

---

## Usage

```sh
flutter_upgradex
```

Run it from the root of your Flutter project. It walks through every dependency automatically:

```
  ╔══════════════════════════════════════════╗
  ║          🔼  flutter upgradex            ║
  ╚══════════════════════════════════════════╝

  ── Upgrading dependencies ─────────────────

  [1/12] dio
         0.0.0 → 5.7.0
         Running flutter analyze... ✅ kept

  [2/12] go_router
         0.0.0 → 14.6.3
         Running flutter analyze... ✅ kept

  [3/12] some_package
         0.0.0 → 2.1.0
         Running flutter analyze... ❌ failed
         Rolling back to 1.9.4

  ── Done ───────────────────────────────────

  10 upgraded   1 rolled back   1 already latest

  See flutter_upgradex_logs.txt for rollback details.
```

---

## What it covers

| Scope | Upgraded? |
|---|---|
| `dependencies` | ✅ |
| `dev_dependencies` | ✅ |
| Transitive / overrides | Planned for a future release |

---

## Output

After a run you'll have:

| File | What it contains |
|---|---|
| `pubspec.yaml` | All safe upgrades applied, broken ones reverted |
| `flutter_upgradex_logs.txt` | Created only if ≥1 package failed — package name + error |

---

## How It Works

```
you run: flutter_upgradex
         └── reads your pubspec.yaml
                  └── detects fvm (.fvmrc / .fvm) → uses fvm flutter, otherwise flutter
                           └── for each dependency:
                                    └── fetches latest version from pub.dev
                                             └── writes new version constraint
                                                      └── runs flutter analyze
                                                               ├── passes → keep ✅
                                                               └── fails  → rollback + log ❌
```

`dart pub global activate` places the `flutter_upgradex` binary on your PATH. Run it directly — no shell tricks, no aliases needed. FVM is auto-detected from your project directory.

---

## Requirements

- Dart SDK `>=3.0.0`
- Flutter installed — `flutter` or `fvm flutter` (auto-detected)
- A valid `pubspec.yaml` in the current directory

---

## Note

`flutter analyze` catches static analysis errors only. A package that passes may still affect runtime behaviour or tests — review your upgrades before shipping.

---

## Contributing

Contributions are welcome! Please make sure your commits follow the conventional commits format.

---

<div align="center">

Made with 🎯 by [@moulibheemaneti](https://github.com/moulibheemaneti)  
MIT License

</div>
