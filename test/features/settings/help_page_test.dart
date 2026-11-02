import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/settings/presentation/help_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('ja'), Locale('en')]) {
    testWidgets('ヘルプのカードが $locale で表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
