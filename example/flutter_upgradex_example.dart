import 'package:flutter_upgradex/flutter_upgradex.dart';

void main() async {
  // Run from the root of a Flutter project to upgrade all dependencies.
  final upgrader = FlutterUpgradeX();
  await upgrader.run();
}
