import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/text/app_formatted_text.dart';

void main() {
  testWidgets('AppFormattedText: 通常テキスト、太字、primary、error、secondaryタグが正しく描画される', (
    tester,
  ) async {
    const text =
        '通常テキスト **太字** [primary]プライマリ強調[/primary] [error]エラー警告[/error] [secondary]サブ強調[/secondary]';

    const primaryColor = Colors.blue;
    const errorColor = Colors.red;
    const secondaryColor = Colors.green;

    final themeData = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        error: errorColor,
        secondary: secondaryColor,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(body: AppFormattedText(text)),
      ),
    );

    final richTextFinder = find.byType(RichText);
    expect(richTextFinder, findsOneWidget);

    final richText = tester.widget<RichText>(richTextFinder);
    final rootSpan = richText.text as TextSpan;

    String cleanText(String raw) =>
        raw.replaceAll('\u2060', '').replaceAll('\u200B', '');

    final fullCleanText = cleanText(rootSpan.toPlainText());

    // 全体のテキストが含まれているか
    expect(fullCleanText, contains('通常テキスト'));
    expect(fullCleanText, contains('太字'));
    expect(fullCleanText, contains('プライマリ強調'));
    expect(fullCleanText, contains('エラー警告'));
    expect(fullCleanText, contains('サブ強調'));

    final allSpans = <TextSpan>[];
    rootSpan.visitChildren((span) {
      if (span is TextSpan) {
        allSpans.add(span);
      }
      return true;
    });

    // 2. 太字
    final boldSpan = allSpans.firstWhere(
      (s) => cleanText(s.toPlainText()).contains('太字'),
    );
    expect(boldSpan.style?.fontWeight, FontWeight.bold);

    // 4. primary強調
    final primarySpan = allSpans.firstWhere(
      (s) => cleanText(s.toPlainText()).contains('プライマリ強調'),
    );
    expect(primarySpan.style?.color, primaryColor);
    expect(primarySpan.style?.fontWeight, FontWeight.bold);

    // 6. error警告
    final errorSpan = allSpans.firstWhere(
      (s) => cleanText(s.toPlainText()).contains('エラー警告'),
    );
    expect(errorSpan.style?.color, errorColor);
    expect(errorSpan.style?.fontWeight, FontWeight.bold);

    // 8. secondary強調
    final secondarySpan = allSpans.firstWhere(
      (s) => cleanText(s.toPlainText()).contains('サブ強調'),
    );
    expect(secondarySpan.style?.color, secondaryColor);
    expect(secondarySpan.style?.fontWeight, FontWeight.bold);
  });
}
