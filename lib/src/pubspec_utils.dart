/// Utilities for reading and modifying pubspec.yaml content.
class PubspecUtils {
  /// Returns true if [value] is a simple hosted dependency (a version string).
  ///
  /// Returns false for sdk, git, and path dependencies, which cannot be
  /// upgraded via pub.dev.
  static bool isHostedDep(dynamic value) => value is String;

  /// Replaces the version constraint for [package] in [content] with [constraint].
  ///
  /// Only replaces the first occurrence (top-level dependencies take precedence
  /// over dev_dependencies when a package appears in both sections).
  /// Returns [content] unchanged if [package] is not found.
  static String setConstraint(
    String content,
    String package,
    String constraint,
  ) {
    final pattern = RegExp(
      r'^(\s+' + RegExp.escape(package) + r':\s*)(.+)$',
      multiLine: true,
    );
    return content.replaceFirstMapped(pattern, (m) => '${m[1]}$constraint');
  }

  /// Reads the current version constraint for [package] in [content].
  ///
  /// Returns the first occurrence's constraint (dependencies before
  /// dev_dependencies), or null if [package] is not present as a hosted dep.
  static String? getConstraint(String content, String package) {
    final pattern = RegExp(
      r'^\s+' + RegExp.escape(package) + r':\s*(.+)$',
      multiLine: true,
    );
    return pattern.firstMatch(content)?.group(1)?.trim();
  }
}
