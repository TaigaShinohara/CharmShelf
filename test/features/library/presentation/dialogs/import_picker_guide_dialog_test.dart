import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/presentation/dialogs/import_picker_guide_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/modern_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestableWidget(
    Widget child, {
    List<Override> overrides = const [],
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.iOS,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showModernDialog<bool>(context, child: child),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('ImportPickerGuideDialog', () {
    testWidgets('初回は棚へ追加してタグで管理できることを案内する', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ImportPickerGuideDialog()),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ファイルを取り込んで、チャームをつける'), findsOneWidget);
      expect(
        find.textContaining('カタログにすると、チャームをつけて自分らしく、見つけやすく整理できます'),
        findsOneWidget,
      );
      expect(find.textContaining('元のファイルは削除・移動されず'), findsOneWidget);
      expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
      expect(find.textContaining('ファイル選択画面'), findsNothing);
      expect(find.textContaining('通知'), findsNothing);
      expect(find.textContaining('戻る'), findsNothing);
      expect(find.bySemanticsLabel('キャンセル'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('ファイルを選ぶ'), findsOneWidget);
    });

    testWidgets('幅360dp・文字サイズ200%・Androidでも内容と操作が欠けず描画される', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const ImportPickerGuideDialog(),
          textScale: 2,
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ファイルを取り込んで、チャームをつける'), findsOneWidget);
      expect(
        find.textContaining('カタログにすると、チャームをつけて自分らしく、見つけやすく整理できます'),
        findsOneWidget,
      );
      expect(find.textContaining('元のファイルは削除・移動されず'), findsOneWidget);
      expect(find.textContaining('通知'), findsNothing);
      expect(find.bySemanticsLabel('キャンセル'), findsOneWidget);
      expect(find.text('ファイルを選ぶ'), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.close_rounded)).dy,
        closeTo(tester.getCenter(find.text('ファイルを選ぶ')).dy, 1),
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('ファイルを選ぶ'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('「ファイル選択へ進む」タップで true が返ること', (tester) async {
      bool? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) => Future.value(prefs),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            const Dialog(child: ImportPickerGuideDialog()),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ファイルを選ぶ'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportPickerGuideDialog), findsNothing);
      expect(result, true);
    });

    testWidgets('「キャンセル」タップで false が返ること', (tester) async {
      bool? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) => Future.value(prefs),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            const Dialog(child: ImportPickerGuideDialog()),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ImportPickerGuideDialog), findsNothing);
      expect(result, false);
      expect(
        prefs.getBool(AppPreferences.importPickerGuideDismissedKey),
        isNot(true),
      );
    });

    testWidgets('案内を進めると既読状態を保存し、次回から案内を省略する', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ImportPickerGuideDialog()),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 進むをタップ
      await tester.tap(find.text('ファイルを選ぶ'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(AppPreferences.importPickerGuideDismissedKey), true);
    });

    testWidgets('プレビューを閉じても既読状態を変更しない', (tester) async {
      await prefs.setBool(AppPreferences.importPickerGuideDismissedKey, false);
      await tester.pumpWidget(
        buildTestableWidget(const ImportPickerGuideDialog(preview: true)),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('閉じる'), findsOneWidget);
      expect(find.text('ファイルを選ぶ'), findsNothing);
      expect(find.text('キャンセル'), findsNothing);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      expect(
        prefs.getBool(AppPreferences.importPickerGuideDismissedKey),
        isFalse,
      );
    });

    testWidgets('ensureGuideShown: 既に非表示設定済みの場合はダイアログを表示せず true を返すこと', (
      tester,
    ) async {
      await prefs.setBool(AppPreferences.importPickerGuideDismissedKey, true);
      bool? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) => Future.value(prefs),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      result = await ImportPickerGuideDialog.ensureGuideShown(
                        context,
                        ref,
                      );
                    },
                    child: const Text('EnsureGuide'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('EnsureGuide'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportPickerGuideDialog), findsNothing);
      expect(result, true);
    });
  });
}
