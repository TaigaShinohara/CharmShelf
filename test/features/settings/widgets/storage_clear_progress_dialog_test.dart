import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/settings/presentation/widgets/storage_clear_progress_dialog.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_service.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _MockStorageClearService extends Mock implements StorageClearService {}

void main() {
  testWidgets(
    'StorageClearProgressDialog shows countdown and allows cancellation',
    (tester) async {
      StorageClearDialogResult? dialogResult;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('ja'), Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await StorageClearProgressDialog.show(
                      context,
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // ダイアログを開く
      await tester.tap(find.text('Open Dialog'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StorageClearProgressDialog), findsOneWidget);
      expect(find.text('ストレージ消去の準備中'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('今すぐ中断する'), findsOneWidget);

      // 1秒経過
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('4'), findsOneWidget);

      // 中断ボタンを押す
      await tester.tap(find.text('今すぐ中断する'));
      await tester.pumpAndSettle();

      expect(find.byType(StorageClearProgressDialog), findsNothing);
      expect(dialogResult, StorageClearDialogResult.cancelled);
    },
  );

  testWidgets('削除開始後は中断ボタンと戻る操作で部分削除にしない', (tester) async {
    final serviceCompleter = Completer<StorageClearService>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageClearServiceProvider.overrideWith(
            (ref) => serviceCompleter.future,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StorageClearProgressDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('今すぐ中断する'), findsNothing);
    expect(find.byType(StorageClearProgressDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(StorageClearProgressDialog), findsOneWidget);
  });

  testWidgets('後処理が失敗した場合は通常操作へ戻さず再試行で完了する', (tester) async {
    final service = _MockStorageClearService();
    when(
      () => service.clearStorage(),
    ).thenAnswer((_) async => Result.failure(AppError.file('release failed')));
    when(() => service.hasPendingClear()).thenAnswer((_) async => true);
    when(
      () => service.recoverPendingClear(),
    ).thenAnswer((_) async => Result.success(null));
    StorageClearDialogResult? dialogResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageClearServiceProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await StorageClearProgressDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.byType(StorageClearProgressDialog), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
    expect(dialogResult, isNull);

    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();

    expect(find.byType(StorageClearProgressDialog), findsNothing);
    expect(dialogResult, StorageClearDialogResult.success);
  });
}
