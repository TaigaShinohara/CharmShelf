import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('初回案内の次へでカタログの説明に進む', (tester) async {
    app.main();
    await _until(
      tester,
      () =>
          find.byKey(const ValueKey('onboarding')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('restore_prompt')).evaluate().isNotEmpty,
    );

    if (find.byKey(const ValueKey('restore_prompt')).evaluate().isNotEmpty) {
      await tester.tap(find.text('このまま'));
      await tester.pump();
      await _until(
        tester,
        () => find.byKey(const ValueKey('onboarding')).evaluate().isNotEmpty,
      );
    }

    expect(find.text('好きなものが並ぶ、あなたの本棚へ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final next = find.byKey(const ValueKey('onboarding-next'));
    await tester.ensureVisible(next);
    await tester.pump(const Duration(milliseconds: 400));
    await _saveShot(binding, 'onboarding-welcome');

    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 400));
    await _until(
      tester,
      () => find.text('写真はフォトブックに。音楽はアルバムに').evaluate().isNotEmpty,
    );
    expect(find.text('前へ'), findsOneWidget);
    await _saveShot(binding, 'onboarding-catalog');
  });
}

Future<void> _saveShot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/$name.png').writeAsBytes(bytes, flush: true);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (ready()) {
      return;
    }
  }
  throw TestFailure('CharmShelfの画面が時間内に出ませんでした');
}
