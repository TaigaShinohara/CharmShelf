import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/onboarding/presentation/onboarding_screen.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('ja'),
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      hapticsEnabledProvider.overrideWith((ref) => false),
      sharedPreferencesProvider.overrideWith(
        (ref) async => SharedPreferences.getInstance(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  if (Platform.isLinux) {
    // macOSで生成されたゴールデンとLinux環境のフォント/レンダリング差異が大きいため、
    // Linux上ではゴールデンテストをスキップする。
    return;
  }
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding ja', (tester) async {
    await tester.pumpWidget(_wrap(OnboardingScreen(onComplete: () {})));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/goldens/onboarding_ja.png'),
    );
  }, tags: 'golden');

  testWidgets('onboarding en', (tester) async {
    await tester.pumpWidget(
      _wrap(OnboardingScreen(onComplete: () {}), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/goldens/onboarding_en.png'),
    );
  }, tags: 'golden');

  testWidgets('onboarding ja 200pct', (tester) async {
    await tester.pumpWidget(
      _wrap(OnboardingScreen(onComplete: () {}), textScale: 2),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/goldens/onboarding_ja_200pct.png'),
    );
  }, tags: 'golden');

  testWidgets('settings ja', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/goldens/settings_ja.png'),
    );
  }, tags: 'golden');

  testWidgets('settings en', (tester) async {
    await tester.pumpWidget(
      _wrap(const SettingsPage(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/goldens/settings_en.png'),
    );
  }, tags: 'golden');

  testWidgets('settings ja 200pct', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage(), textScale: 2));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/goldens/settings_ja_200pct.png'),
    );
  }, tags: 'golden');
}
