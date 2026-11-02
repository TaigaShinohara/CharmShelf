import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:private_shelf/features/splash/presentation/screens/app_splash_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

Widget _createSplashApp() {
  return const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('ja'), Locale('en')],
    home: AppSplashScreen(),
  );
}

void main() {
  testWidgets('AppSplashScreen が描画される', (WidgetTester tester) async {
    await tester.pumpWidget(_createSplashApp());

    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.pump();
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSplashScreen の静止ロゴを維持する', (WidgetTester tester) async {
    await tester.pumpWidget(_createSplashApp());

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('startup_logo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
