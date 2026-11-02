import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_import_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('showTagImportSheet でテキストモードに切り替えてもエラーなく描画される', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTagImportSheet(context),
            child: const Text('Open Import Sheet'),
          ),
        ),
      ),
    );

    // ボトムシートを開く
    await tester.tap(find.text('Open Import Sheet'));
    await tester.pumpAndSettle();

    // 初期状態はファイルインポートモード
    expect(find.byType(TagImportSheet), findsOneWidget);

    // 「テキストからインポート」セグメントをタップ
    final textSegmentFinder = find.descendant(
      of: find.byType(SegmentedButton<bool>),
      matching: find.byIcon(Icons.text_fields),
    );
    expect(textSegmentFinder, findsOneWidget);
    await tester.tap(textSegmentFinder);
    await tester.pumpAndSettle();

    // テキスト入力用のTextFieldとボタン群が表示されることを確認
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('チェック'), findsOneWidget);
    expect(find.text('取り込み実行'), findsOneWidget);
  });
}
