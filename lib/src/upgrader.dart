import 'dart:io';

import 'package:yaml/yaml.dart';

import 'outdated.dart';
import 'pubspec_utils.dart';

/// How the upgrade run should proceed.
enum UpgradeMode {
  /// Batch every resolvable upgrade at once and analyze a single time.
  oneGo,

  /// Batch the resolvable upgrades first, then walk the remaining packages
  /// one at a time with per-package analyze + rollback.
  phases,
}

/// Upgrades Flutter/Dart dependencies, validating with `flutter analyze`.
///
/// A run starts with a fast batch pass over everything `flutter pub outdated`
/// reports as resolvable. In [UpgradeMode.phases] the run then falls back to
/// the careful one-by-one loop for packages still behind their latest version.
class FlutterUpgradeX {
  static const _logFile = 'flutter_upgradex_logs.txt';

  /// Returns `['fvm', 'flutter']` when an fvm config is detected in the
  /// working directory, otherwise `['flutter']`.
  List<String> get _flutterCmd {
    final hasFvm =
        File('.fvmrc').existsSync() || Directory('.fvm').existsSync();
    return hasFvm ? ['fvm', 'flutter'] : ['flutter'];
  }

  /// Runs the upgrade flow against the `pubspec.yaml` in the current directory.
  ///
  /// When [mode] is null the user is prompted to choose at runtime.
  Future<void> run({UpgradeMode? mode}) async {
    final pubspecFile = File('pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      stderr.writeln(
        '\x1b[31mError: No pubspec.yaml found. '
        'Run flutter_upgradex from your Flutter project root.\x1b[0m',
      );
      exit(1);
    }

    _ensureLogFileGitignored();
    _printHeader();

    final chosenMode = mode ?? _promptMode();

    final originalContent = pubspecFile.readAsStringSync();
    final hostedDeps = _hostedDepNames(originalContent);

    _printSectionHeader('Scanning');
    stdout.write('  Running flutter pub outdated... ');
    final outdated = await _fetchOutdated();
    stdout.writeln('done\n');

    // Only touch direct/dev deps that we can edit in this pubspec.
    final upgradable = outdated
        .where((p) => p.isDirect && hostedDeps.contains(p.name))
        .toList();

    if (upgradable.isEmpty) {
      _printSectionHeader('Done');
      stdout.writeln('  Everything is already up to date. 🎉\n');
      return;
    }

    var currentContent = originalContent;
    final failures = <String, String>{};
    var upgraded = 0;

    // ── Phase 1: batch every resolvable upgrade at once ──────────────────
    _printSectionHeader('Phase 1 · batch resolvable upgrades');
    final batch = await _batchUpgradeResolvable(
      pubspecFile,
      currentContent,
      upgradable,
    );
    currentContent = batch.content;
    upgraded += batch.upgradedCount;

    // ── Phase 2: one-by-one for the stragglers (phases mode only) ────────
    if (chosenMode == UpgradeMode.phases) {
      final List<OutdatedPackage> remaining;
      if (batch.passed) {
        // Batch kept: only packages still held back from their latest.
        remaining = upgradable.where((p) => p.isBehindLatest).toList();
      } else {
        // Batch rolled back: retry every upgrade individually so we still
        // land the ones that are safe on their own.
        remaining = upgradable
            .where((p) => p.hasResolvableUpgrade || p.isBehindLatest)
            .toList();
      }

      if (remaining.isNotEmpty) {
        _printSectionHeader('Phase 2 · one-by-one');
        final oneByOne = await _upgradeOneByOne(
          pubspecFile,
          currentContent,
          remaining,
          failures,
        );
        currentContent = oneByOne.content;
        upgraded += oneByOne.upgradedCount;
      }
    } else {
      final held = upgradable.where((p) => p.isBehindLatest).length;
      if (held > 0) {
        stdout.writeln(
          '  \x1b[90m$held package(s) held back from their latest version. '
          'Re-run in phases mode to attempt them individually.\x1b[0m\n',
        );
      }
    }

