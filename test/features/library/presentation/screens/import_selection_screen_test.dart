import '../../../../helpers/visual_review_capture.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/internal_import_service_provider.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:private_shelf/core/services/app_lifecycle_service.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import '../../../../helpers/test_helpers.dart';

Widget _reviewApp(
  Widget child, {
  List<Override> overrides = const [],
  double textScale = 1,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: reviewFontsEnabled ? reviewTheme() : null,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(key: reviewBoundaryKey, child: child!),
    ),
    home: child,
  ),
);

FileTreeNode _buildImportTree() {
  return FileTreeNode(
    name: 'root',
    uri: Uri.parse('content://provider/root'),
    relativePath: '',
    isDirectory: true,
    isExpanded: true,
    isCatalog: true,
    children: [
      FileTreeNode(
        name: 'keep.jpg',
        uri: Uri.parse('content://provider/root/keep.jpg'),
        relativePath: 'keep.jpg',
        isDirectory: false,
        includeInImport: true,

        isCatalog: false,
      ),
      FileTreeNode(
        name: 'retry.jpg',
        uri: Uri.parse('content://provider/root/retry.jpg'),
        relativePath: 'retry.jpg',
        isDirectory: false,
        includeInImport: false,

        isCatalog: false,
      ),
    ],
  );
}

FileTreeNode _buildMultiFileImportTree() {
  return FileTreeNode(
    name: 'selected-files',
    uri: Uri.parse('private-shelf://selected-files'),
    relativePath: '',
    isDirectory: true,
    children: [
      FileTreeNode(
        name: 'first.jpg',
        uri: Uri.parse('content://provider/first.jpg'),
        relativePath: 'first.jpg',
        isDirectory: false,
        includeInImport: true,
      ),
      FileTreeNode(
        name: 'second.jpg',
        uri: Uri.parse('content://provider/second.jpg'),
        relativePath: 'second.jpg',
        isDirectory: false,
        includeInImport: true,
      ),
    ],
  );
}

class _TestImportFlowCompletedNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(
      status: ImportFlowStatus.completed,
      rootNode: _buildImportTree(),
      importReport: const ImportExecutionReport(
        sessionId: 'test-session',
        pendingSourcePaths: ['retry.jpg'],
        totalItems: 2,
        processedItems: 1,
        failedItems: 1,
        failureThresholdCount: 5,
        failedEntries: [
          ImportFailureDetail(
            path: 'retry.jpg',
            displayName: 'retry.jpg',
            reason: '読み込みに失敗',
          ),
        ],
      ),
    );
  }
}

class _TestImportFlowBlockedNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() => ImportFlowState(
    status: ImportFlowStatus.error,
    importReport: const ImportExecutionReport(
      sessionId: 'blocked',
      totalItems: 2,
      processedItems: 0,
      failedItems: 1,
      failureThresholdCount: 5,
      pendingSourcePaths: ['uncertain.jpg'],
      retryBlocked: true,
    ),
  );
}

class _TestImportFlowConfirmingNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(
      status: ImportFlowStatus.confirming,
      rootNode: _buildImportTree(),
    );
  }
}

class _TestImportFlowImportingNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(status: ImportFlowStatus.importing);
  }
}

class _TestImportFlowScanningNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(status: ImportFlowStatus.scanning);
  }
}

class _TestMultiFileImportFlowConfirmingNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() => ImportFlowState(
    status: ImportFlowStatus.confirming,
    rootNode: _buildMultiFileImportTree(),
  );
}

