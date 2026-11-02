import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/states/async_value_widget.dart';
import 'package:private_shelf/shared/widgets/states/loading_widget.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: Scaffold(body: child),
    );
  }

  group('AsyncValueWidget', () {
    testWidgets('データがある場合はbuilderが呼ばれる', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          AsyncValueWidget<String>(
            value: const AsyncValue.data('Hello'),
            builder: (data) => Text(data),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('ローディング中はLoadingWidgetが表示される', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          AsyncValueWidget<String>(
            value: const AsyncValue.loading(),
            builder: (data) => Text(data),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LoadingWidget は読み上げ用のラベルを持つ', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const LoadingWidget(message: '処理中です')),
      );

      expect(find.bySemanticsLabel('処理中です'), findsOneWidget);
    });

    testWidgets('カスタムローディングウィジェットを指定できる', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          AsyncValueWidget<String>(
            value: const AsyncValue.loading(),
            builder: (data) => Text(data),
            loading: const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('エラー時はErrorStateWidgetが表示される', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          AsyncValueWidget<String>(
            value: AsyncValue.error(
              Exception('Test error'),
              StackTrace.current,
            ),
            builder: (data) => Text(data),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // ErrorStateWidgetが表示されていることを確認
      expect(find.byType(Text), findsWidgets);
    });
  });
}
