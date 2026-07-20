import 'package:flutter_upgradex/flutter_upgradex.dart';
import 'package:test/test.dart';

void main() {
  group('PubspecUtils.isHostedDep', () {
    test('returns true for a caret version string', () {
      expect(PubspecUtils.isHostedDep('^1.0.0'), isTrue);
    });

    test('returns true for "any"', () {
      expect(PubspecUtils.isHostedDep('any'), isTrue);
    });

    test('returns true for a range constraint', () {
      expect(PubspecUtils.isHostedDep('>=1.0.0 <2.0.0'), isTrue);
    });

    test('returns false for null', () {
      expect(PubspecUtils.isHostedDep(null), isFalse);
    });

    test('returns false for a map (sdk/git/path dep)', () {
      expect(PubspecUtils.isHostedDep({'sdk': 'flutter'}), isFalse);
    });

    test('returns false for an int', () {
      expect(PubspecUtils.isHostedDep(1), isFalse);
    });
  });

  group('PubspecUtils.setConstraint', () {
    const pubspec = '''
dependencies:
  foo: ^1.0.0
  bar: ^2.0.0
dev_dependencies:
  baz: ^3.0.0
''';

    test('updates constraint for the target package', () {
      final result = PubspecUtils.setConstraint(pubspec, 'foo', '^1.2.3');
      expect(result, contains('  foo: ^1.2.3'));
    });

    test('does not modify other packages', () {
      final result = PubspecUtils.setConstraint(pubspec, 'foo', '^9.0.0');
      expect(result, contains('  bar: ^2.0.0'));
      expect(result, contains('  baz: ^3.0.0'));
    });

    test('updates dev_dependency constraint', () {
      final result = PubspecUtils.setConstraint(pubspec, 'baz', '^4.0.0');
      expect(result, contains('  baz: ^4.0.0'));
    });

    test('returns content unchanged for unknown package', () {
      final result = PubspecUtils.setConstraint(pubspec, 'unknown', '^1.0.0');
      expect(result, equals(pubspec));
    });

    test('replaces only the first occurrence when package appears twice', () {
      const dup = '''
dependencies:
  foo: ^1.0.0
dev_dependencies:
  foo: ^1.0.0
''';
      final result = PubspecUtils.setConstraint(dup, 'foo', '^2.0.0');
      // First occurrence updated, second left alone
      expect(
        result,
        equals('''
dependencies:
  foo: ^2.0.0
dev_dependencies:
  foo: ^1.0.0
'''),
      );
    });

    test('handles packages with underscores and numbers in name', () {
      const content = '''
dependencies:
  my_package_2: ^1.0.0
''';
      final result = PubspecUtils.setConstraint(
        content,
        'my_package_2',
        '^2.0.0',
      );
      expect(result, contains('  my_package_2: ^2.0.0'));
    });

    test('preserves rest of file structure', () {
      final result = PubspecUtils.setConstraint(pubspec, 'foo', '^5.0.0');
      expect(result, contains('dependencies:'));
      expect(result, contains('dev_dependencies:'));
      expect(result, contains('  bar: ^2.0.0'));
      expect(result, contains('  baz: ^3.0.0'));
    });
  });

  group('PubspecUtils.getConstraint', () {
    const pubspec = '''
dependencies:
  foo: ^1.0.0
  bar: ^2.0.0
dev_dependencies:
  baz: ^3.0.0
''';

    test('reads a top-level dependency constraint', () {
      expect(PubspecUtils.getConstraint(pubspec, 'foo'), '^1.0.0');
    });

    test('reads a dev_dependency constraint', () {
      expect(PubspecUtils.getConstraint(pubspec, 'baz'), '^3.0.0');
    });

    test('returns null for an unknown package', () {
      expect(PubspecUtils.getConstraint(pubspec, 'unknown'), isNull);
    });

    test('returns the first occurrence when a package appears twice', () {
      const dup = '''
dependencies:
  foo: ^1.0.0
dev_dependencies:
  foo: ^9.9.9
''';
      expect(PubspecUtils.getConstraint(dup, 'foo'), '^1.0.0');
    });
  });

  group('OutdatedParser.parse', () {
    test('parses packages with all version fields', () {
      const json = '''
{
  "packages": [
    {
      "package": "dio",
      "kind": "direct",
      "current": {"version": "4.0.6"},
      "upgradable": {"version": "4.0.6"},
      "resolvable": {"version": "5.7.0"},
      "latest": {"version": "5.7.0"}
    }
  ]
}
''';
      final packages = OutdatedParser.parse(json);
      expect(packages, hasLength(1));
      final dio = packages.single;
      expect(dio.name, 'dio');
      expect(dio.kind, 'direct');
      expect(dio.current, '4.0.6');
      expect(dio.resolvable, '5.7.0');
      expect(dio.latest, '5.7.0');
      expect(dio.isDirect, isTrue);
      expect(dio.hasResolvableUpgrade, isTrue);
      expect(dio.isBehindLatest, isFalse);
    });

    test('handles null version fields', () {
      const json = '''
{
  "packages": [
    {
      "package": "unresolved",
      "kind": "direct",
      "current": null,
      "upgradable": null,
      "resolvable": {"version": "1.2.0"},
      "latest": {"version": "1.2.0"}
    }
  ]
}
''';
      final pkg = OutdatedParser.parse(json).single;
      expect(pkg.current, isNull);
      expect(pkg.resolvable, '1.2.0');
      expect(pkg.hasResolvableUpgrade, isTrue);
      expect(pkg.effectiveResolvable, '1.2.0');
    });

    test('flags a package held back from its latest version', () {
      const json = '''
{
  "packages": [
    {
      "package": "held",
      "kind": "dev",
      "current": {"version": "1.0.0"},
      "resolvable": {"version": "1.5.0"},
      "latest": {"version": "2.0.0"}
    }
  ]
}
''';
      final pkg = OutdatedParser.parse(json).single;
      expect(pkg.isDirect, isTrue);
      expect(pkg.hasResolvableUpgrade, isTrue);
      expect(pkg.isBehindLatest, isTrue);
      expect(pkg.upgradeTarget, '2.0.0');
    });

    test('marks transitive dependencies as non-direct', () {
      const json = '''
{
  "packages": [
    {
      "package": "meta",
      "kind": "transitive",
      "current": {"version": "1.0.0"},
      "resolvable": {"version": "1.1.0"},
      "latest": {"version": "1.1.0"}
    }
  ]
}
''';
      expect(OutdatedParser.parse(json).single.isDirect, isFalse);
    });

    test('treats an already-latest package as having no upgrade', () {
      const json = '''
{
  "packages": [
    {
      "package": "current_pkg",
      "kind": "direct",
      "current": {"version": "3.0.0"},
      "resolvable": {"version": "3.0.0"},
      "latest": {"version": "3.0.0"}
    }
  ]
}
''';
      final pkg = OutdatedParser.parse(json).single;
      expect(pkg.hasResolvableUpgrade, isFalse);
      expect(pkg.isBehindLatest, isFalse);
    });

    test('returns an empty list when there are no packages', () {
      expect(OutdatedParser.parse('{"packages": []}'), isEmpty);
      expect(OutdatedParser.parse('{}'), isEmpty);
    });
  });
}
