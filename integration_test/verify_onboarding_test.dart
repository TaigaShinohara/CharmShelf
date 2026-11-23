import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('初回案内から使い方を開いてカタログの説明を表示する', (tester) async {
    final testErrorHandler = FlutterError.onError;
    final dispatcher = binding.platformDispatcher;
    final testPlatformErrorHandler = dispatcher.onError;
    try {
      app.main();
    } finally {
      FlutterError.onError = testErrorHandler;
      dispatcher.onError = testPlatformErrorHandler;
    }

    final onboarding = find.byKey(const ValueKey('onboarding'));
    final restorePrompt = find.byKey(const ValueKey('restore_prompt'));
    await _until(
      tester,
      () =>
          onboarding.evaluate().isNotEmpty ||
          restorePrompt.evaluate().isNotEmpty,
    );

    if (restorePrompt.evaluate().isNotEmpty) {
      final l10n = AppLocalizations.of(tester.element(restorePrompt))!;
      await tester.tap(find.text(l10n.dataRestoreActionContinue));
      await _until(tester, () => onboarding.evaluate().isNotEmpty);
    }

    final l10n = AppLocalizations.of(tester.element(onboarding))!;
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final guide = find.byKey(const ValueKey('onboarding-guide'));
    await tester.ensureVisible(guide);
    await tester.pump(const Duration(milliseconds: 400));
    await _saveShot(binding, 'onboarding-welcome');

    await tester.tap(guide);
    await _until(
      tester,
      () => find.text(l10n.onboardingCatalogTitle).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 400));
    final closeGuide = find.byKey(const ValueKey('onboarding-guide-close'));
    expect(closeGuide, findsOneWidget);
    await _saveShot(binding, 'onboarding-catalog');

    await tester.tap(closeGuide);
    await _until(tester, () => closeGuide.evaluate().isEmpty);
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
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
