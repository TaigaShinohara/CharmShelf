import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/create_folder_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  showDialog<String>(context: context, builder: (_) => child),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
  }

  group('CreateFolderDialog', () {
    testWidgets('初期状態: タイトルが表示され、作成ボタンは非活性であること', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const CreateFolderDialog()));

      // ダイアログを開く
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('新規フォルダ'), findsOneWidget);
      expect(find.text('フォルダ名を入力'), findsOneWidget);
      expect(find.bySemanticsLabel('キャンセル'), findsOneWidget);
      expect(find.text('作成'), findsOneWidget);

      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '作成'),
      );
      expect(createButton.onPressed, isNull);
    });

    testWidgets('有効なフォルダ名を入力すると、作成ボタンが活性化され、タップでその名前が返ること', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => const CreateFolderDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '旅行の写真 ');
      await tester.pumpAndSettle();

      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '作成'),
      );
      expect(createButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, '作成'));
      await tester.pumpAndSettle();

      // ダイアログが閉じ、トリムされた文字列が返ること
      expect(find.byType(CreateFolderDialog), findsNothing);
      expect(result, '旅行の写真');
    });

    testWidgets('不正な文字が含まれる場合、エラーメッセージが表示され作成ボタンが非活性であること', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const CreateFolderDialog()));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '写真:2024');
      await tester.pumpAndSettle();

      expect(find.textContaining('使用できません'), findsOneWidget);
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '作成'),
      );
      expect(createButton.onPressed, isNull);
    });

    testWidgets('空白のみが入力された場合、作成ボタンが非活性であること', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const CreateFolderDialog()));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '作成'),
      );
      expect(createButton.onPressed, isNull);
    });

    testWidgets('キャンセルボタンをタップすると、nullが返ること', (tester) async {
      String? result = 'not_null';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => const CreateFolderDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CreateFolderDialog), findsNothing);
      expect(result, isNull);
    });
  });
}
