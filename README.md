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

`flutter pub upgrade` upgrades everything at once. When something breaks, you have no idea *which* package caused it. Upgrading strictly one-by-one is safe, but slow.

`flutter_upgradex` gives you the best of both — a fast batch first, then surgical precision only where it's needed:

```
✦ Batch-first — applies every resolvable upgrade at once and analyzes a single time
✦ Phased fallback — packages still behind their latest are then tried one at a time
✦ Runtime choice — pick "all in one go" (fastest) or "in phases" (safest) each run
✦ Runs flutter analyze after every step — catches issues immediately
✦ Auto-rollback — a broken batch or package reverts to its original version
✦ Failure log — every rollback is recorded with the error that caused it
✦ FVM aware — works with flutter or fvm flutter automatically
✦ Zero config — install once, run from any Flutter project
```

### Two modes

On every run you're asked how to proceed:

| Mode | What happens | Best for |
|---|---|---|
| **All in one go** | Runs `flutter pub outdated`, applies all *resolvable* upgrades in one batch, analyzes once | Speed — routine bumps |
| **In phases** | Same batch first, then walks every package still held back from its latest version one at a time, with per-package analyze + rollback | Safety — major-version jumps |

On a non-interactive terminal (CI) the tool defaults to **phases**.

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

Run it from the root of your Flutter project. It asks how you'd like to upgrade, then does the work:

```
  ╔══════════════════════════════════════════╗
  ║          🔼  flutter upgradex            ║
  ╚══════════════════════════════════════════╝

  How would you like to upgrade?

    [1] All in one go  — batch every resolvable upgrade, analyze once (fastest)
    [2] In phases      — batch the safe ones, then one-by-one for the rest (safest)

  Choose [1/2] (default 2): 2

  ── Scanning ───────────────────────────────

  Running flutter pub outdated... done

  ── Phase 1 · batch resolvable upgrades ────

  • dio         ^4.0.6 → ^5.7.0
  • flutter_bloc ^8.1.6 → ^8.1.9

  Running flutter analyze on the batch... ✅ kept (2)

  ── Phase 2 · one-by-one ───────────────────

  [1/1] some_package
        ^1.9.4 → ^2.1.0
        Running flutter analyze... ❌ failed
        Rolling back to ^1.9.4

  ── Done ───────────────────────────────────

  2 upgraded   1 rolled back

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
                           └── asks: all in one go, or in phases?
                                    └── runs flutter pub outdated --json
                                             │
                                             ├── Phase 1 (both modes): batch every resolvable upgrade
                                             │        └── runs flutter analyze once
                                             │                 ├── passes → keep the batch ✅
                                             │                 └── fails  → roll back the whole batch ❌
                                             │
                                             └── Phase 2 (phases mode): packages still behind latest
                                                      └── for each, bump → analyze
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
