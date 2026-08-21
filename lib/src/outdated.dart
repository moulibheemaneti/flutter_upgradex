import 'dart:convert';

/// A single package as reported by `flutter pub outdated --json`.
class OutdatedPackage {
  OutdatedPackage({
    required this.name,
    required this.kind,
    this.current,
    this.resolvable,
    this.latest,
  });

  /// Package name.
  final String name;

  /// One of `direct`, `dev`, or `transitive`.
  final String kind;

  /// Currently resolved version, or null if the package is not yet resolved.
  final String? current;

  /// Version reachable by editing pubspec constraints, as suggested by pub.
  final String? resolvable;

  /// Absolute latest version on pub.dev.
  final String? latest;

  /// True for packages declared in `dependencies` or `dev_dependencies`.
  bool get isDirect => kind == 'direct' || kind == 'dev';

  /// The version a batch upgrade would move this package to.
  String? get effectiveResolvable => resolvable ?? current;

  /// True when pub can resolve a newer version than what's installed.
  bool get hasResolvableUpgrade => resolvable != null && resolvable != current;

  /// True when the absolute latest is newer than what a batch upgrade reaches,
  /// i.e. the package is held back by other constraints and needs individual
  /// attention.
  bool get isBehindLatest => latest != null && latest != effectiveResolvable;

  /// The best target for a one-by-one attempt: latest if available, else the
  /// resolvable version.
  String? get upgradeTarget => latest ?? resolvable;
}

/// Parses the output of `flutter pub outdated --json`.
class OutdatedParser {
  /// Parses [jsonOutput] into a list of [OutdatedPackage].
  ///
  /// Throws [FormatException] if the payload is not the expected shape.
  static List<OutdatedPackage> parse(String jsonOutput) {
    final data = jsonDecode(jsonOutput) as Map<String, dynamic>;
    final packages = data['packages'] as List<dynamic>? ?? const [];

    String? version(Map<String, dynamic> pkg, String key) {
      final field = pkg[key];
      if (field is! Map<String, dynamic>) return null;
      return field['version'] as String?;
    }

    return [
      for (final entry in packages)
        if (entry is Map<String, dynamic>)
          OutdatedPackage(
            name: entry['package'] as String,
            kind: entry['kind'] as String? ?? 'direct',
            current: version(entry, 'current'),
            resolvable: version(entry, 'resolvable'),
            latest: version(entry, 'latest'),
          ),
    ];
  }
}
