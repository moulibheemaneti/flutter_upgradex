import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'pubspec_utils.dart';

/// Upgrades Flutter/Dart dependencies one at a time, validating each upgrade
/// with `flutter analyze` before keeping it.
///
/// Usage:
/// ```dart
/// await FlutterUpgradeX().run();
/// ```
class FlutterUpgradeX {
  static const _logFile = 'flutter_upgradex_logs.txt';

  /// Returns `['fvm', 'flutter']` when an fvm config is detected in the
  /// working directory, otherwise `['flutter']`.
  List<String> get _flutterCmd {
    final hasFvm =
        File('.fvmrc').existsSync() || Directory('.fvm').existsSync();
    return hasFvm ? ['fvm', 'flutter'] : ['flutter'];
  }

  /// Runs the upgrade loop against the `pubspec.yaml` in the current directory.
  ///
  /// For every hosted dependency in `dependencies` and `dev_dependencies`:
  /// 1. Fetches the latest version from pub.dev.
  /// 2. Writes the new constraint to `pubspec.yaml`.
  /// 3. Runs `flutter analyze`.
  ///    - Pass → keep the upgrade, move to the next package.
  ///    - Fail → roll back to the previous constraint and log the failure.
  ///
  /// If any packages fail, a `flutter_upgradex_logs.txt` file is written to
  /// the current directory listing each failed package and reason.
  Future<void> run() async {
    final pubspecFile = File('pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      stderr.writeln(
        '\x1b[31mError: No pubspec.yaml found. '
        'Run flutter_upgradex from your Flutter project root.\x1b[0m',
      );
      exit(1);
    }

    _ensureLogFileGitignored();

    stdout.writeln('Reading pubspec.yaml…\n');

    final originalContent = pubspecFile.readAsStringSync();

    final yaml = loadYaml(originalContent) as YamlMap;

    final failures = <String, String>{};

    var currentContent = originalContent;

    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = yaml[section];

      if (deps is! YamlMap) continue;

      for (final entry in deps.entries) {
        final name = entry.key as String;

        if (!PubspecUtils.isHostedDep(entry.value)) continue;

        stdout.write('  $name … ');

        final latest = await _fetchLatestVersion(name);

        if (latest == null) {
          stdout.writeln('skipped (could not fetch version from pub.dev)');
          continue;
        }

        final newConstraint = '^$latest';

        final newContent = PubspecUtils.setConstraint(
          currentContent,
          name,
          newConstraint,
        );

        pubspecFile.writeAsStringSync(newContent);
        await _pubGet();

        if (await _analyze()) {
          stdout.writeln('\x1b[32m✓ upgraded to $newConstraint\x1b[0m');
          currentContent = newContent;
        } else {
          stdout.writeln('\x1b[31m✗ rolled back (analyze failed)\x1b[0m');
          pubspecFile.writeAsStringSync(currentContent);
          await _pubGet();
          failures[name] =
              'flutter analyze failed after upgrading to $newConstraint';
        }
      }
    }

    if (failures.isNotEmpty) {
      final buf = StringBuffer('Packages that failed flutter analyze:\n\n');

      for (final e in failures.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }

      File(_logFile).writeAsStringSync(buf.toString());

      stdout.writeln(
        '\n\x1b[33m${failures.length} package(s) rolled back. '
        'See $_logFile for details.\x1b[0m',
      );
    } else {
      stdout.writeln('\n\x1b[32mAll upgrades applied successfully!\x1b[0m');
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

  Future<String?> _fetchLatestVersion(String package) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://pub.dev/api/packages/$package'),
      );

      request.headers.set('accept', 'application/json');

      final response = await request.close();

      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();

      final data = jsonDecode(body) as Map<String, dynamic>;

      return (data['latest'] as Map<String, dynamic>)['version'] as String?;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _pubGet() async {
    final cmd = _flutterCmd;
    await Process.run(cmd.first, [...cmd.skip(1), 'pub', 'get'],
        runInShell: true);
  }

  Future<bool> _analyze() async {
    final cmd = _flutterCmd;
    final result = await Process.run(
      cmd.first,
      [...cmd.skip(1), 'analyze'],
      runInShell: true,
    );
    return result.exitCode == 0;
  }
}
