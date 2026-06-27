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
}
