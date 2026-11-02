import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/rename_item_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    required String initialName,
    bool isFolder = false,
    Iterable<String>? existingNames,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRenameItemDialog(
              context,
              initialName: initialName,
              isFolder: isFolder,
              existingNames: existingNames,
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );
  }

  group('RenameItemDialog', () {
    testWidgets('初期表示時にベース名のみが入力欄にセットされ、保存ボタンが無効（未変更）', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialName: 'sample_photo.jpg'));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'sample_photo');

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('同名重複がある場合はリアルタイムでエラーが表示され保存不可', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          initialName: 'photo1.jpg',
          existingNames: ['photo1.jpg', 'photo2.jpg'],
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'photo2');
      await tester.pumpAndSettle();

      expect(find.text('同じ名前の項目が既に存在します'), findsOneWidget);

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('有効な名前を入力して保存すると、拡張子付きのフルネームが返る', (tester) async {
      String? returnedName;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedName = await showRenameItemDialog(
                    context,
                    initialName: 'old_file.png',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'new_file');
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(returnedName, 'new_file.png');
    });
  });
}
