import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/confirm_dialog.dart';

import '../finders.dart';

void main() {
  Widget buildSubject({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  }) {
    return ProviderScope(
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
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: title,
                  message: message,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                ),
                child: const Text('ダイアログを開く'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ConfirmDialog: [error]や**太字**タグが正しくパースされ、生のタグが表示されない', (
    tester,
  ) async {
    const title = 'パスコードを設定しますか？';
    const message =
        '[error]重要[/error]: パスコードを忘れた場合、**アプリ内で復旧・再発行はできません**。\n\n生体認証が使えなくなる場合に備えて、忘れないよう必ずメモ等をお控えください。';

    await tester.pumpWidget(
      buildSubject(
        title: title,
        message: message,
        confirmLabel: '理解して設定',
        cancelLabel: 'キャンセル',
      ),
    );
    await tester.pumpAndSettle();

    // ダイアログを開く
    await tester.tap(find.text('ダイアログを開く'));
    await tester.pumpAndSettle();

    // タイトルとアクションボタンの確認
    expect(findAppText('パスコードを設定しますか？'), findsOneWidget);
    expect(findAppText('理解して設定'), findsOneWidget);
    expect(find.bySemanticsLabel('キャンセル'), findsOneWidget);

    // 生のタグ [error] や [/error] や ** がそのまま表示されていないこと
    expect(findAppTextContaining('[error]'), findsNothing);
    expect(findAppTextContaining('[/error]'), findsNothing);
    expect(findAppTextContaining('**'), findsNothing);

    // パースされた文言が表示されていること
    expect(findAppTextContaining('重要'), findsOneWidget);
    expect(findAppTextContaining('アプリ内で復旧・再発行はできません'), findsOneWidget);

    // キャンセルボタンを押して閉じる
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(findAppText('パスコードを設定しますか？'), findsNothing);
  });
}
