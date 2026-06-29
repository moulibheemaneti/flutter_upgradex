import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'pubspec_utils.dart';

/// Upgrades Flutter/Dart dependencies one at a time, validating each upgrade
/// with `flutter analyze` before keeping it.
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
    _printHeader();

    final originalContent = pubspecFile.readAsStringSync();
    final yaml = loadYaml(originalContent) as YamlMap;

    // Collect all hosted deps with their current constraints upfront.
    final allDeps = <(String, String)>[];
    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = yaml[section];
      if (deps is! YamlMap) continue;
      for (final entry in deps.entries) {
        if (PubspecUtils.isHostedDep(entry.value)) {
          allDeps.add((entry.key as String, entry.value as String));
        }
      }
    }

    _printSectionHeader('Upgrading dependencies');

    final failures = <String, String>{};
    var currentContent = originalContent;
    var upgraded = 0;
    var alreadyLatest = 0;

    for (var i = 0; i < allDeps.length; i++) {
      final (name, currentConstraint) = allDeps[i];
      stdout.writeln('  \x1b[34m[${i + 1}/${allDeps.length}]\x1b[0m $name');

      final latest = await _fetchLatestVersion(name);
      if (latest == null) {
        stdout.writeln(
          '        \x1b[33mskipped (could not fetch from pub.dev)\x1b[0m\n',
        );
        continue;
      }

      final newConstraint = '^$latest';

      if (currentConstraint == newConstraint) {
        stdout.writeln('        already latest ($newConstraint)\n');
        alreadyLatest++;
        continue;
      }

      stdout.writeln(
        '        \x1b[90m$currentConstraint\x1b[0m → \x1b[36m$newConstraint\x1b[0m',
      );
      stdout.write('        Running flutter analyze... ');

      final newContent = PubspecUtils.setConstraint(
        currentContent,
        name,
        newConstraint,
      );
      pubspecFile.writeAsStringSync(newContent);
      await _pubGet();

      final (passed, analyzeOutput) = await _analyze();
      if (passed) {
        stdout.writeln('\x1b[32m✅ kept\x1b[0m\n');
        currentContent = newContent;
        upgraded++;
      } else {
        stdout.writeln('\x1b[31m❌ failed\x1b[0m');
        stdout.writeln('        Rolling back to $currentConstraint\n');
        pubspecFile.writeAsStringSync(currentContent);
        await _pubGet();
        failures[name] = analyzeOutput;
        _appendToLog(name, newConstraint, analyzeOutput);
      }
    }

    _printSectionHeader('Done');

    stdout.writeln(
      '  \x1b[32m$upgraded upgraded\x1b[0m   '
      '\x1b[31m${failures.length} rolled back\x1b[0m   '
      '\x1b[90m$alreadyLatest already latest\x1b[0m\n',
    );

    if (failures.isNotEmpty) {
      stdout.writeln(
        '  \x1b[33mSee $_logFile for rollback details.\x1b[0m\n',
      );
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
    final dashes = '─' * (39 - title.length);
    stdout.writeln('  ── $title $dashes\n');
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
