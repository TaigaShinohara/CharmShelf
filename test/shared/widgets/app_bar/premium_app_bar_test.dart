import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

void main() {
  group('PremiumAppBar', () {
    testWidgets('titleText と leading が正しく表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const PremiumAppBar(titleText: 'テストタイトル'),
            body: Container(),
          ),
        ),
      );

      expect(find.text('テストタイトル'), findsOneWidget);
    });

    testWidgets('subtitleText と actions が正しく表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PremiumAppBar(
              titleText: 'メインタイトル',
              subtitleText: 'サブタイトル',
              actions: [
                IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
              ],
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.text('メインタイトル'), findsOneWidget);
      expect(find.text('サブタイトル'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