    _printSummary(upgraded, failures.length);
  }

  /// Applies every resolvable upgrade in a single pass, then runs one analyze.
  /// On failure the whole batch is rolled back.
  Future<_PassResult> _batchUpgradeResolvable(
    File pubspecFile,
    String currentContent,
    List<OutdatedPackage> packages,
  ) async {
    final targets = packages.where((p) => p.hasResolvableUpgrade).toList();

    if (targets.isEmpty) {
      stdout.writeln('  Nothing resolvable to batch — skipping.\n');
      return _PassResult(currentContent, 0, passed: true);
    }

    var newContent = currentContent;
    for (final p in targets) {
      newContent =
          PubspecUtils.setConstraint(newContent, p.name, '^${p.resolvable}');
      final from = p.current == null ? '' : '\x1b[90m^${p.current}\x1b[0m → ';
      stdout.writeln('  • ${p.name}  $from\x1b[36m^${p.resolvable}\x1b[0m');
    }

    pubspecFile.writeAsStringSync(newContent);
    await _pubGet();

    stdout.write('\n  Running flutter analyze on the batch... ');
    final (passed, output) = await _analyze();
    if (passed) {
      stdout.writeln('\x1b[32m✅ kept (${targets.length})\x1b[0m\n');
      return _PassResult(newContent, targets.length, passed: true);
    }

    stdout.writeln('\x1b[31m❌ failed\x1b[0m');
    stdout.writeln('  Rolling back the entire batch.\n');
    pubspecFile.writeAsStringSync(currentContent);
    await _pubGet();
    _appendToLog('[batch]', 'resolvable upgrades', output);
    return _PassResult(currentContent, 0, passed: false);
  }

  /// Walks [packages] one at a time, bumping each to its upgrade target,
  /// keeping the ones that pass analyze and rolling back the ones that don't.
  Future<_PassResult> _upgradeOneByOne(
    File pubspecFile,
    String startContent,
    List<OutdatedPackage> packages,
    Map<String, String> failures,
  ) async {
    var currentContent = startContent;
    var upgraded = 0;

    for (var i = 0; i < packages.length; i++) {
      final p = packages[i];
      final target = p.upgradeTarget;
      stdout.writeln(
        '  \x1b[34m[${i + 1}/${packages.length}]\x1b[0m ${p.name}',
      );

      if (target == null) {
        stdout.writeln('        \x1b[90mnothing newer available\x1b[0m\n');
        continue;
      }

      final newConstraint = '^$target';
      // What's live in the file right now for this package.
      final liveConstraint = PubspecUtils.getConstraint(currentContent, p.name);
      if (liveConstraint == newConstraint) {
        stdout.writeln('        already latest ($newConstraint)\n');
        continue;
      }

      final from = liveConstraint ?? (p.current == null ? '?' : '^${p.current}');
      stdout.writeln(
        '        \x1b[90m$from\x1b[0m → \x1b[36m$newConstraint\x1b[0m',
      );
      stdout.write('        Running flutter analyze... ');

      final newContent =
          PubspecUtils.setConstraint(currentContent, p.name, newConstraint);
      pubspecFile.writeAsStringSync(newContent);
      await _pubGet();

      final (passed, output) = await _analyze();
      if (passed) {
        stdout.writeln('\x1b[32m✅ kept\x1b[0m\n');
        currentContent = newContent;
        upgraded++;
      } else {
        stdout.writeln('\x1b[31m❌ failed\x1b[0m');
        stdout.writeln('        Rolling back to $from\n');
        pubspecFile.writeAsStringSync(currentContent);
        await _pubGet();
        failures[p.name] = output;
        _appendToLog(p.name, newConstraint, output);
      }
    }

    return _PassResult(currentContent, upgraded, passed: true);
  }

  /// Asks the user whether to run everything in one go or in phases.
  ///
  /// Defaults to [UpgradeMode.phases] on a non-interactive terminal.
  UpgradeMode _promptMode() {
    stdout.writeln('  How would you like to upgrade?\n');
    stdout.writeln(
      '    \x1b[36m[1]\x1b[0m All in one go  '
      '— batch every resolvable upgrade, analyze once \x1b[90m(fastest)\x1b[0m',
    );
    stdout.writeln(
      '    \x1b[36m[2]\x1b[0m In phases      '
      '— batch the safe ones, then one-by-one for the rest '
      '\x1b[90m(safest)\x1b[0m\n',
    );

    var interactive = false;
    try {
      interactive = stdin.hasTerminal;
    } catch (_) {
      interactive = false;
    }

    if (!interactive) {
      stdout.writeln(
        '  \x1b[90mNon-interactive terminal — defaulting to phases.\x1b[0m\n',
      );
      return UpgradeMode.phases;
    }

    stdout.write('  Choose \x1b[36m[1/2]\x1b[0m (default 2): ');
    final answer = stdin.readLineSync()?.trim();
    stdout.writeln();
    return answer == '1' ? UpgradeMode.oneGo : UpgradeMode.phases;
  }

  /// Collects the names of hosted (version-string) deps from [content].
  Set<String> _hostedDepNames(String content) {
    final names = <String>{};
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) return names;
    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = yaml[section];
      if (deps is! YamlMap) continue;
      for (final entry in deps.entries) {
        if (PubspecUtils.isHostedDep(entry.value)) {
          names.add(entry.key as String);
        }
      }
    }
    return names;
  }

  Future<List<OutdatedPackage>> _fetchOutdated() async {
    final cmd = _flutterCmd;
    final result = await Process.run(
      cmd.first,
      [...cmd.skip(1), 'pub', 'outdated', '--json'],
      runInShell: true,
    );
    final out = (result.stdout as String).trim();
    if (out.isEmpty) return const [];
    try {
      return OutdatedParser.parse(out);
    } catch (_) {
      return const [];
    }
  }

  void _appendToLog(String name, String newConstraint, String analyzeOutput) {
    final buf = StringBuffer();
    buf.writeln('─' * 60);
    buf.writeln('Package : $name (attempted $newConstraint)');
    buf.writeln('Time    : ${DateTime.now().toIso8601String()}');
    buf.writeln('flutter analyze output:');
    buf.writeln();
    buf.writeln(analyzeOutput.trim());
    buf.writeln();
    File(_logFile).writeAsStringSync(buf.toString(), mode: FileMode.append);
  }

  void _printHeader() {
    stdout.writeln();
    stdout.writeln('  ╔══════════════════════════════════════════╗');
    stdout.writeln('  ║          🔼  flutter upgradex            ║');
    stdout.writeln('  ╚══════════════════════════════════════════╝');
    stdout.writeln();
  }

  // Total line width is 45. Formula: 39 - title.length trailing dashes.
  void _printSectionHeader(String title) {
    final dashes = '─' * (39 - title.length).clamp(0, 39);
    stdout.writeln('  ── $title $dashes\n');
  }

  void _printSummary(int upgraded, int rolledBack) {
    _printSectionHeader('Done');
    stdout.writeln(
      '  \x1b[32m$upgraded upgraded\x1b[0m   '
      '\x1b[31m$rolledBack rolled back\x1b[0m\n',
    );
    if (rolledBack > 0) {
      stdout.writeln(
        '  \x1b[33mSee $_logFile for rollback details.\x1b[0m\n',
      );
    }
  }

  void _ensureLogFileGitignored() {
    final gitignore = File('.gitignore');
    final entry = _logFile;
    const block = '\n# flutter_upgradex logs\n$_logFile\n';

    if (gitignore.existsSync()) {
      final lines = gitignore.readAsLinesSync();
      if (lines.any((l) => l.trim() == entry)) return;
      gitignore.writeAsStringSync(block, mode: FileMode.append);
    } else {
      gitignore.writeAsStringSync(block.trimLeft());
    }
  }

  Future<void> _pubGet() async {
    final cmd = _flutterCmd;
    await Process.run(
      cmd.first,
      [...cmd.skip(1), 'pub', 'get'],
      runInShell: true,
    );
  }

  Future<(bool, String)> _analyze() async {
    final cmd = _flutterCmd;
    final result = await Process.run(
      cmd.first,
      [...cmd.skip(1), 'analyze'],
      runInShell: true,
    );
    final output = [
      if ((result.stdout as String).trim().isNotEmpty) result.stdout as String,
      if ((result.stderr as String).trim().isNotEmpty) result.stderr as String,
    ].join('\n').trim();
    return (result.exitCode == 0, output);
  }
}

/// Result of a single upgrade pass (batch or one-by-one).
class _PassResult {
  _PassResult(this.content, this.upgradedCount, {required this.passed});

  /// Pubspec content after the pass.
  final String content;

  /// Number of packages kept.
  final int upgradedCount;

  /// Whether the pass's analyze succeeded (relevant to the batch pass).
  final bool passed;
}
