import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/security/presentation/widgets/passcode_keypad.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('数字キーと削除キーを重複なく読み上げる', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: PasscodeKeypad(onDigitPress: (_) {}, onDeletePress: () {}),
          ),
        ),
      ),
    );

    for (var digit = 0; digit <= 9; digit++) {
      expect(find.bySemanticsLabel('$digit'), findsOneWidget);
    }
    expect(find.bySemanticsLabel('削除'), findsOneWidget);
    expect(find.bySemanticsLabel('生体認証'), findsNothing);
    semantics.dispose();
  });

  testWidgets('生体認証キーを表示すると一度だけ読み上げる', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: PasscodeKeypad(
              onDigitPress: (_) {},
              onDeletePress: () {},
              onBiometricsPress: () {},
              showBiometrics: true,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('生体認証'), findsOneWidget);
    semantics.dispose();
  });
}
