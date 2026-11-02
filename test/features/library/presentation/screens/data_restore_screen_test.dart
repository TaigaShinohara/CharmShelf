import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/presentation/providers/data_restore_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/data_restore_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  Widget buildSubject({
    required RestorableDataSummary summary,
    required VoidCallback onRestoreCompleted,
    required VoidCallback onSkipped,
    List<Override> overrides = const [],
    double textScale = 1.0,
    bool autoStartRestore = false,
    Locale locale = const Locale('ja'),
  }) {
    return ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ja'), Locale('en')],
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: DataRestoreScreen(
            summary: summary,
            onRestoreCompleted: onRestoreCompleted,
            onSkipped: onSkipped,
            autoStartRestore: autoStartRestore,
          ),
        ),
      ),
    );
  }

  testWidgets('フォルダ選択待ちは自動復元せず選択ボタンから開始する', (tester) async {
    final notifier = _FolderSelectionNotifier();
    await tester.pumpWidget(
      buildSubject(
        summary: RestorableDataSummary.empty,
        onRestoreCompleted: () {},
        onSkipped: () {},
        autoStartRestore: true,
        overrides: [dataRestoreNotifierProvider.overrideWith(() => notifier)],
      ),
    );
    await tester.pump();
    expect(notifier.executeRestoreCalled, isFalse);
    await tester.tap(find.text('以前のデータを戻す'));
    await tester.pump();
    expect(notifier.executeRestoreCalled, isTrue);
  });

  group('DataRestoreScreen (報告専用画面)', () {
    testWidgets('復元完了時に「以前のデータを復元しました」と3カラム統計、「アプリを始める」ボタンが表示される', (
      tester,
    ) async {
      final summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 12,
        collectionCount: 0,
        mediaItemCount: 42,
        folderCount: 3,
        storagePath: '/test/path',
        lastExportedAt: DateTime(2026, 8, 27, 15, 30),
      );

      var started = false;

      await tester.pumpWidget(
        buildSubject(
          summary: summary,
          onRestoreCompleted: () => started = true,
          onSkipped: () {},
          overrides: [
            dataRestoreNotifierProvider.overrideWith(
              () => _TestSuccessDataRestoreNotifier(summary: summary),
            ),
          ],
        ),
      );

      expect(find.text('以前のデータを復元しました'), findsOneWidget);
      expect(find.text('端末内に保存されていたデータが見つかったため、自動で復元しました。'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('メディア'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('チャーム'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('コレクション'), findsOneWidget);
      expect(find.text('アプリを始める'), findsOneWidget);
      // 長い内部パスは非表示
      expect(find.text('/test/path'), findsNothing);
      // Semanticsラベルが設定されている
      expect(find.bySemanticsLabel('メディアファイル 42 件'), findsOneWidget);
      expect(find.bySemanticsLabel('チャーム 12 件'), findsOneWidget);
      expect(find.bySemanticsLabel('コレクション 0 件'), findsOneWidget);

      await tester.tap(find.text('アプリを始める'));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('画面生成時の件数が空でも保持中の検出結果を完了件数として表示する', (tester) async {
      const detectedSummary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 47,
        collectionCount: 2,
        mediaItemCount: 3,
        folderCount: 2,
        storagePath: '/test/path',
      );

      await tester.pumpWidget(
        buildSubject(
          summary: RestorableDataSummary.empty,
          onRestoreCompleted: () {},
          onSkipped: () {},
          overrides: [
            dataRestoreNotifierProvider.overrideWith(
              () => _TestSuccessDataRestoreNotifier(summary: detectedSummary),
            ),
          ],
        ),
      );

      expect(find.text('47'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('チャーム 47 件'), findsOneWidget);
    });

    testWidgets('通常時はPopScopeのcanPopがtrueである', (tester) async {
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 1,
        collectionCount: 1,
        mediaItemCount: 1,
        folderCount: 1,
        storagePath: '/test/path',
      );

      await tester.pumpWidget(
        buildSubject(
          summary: summary,
          onRestoreCompleted: () {},
          onSkipped: () {},
        ),
      );

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isTrue);
    });

    testWidgets('エラー時はインラインエラーバナーと「このまま」が表示される', (tester) async {
      var skipped = false;
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 1,
        collectionCount: 1,
        mediaItemCount: 1,
        folderCount: 1,
        storagePath: '/test/path',
      );

      await tester.pumpWidget(
        buildSubject(
          summary: summary,
          onRestoreCompleted: () {},
          onSkipped: () => skipped = true,
          overrides: [
            dataRestoreNotifierProvider.overrideWith(
              () => _TestErrorDataRestoreNotifier(),
            ),
          ],
        ),
      );

      expect(find.text('ファイルの操作に失敗しました'), findsOneWidget);
      expect(find.textContaining('ディスク容量不足'), findsNothing);
      expect(find.text('再試行'), findsOneWidget);
      expect(find.text('このまま'), findsOneWidget);

      await tester.tap(find.text('このまま'));
      await tester.pump();

      expect(skipped, isTrue);
    });

    testWidgets('文字サイズ200%（textScale: 2.0）でもRenderFlexエラーなく描画できる', (
      tester,
    ) async {
      final summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 9999,
        collectionCount: 8888,
        mediaItemCount: 7777,
        folderCount: 3,
        storagePath: '/test/path',
        lastExportedAt: DateTime(2026, 8, 27, 15, 30),
      );

      await tester.pumpWidget(
        buildSubject(
          summary: summary,
          onRestoreCompleted: () {},
          onSkipped: () {},
          textScale: 2.0,
          overrides: [
            dataRestoreNotifierProvider.overrideWith(
              () => _TestSuccessDataRestoreNotifier(summary: summary),
            ),
          ],
        ),
      );

      expect(find.text('以前のデータを復元しました'), findsOneWidget);
      expect(find.text('9999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('autoStartRestoreがtrueの場合、マウント時にexecuteRestoreが呼ばれる', (
      tester,
    ) async {
      final mockNotifier = _TestMockAutoRestoreNotifier();
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 1,
        collectionCount: 1,
        mediaItemCount: 1,
        folderCount: 1,
        storagePath: '/test/path',
      );

      await tester.pumpWidget(
        buildSubject(
          summary: summary,
          onRestoreCompleted: () {},
          onSkipped: () {},
          autoStartRestore: true,
          overrides: [
            dataRestoreNotifierProvider.overrideWith(() => mockNotifier),
          ],
        ),
      );

      await tester.pump();
      expect(mockNotifier.executeRestoreCalled, isTrue);
    });
  });
}

class _TestSuccessDataRestoreNotifier extends DataRestoreNotifier {
  _TestSuccessDataRestoreNotifier({required this.summary});
  final RestorableDataSummary summary;

  @override
  DataRestoreState build() {
    return DataRestoreState(
      status: DataRestoreStatus.success,
      summary: summary,
    );
  }
}

class _TestErrorDataRestoreNotifier extends DataRestoreNotifier {
  @override
  DataRestoreState build() {
    return DataRestoreState(
      status: DataRestoreStatus.error,
      error: AppError.file('ディスク容量不足'),
    );
  }
}

class _TestMockAutoRestoreNotifier extends DataRestoreNotifier {
  bool executeRestoreCalled = false;

  @override
  DataRestoreState build() {
    return const DataRestoreState(status: DataRestoreStatus.readyToRestore);
  }

  @override
  Future<Result<void, AppError>> executeRestore() async {
    executeRestoreCalled = true;
    return Result.success(null);
  }
}

class _FolderSelectionNotifier extends _TestMockAutoRestoreNotifier {
  @override
  DataRestoreState build() =>
      const DataRestoreState(status: DataRestoreStatus.permissionRequired);
}