class _ReviewFilesFlow extends ImportFlowNotifier {
  int executions = 0;
  final names = [
    for (var i = 1; i <= 7; i++)
      'QA_共通のとても長いファイル名_取り込み確認_別の末尾_$i.${i == 1
          ? 'mp3'
          : i == 7
          ? 'bin'
          : 'txt'}',
  ];
  @override
  ImportFlowState build() => ImportFlowState(
    status: ImportFlowStatus.confirming,
    rootNode: FileTreeNode(
      name: 'selected-files',
      uri: Uri.parse('private-shelf://selected-files'),
      relativePath: '',
      isDirectory: true,
      children: [
        for (var i = 0; i < names.length; i++)
          FileTreeNode(
            name: names[i],
            uri: Uri.file('/qa/${names[i]}'),
            relativePath: names[i],
            isDirectory: false,
            size: i == 6 ? null : 2048,
          ),
      ],
    ),
  );
  @override
  Future<void> restoreDraftSession() async {}
  @override
  Future<void> executeImport() async {
    executions++;
  }
}

class _TestSingleFileImportFlowConfirmingNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() => ImportFlowState(
    status: ImportFlowStatus.confirming,
    rootNode: FileTreeNode(
      name: 'selected-files',
      uri: Uri.parse('private-shelf://selected-files'),
      relativePath: '',
      isDirectory: true,
      children: [
        FileTreeNode(
          name: 'photo.jpg',
          uri: Uri.parse('content://provider/photo.jpg'),
          relativePath: 'photo.jpg',
          isDirectory: false,
          includeInImport: true,
          size: 2048,
        ),
      ],
    ),
  );
}

class _TestImportFlowCompletedWithSkippedNotifier extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(
      status: ImportFlowStatus.completed,
      rootNode: _buildImportTree(),
      importReport: const ImportExecutionReport(
        sessionId: 'test-session',
        pendingSourcePaths: ['retry.jpg'],
        totalItems: 4,
        processedItems: 2,
        failedItems: 1,
        failureThresholdCount: 5,
        failedEntries: [
          ImportFailureDetail(
            path: 'retry.jpg',
            displayName: 'retry.jpg',
            reason: '空き容量不足',
          ),
        ],
      ),
    );
  }
}

class _TestImportFlowCompletedWithReasonCodeNotifier
    extends ImportFlowNotifier {
  @override
  ImportFlowState build() {
    return ImportFlowState(
      status: ImportFlowStatus.completed,
      rootNode: _buildImportTree(),
      importReport: const ImportExecutionReport(
        sessionId: 'test-session',
        pendingSourcePaths: ['retry.jpg'],
        totalItems: 1,
        processedItems: 0,
        failedItems: 1,
        failureThresholdCount: 5,
        failedEntries: [
          ImportFailureDetail(
            path: 'retry.jpg',
            displayName: 'retry.jpg',
            reason: ImportFailureReasonCode.noSpace,
          ),
        ],
      ),
    );
  }
}

class _TestAppLifecycleBackgroundNotifier extends AppLifecycleNotifier {
  _TestAppLifecycleBackgroundNotifier() : super() {
    state = AppLifecycleStatus.background;
  }
}

