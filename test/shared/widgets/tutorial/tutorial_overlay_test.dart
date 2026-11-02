import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/modern_dialog.dart';
import 'package:private_shelf/shared/widgets/tutorial/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../finders.dart' as shared_find;

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'tutorial.tone_color_test_20260915.completed': false,
    }),
  );

  testWidgets('重要は黄色、危険は赤で1ページずつ表示する', (tester) async {
    tester.view.physicalSize = const Size(427, 952);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => TutorialOverlay.show(
                  context,
                  ref: ref,
                  tutorialId: 'tone_color_test_20260915',
                  steps: const [
                    TutorialStep(
                      title: '大切な説明',
                      message: '大切な内容',
                      tone: TutorialTone.important,
                    ),
                    TutorialStep(
                      title: '危険な説明',
                      message: '危険な内容',
                      tone: TutorialTone.danger,
                    ),
                  ],
                ),
                child: const Text('表示'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('表示'));
    await tester.pumpAndSettle();

    expect(find.byType(ModernDialog), findsOneWidget);
    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    expect(shared_find.findAppText('大切な説明'), findsOneWidget);

    expect(shared_find.findAppText('重要'), findsOneWidget);
    expect(shared_find.findAppText('大切な説明'), findsOneWidget);
    expect(shared_find.findAppText('危険な説明'), findsNothing);
    final importantCard = find.byKey(const ValueKey('tutorial-card-important'));
    expect(
      tester.widget<Material>(importantCard).color,
      Theme.of(tester.element(importantCard)).appColors.warningContainer,
    );

    await tester.tap(shared_find.findAppText('次へ'));
    await tester.pump();

    expect(shared_find.findAppText('注意'), findsOneWidget);
    expect(shared_find.findAppText('大切な説明'), findsNothing);
    expect(shared_find.findAppText('危険な説明'), findsOneWidget);
    final dangerCard = find.byKey(const ValueKey('tutorial-card-danger'));
    expect(
      tester.widget<Material>(dangerCard).color,
      Theme.of(tester.element(dangerCard)).colorScheme.errorContainer,
    );
  });

  testWidgets('プレビューで最後まで見ても既読状態を変更しない', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => TutorialOverlay.show(
                  context,
                  ref: ref,
                  tutorialId: 'tone_color_test_20260915',
                  preview: true,
                  steps: const [TutorialStep(title: '見直す説明', message: '見直す内容')],
                ),
                child: const Text('表示'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('表示'));
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('見直す説明'), findsOneWidget);

    await tester.tap(shared_find.findAppText('完了'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('tutorial.tone_color_test_20260915.completed'),
      isFalse,
    );
  });

  testWidgets('初回自動表示は画面下部カードのまま表示する', (tester) async {
    tester.view.physicalSize = const Size(427, 952);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: TutorialOverlay(
              tutorialId: 'tone_color_test_20260915',
              steps: [TutorialStep(title: '初回案内', message: '画面下部の案内')],
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find.byKey(const ValueKey('tutorial-card-normal')),
    );
    expect(card.bottom, greaterThan(900));
    expect(find.byType(ModernDialog), findsNothing);
  });
}
