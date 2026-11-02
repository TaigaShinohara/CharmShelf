import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/splash/presentation/screens/app_splash_screen.dart';

void main() {
  testWidgets('起動待ちでは静止ロゴを表示し、動画を起動しない', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppSplashScreen()));

    expect(find.byKey(const ValueKey('startup_logo')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('時間がかかった場合だけ状態説明を表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSplashScreen(
          statusText: 'データを安全に確認しています…',
          statusDelay: Duration(seconds: 2),
        ),
      ),
    );

    expect(find.text('データを安全に確認しています…'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('データを安全に確認しています…'), findsOneWidget);
  });
}