void main() {
  setUpAll(loadReviewFonts);
  testWidgets('短時間のインポートでは中断警告を表示しない', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowImportingNotifier(),
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.text('処理中です。画面を閉じずにお待ちください。'), findsNothing);
    expect(find.text('インポート中はこの画面を閉じないでください。'), findsNothing);
    await tester.pump(const Duration(seconds: 1, milliseconds: 999));
    expect(find.text('インポート中はこの画面を閉じないでください。'), findsNothing);
  });

  testWidgets('インポートが長時間続く場合だけ中断警告を表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowImportingNotifier(),
          ),
        ],
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('インポート中はこの画面を閉じないでください。'), findsOneWidget);
  });

  testWidgets('スキャンが長時間続いてもインポート中断警告を表示しない', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowScanningNotifier(),
          ),
        ],
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('追加内容を確認中'), findsOneWidget);
    expect(find.text('そのままお待ちください'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('インポート中はこの画面を閉じないでください。'), findsNothing);
  });

  testWidgets('完了画面で失敗理由と再試行導線を表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowCompletedNotifier(),
          ),
        ],
      ),
    );
    await tester.pump();

    // AppBarに戻るボタンが表示されず、タイトルが「インポート完了」となっていること
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('スキャン結果'), findsNothing);

    expect(find.text('失敗した項目と理由'), findsOneWidget);
    expect(find.text('retry.jpg - 読み込みに失敗'), findsOneWidget);
    expect(find.text('保存されなかった項目を再試行'), findsOneWidget);
    expect(find.text('ライブラリへ戻る'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('失敗理由コードを英語表示へローカライズする', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        locale: const Locale('en'),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowCompletedWithReasonCodeNotifier(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('retry.jpg - Not enough storage space'), findsOneWidget);
  });

  testWidgets('再試行すると失敗項目だけ再選択された確認画面へ戻る', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowCompletedNotifier(),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('保存されなかった項目を再試行'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    final state = container.read(importFlowNotifierProvider);
    expect(state.status, ImportFlowStatus.confirming);
    expect(state.rootNode, isNotNull);
    final root = state.rootNode!;
    expect(root.children.first.includeInImport, isFalse);
    expect(root.children.last.includeInImport, isTrue);
  });

  testWidgets('確認画面で追加対象と実行ボタンを簡潔に表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('追加内容の確認'), findsOneWidget);
    expect(find.text('以下をひとつのカタログとして取り込みます'), findsOneWidget);
    expect(find.text('root'), findsOneWidget);
    expect(find.text('ファイル 1件'), findsOneWidget);
    expect(find.text('1項目'), findsNothing);
    expect(find.textContaining('約 '), findsNothing);
    expect(find.text('追加する'), findsOneWidget);
    expect(find.text('スキャン'), findsNothing);
    expect(find.text('選択内容を変更'), findsOneWidget);
    expect(
      find.textContaining('CharmShelf内にコピーします。', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('元のファイルは変更しません。', findRichText: true),
      findsOneWidget,
    );

    expect(find.byIcon(Icons.auto_stories), findsNothing);
    expect(find.bySemanticsLabel('retry.jpg'), findsNothing);
  });

  testWidgets('複数ファイル確認では件数を重複表示しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _reviewApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestMultiFileImportFlowConfirmingNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('選択したファイルを追加します'), findsOneWidget);
    expect(find.text('ファイル 2件'), findsOneWidget);
    expect(find.text('first.jpg'), findsOneWidget);
    expect(find.text('second.jpg'), findsOneWidget);
    await captureReview(tester, 'import-two-files');
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all selected names and metadata can be reviewed before importing at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final flow = _ReviewFilesFlow();
        await tester.pumpWidget(
          _reviewApp(
            const ImportSelectionScreen(),
            textScale: scale,
            overrides: [importFlowNotifierProvider.overrideWith(() => flow)],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(flow.names.first), findsOneWidget);
        expect(find.text('音声 · 2.0 KB'), findsOneWidget);
        expect(flow.executions, 0);
        await captureReview(tester, 'import-seven-files-${scale}x');
        final all = find.byKey(const ValueKey('import-review-all-files'));
        await tester.ensureVisible(all);
        await tester.tap(all);
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('import-selected-files-list'));
        expect(
          MediaQuery.textScalerOf(tester.element(list)).scale(16),
          16 * scale,
        );
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(
          find.text(flow.names.last),
          220,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text(flow.names.last).hitTestable(), findsOneWidget);
        final fullName = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText && widget.data == flow.names.last,
          ),
        );
        expect(fullName.maxLines, isNull);
        expect(find.textContaining('容量不明'), findsWidgets);
        expect(flow.executions, 0);
        await captureReview(tester, 'import-all-files-${scale}x');
        Navigator.of(tester.element(list)).pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('import-selected-files-list')),
          findsNothing,
        );
        expect(flow.executions, 0);
        await tester.tap(find.widgetWithText(FilledButton, '追加する'));
        await tester.pump();
        expect(flow.executions, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('単体確認は名前とサイズに絞り、コピー前の確認を保持する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            _TestSingleFileImportFlowConfirmingNotifier.new,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('ファイル 1件'), findsNothing);
    expect(find.text('追加する'), findsOneWidget);
    expect(
      find.textContaining('元のファイルは変更しません。', findRichText: true),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    expect(
      container.read(importFlowNotifierProvider).status,
      ImportFlowStatus.confirming,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('フォルダ取り込みの管理方法をファイル単位へ切り替えられる', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理方法'), findsNothing);
    expect(find.text('1つのカタログにまとめる'), findsOneWidget);
    await tester.tap(find.text('まとめ方を変更'));
    await tester.pump();
    expect(find.text('管理方法'), findsOneWidget);
    await tester.ensureVisible(find.text('ファイルごとに並べる'));
    await tester.tap(find.text('ファイルごとに並べる'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    expect(
      container.read(importFlowNotifierProvider).catalogMode,
      ImportCatalogMode.file,
    );
  });

  testWidgets('選択内容を変更すると詳細画面へ遷移する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('keep.jpg'), findsNothing);

    await tester.tap(find.text('選択内容を変更'));
    await tester.pumpAndSettle();

    expect(find.text('スキャン結果'), findsOneWidget);
    expect(find.text('keep.jpg'), findsOneWidget);
    expect(find.text('retry.jpg'), findsOneWidget);
    expect(find.text('取り込む'), findsOneWidget);
  });

  testWidgets('完了画面で追加、スキップ、失敗件数を表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowCompletedWithSkippedNotifier(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('追加: 2件'), findsOneWidget);
    expect(find.text('スキップ: 1件'), findsOneWidget);
    expect(find.text('失敗: 1件'), findsOneWidget);
  });

  testWidgets('保存済みの下書きセッションを起動時に復元する', (tester) async {
    setupMockSharedPreferences({
      'import_flow_draft_session_v1': jsonEncode({
        'version': 1,
        'status': 'confirming',
        'targetParentPath': 'library/drafts',
        'rootNode': _buildImportTree().toMap(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    });

    await tester.pumpWidget(createProviderApp(const ImportSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('追加内容の確認'), findsOneWidget);
    expect(find.text('keep.jpg'), findsNothing);

    await tester.tap(find.text('選択内容を変更'));
    await tester.pumpAndSettle();

    expect(find.text('keep.jpg'), findsOneWidget);
    expect(find.text('retry.jpg'), findsOneWidget);
  });

  testWidgets('保存状態が不明なエラーを追加0件と断定せず再試行を止める', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowBlockedNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('追加: 0件'), findsNothing);
    expect(find.text('保存されなかった項目を再試行'), findsNothing);
    expect(find.text('ライブラリへ戻る'), findsOneWidget);
  });

  testWidgets('取り込みの二重実行を拒否し実行前に中断マーカーを保存する', (tester) async {
    final dependency = Completer<AdvancedImportUseCase>();
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
          advancedImportUseCaseProvider.overrideWith(
            (ref) => dependency.future,
          ),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    final notifier = container.read(importFlowNotifierProvider.notifier);
    final first = notifier.executeImport();
    var duplicateFinished = false;
    final duplicate = notifier.executeImport().then(
      (_) => duplicateFinished = true,
    );
    await tester.pump();
    expect(duplicateFinished, isTrue);
    final prefs = await SharedPreferences.getInstance();
    final marker =
        jsonDecode(prefs.getString('import_flow_draft_session_v1')!)
            as Map<String, dynamic>;
    expect(marker['status'], 'importing');
    expect(
      container.read(importFlowNotifierProvider).status,
      ImportFlowStatus.importing,
    );
    dependency.completeError(StateError('dependency unavailable'));
    await tester.pump();
    await first;
    await duplicate;
  });

  testWidgets('実行中の下書きは確認画面へ戻して自動再実行せず保存状態確認を案内する', (tester) async {
    setupMockSharedPreferences({
      'import_flow_draft_session_v1': jsonEncode({
        'version': 3,
        'status': 'importing',
        'rootNode': _buildImportTree().toMap(),
      }),
    });
    await tester.pumpWidget(createProviderApp(const ImportSelectionScreen()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    final state = container.read(importFlowNotifierProvider);
    expect(state.status, ImportFlowStatus.error);
    expect(state.importReport!.retryBlocked, isTrue);
    expect(find.text('保存されなかった項目を再試行'), findsNothing);
    expect(find.text('ライブラリへ戻る'), findsOneWidget);
  });

  testWidgets('バックグラウンド時は処理継続に注意を促す', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
          appLifecycleProvider.overrideWith(
            (ref) => _TestAppLifecycleBackgroundNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('バックグラウンド'), findsOneWidget);
    expect(find.textContaining('処理が止まる可能性があります'), findsOneWidget);
  });

  testWidgets('小型画面と200%文字サイズでも確認画面の主要文言を維持する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: createProviderApp(
          const ImportSelectionScreen(),
          overrides: [
            importFlowNotifierProvider.overrideWith(
              () => _TestImportFlowConfirmingNotifier(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ファイル 1件'), findsOneWidget);
    expect(find.text('追加する'), findsOneWidget);
    expect(find.text('追加内容の確認'), findsOneWidget);
  });

  testWidgets('詳細設定画面で全選択・全解除およびメディアフィルターが機能する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ImportSelectionScreen(),
        overrides: [
          importFlowNotifierProvider.overrideWith(
            () => _TestImportFlowConfirmingNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 詳細画面へ遷移
    await tester.tap(find.text('選択内容を変更'));
    await tester.pumpAndSettle();

    // クイック操作バーが表示されていること
    expect(find.text('すべて選択'), findsOneWidget);
    expect(find.text('すべて解除'), findsOneWidget);
    expect(find.text('すべて'), findsOneWidget);
    expect(find.text('画像'), findsOneWidget);
    expect(find.text('動画'), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(3));
    final videoFilter = find.byKey(const ValueKey('import-filter-videos'));
    expect(videoFilter, findsOneWidget);
    expect(tester.getSize(videoFilter).height, greaterThanOrEqualTo(48));

    // 全解除をタップ
    await tester.tap(find.text('すべて解除'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportSelectionScreen)),
    );
    var state = container.read(importFlowNotifierProvider);
    expect(state.rootNode?.includeInImport, isFalse);
    expect(state.rootNode?.children.every((c) => !c.includeInImport), isTrue);
    expect(state.hasImportSelection, isFalse);
    expect(find.text('カタログにする項目が選択されていません'), findsOneWidget);
    final disabledImportButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '取り込む'),
    );
    expect(disabledImportButton.onPressed, isNull);
    await container.read(importFlowNotifierProvider.notifier).executeImport();
    expect(
      container.read(importFlowNotifierProvider).status,
      ImportFlowStatus.confirming,
    );

    // 全選択をタップ
    await tester.tap(find.text('すべて選択'));
    await tester.pumpAndSettle();

    state = container.read(importFlowNotifierProvider);
    expect(state.rootNode?.includeInImport, isTrue);
    expect(state.rootNode?.children.every((c) => c.includeInImport), isTrue);

    // 動画フィルターを選択（画像ファイルのみなのでファイルノードは表示されなくなる）
    await tester.tap(find.text('動画'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final filterSemantics = tester
        .getSemantics(
          find.descendant(of: videoFilter, matching: find.byType(ChoiceChip)),
        )
        .getSemanticsData();
    expect(filterSemantics.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(filterSemantics.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(find.text('keep.jpg'), findsNothing);
    expect(find.text('retry.jpg'), findsNothing);

    // すべてフィルターに戻す
    await tester.tap(find.text('すべて'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('keep.jpg'), findsOneWidget);
    expect(find.text('retry.jpg'), findsOneWidget);
  });
}
