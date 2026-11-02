import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDir = Platform.environment['VERIFY_ARTIFACTS'];
  if (outputDir == null || outputDir.isEmpty) {
    throw StateError('VERIFY_ARTIFACTS がありません');
  }
  await Directory(outputDir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('$outputDir/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
