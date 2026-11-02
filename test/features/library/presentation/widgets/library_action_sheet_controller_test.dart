import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import '../../../../shared/finders.dart' as shared_find;
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/shared/widgets/dialogs/modern_dialog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/application/use_cases/archive_media_item_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/remove_external_folder_reference_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/toggle_hidden_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/controllers/library_action_sheet_controller.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecurityRepository extends Mock implements SecurityRepository {}

class _MockToggleHiddenUseCase extends Mock implements ToggleHiddenUseCase {}

class _MockArchiveMediaItemUseCase extends Mock
    implements ArchiveMediaItemUseCase {}

class _EmptyCollection extends CollectionNotifier {
  @override
  Future<MediaCollection?> build(String path) async => null;
}

class _RecordingLibraryViewModel extends LibraryViewModel {
  int setAsFolderCoverCallCount = 0;

  @override
  FutureOr<List<MediaItem>> build() => [];

  @override
  Future<void> setAsFolderCover(MediaItem item) async {
    setAsFolderCoverCallCount++;
  }
}

class _RecordingExternalFolderList extends ExternalFolderList {
  _RecordingExternalFolderList(this.outcome);

  final RemoveExternalFolderReferenceOutcome outcome;
  int removeCallCount = 0;

  @override
  FutureOr<List<MediaCollection>> build() => [];

  @override
  Future<RemoveExternalFolderReferenceOutcome> removeFolder(
    MediaCollection folder,
  ) async {
    removeCallCount++;
    return outcome;
  }
}

class _ExternalFolderFilter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(
    parentPath: 'content://provider/root',
    sourceType: MediaSourceType.externalReference,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'tutorial.first_hide.completed': true,
      'tutorial.first_archive.completed': true,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('パスをコピーして結果を表示してもメニューを閉じない', (tester) async {
    await tester.pumpWidget(_testApp(action: _Action.copyPath));

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);
    expect(find.text('クリップボードにコピーしました'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('フォルダの表紙に設定して結果を表示してもメニューを閉じない', (tester) async {
    final viewModel = _RecordingLibraryViewModel();
    await tester.pumpWidget(
      _testApp(action: _Action.setAsFolderCover, viewModel: viewModel),
    );

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(viewModel.setAsFolderCoverCallCount, 1);
    expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);
    expect(find.text('カバー画像を設定しました'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('非表示にするとメニューを閉じる', (tester) async {
    final useCase = _MockToggleHiddenUseCase();
    final item = _actionItem();
    when(
      () => useCase.call(item: item, collection: null, isHidden: true),
    ).thenAnswer((_) async => Result.success(null));

    await tester.pumpWidget(
      _testApp(action: _Action.hide, item: item, toggleHiddenUseCase: useCase),
    );

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このまま隠す'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action-menu')), findsNothing);
    verify(
      () => useCase.call(item: item, collection: null, isHidden: true),
    ).called(1);
  });

  testWidgets('アーカイブするとメニューを閉じる', (tester) async {
    final useCase = _MockArchiveMediaItemUseCase();
    final item = _actionItem();
    when(
      () => useCase.call(item: item, collection: null, isArchived: true),
    ).thenAnswer((_) async => Result.success(null));

    await tester.pumpWidget(
      _testApp(
        action: _Action.archive,
        item: item,
        archiveMediaItemUseCase: useCase,
      ),
    );

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action-menu')), findsNothing);
    verify(
      () => useCase.call(item: item, collection: null, isArchived: true),
    ).called(1);
  });

  testWidgets('非表示解除とアーカイブ解除ではメニューを閉じない', (tester) async {
    final hiddenUseCase = _MockToggleHiddenUseCase();
    final archivedUseCase = _MockArchiveMediaItemUseCase();
    final hiddenItem = _actionItem()..isHidden = true;
    final archivedItem = _actionItem()..isArchived = true;
    when(
      () => hiddenUseCase.call(
        item: hiddenItem,
        collection: null,
        isHidden: false,
      ),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => archivedUseCase.call(
        item: archivedItem,
        collection: null,
        isArchived: false,
      ),
    ).thenAnswer((_) async => Result.success(null));

    await tester.pumpWidget(
      _testApp(
        action: _Action.unhide,
        item: hiddenItem,
        toggleHiddenUseCase: hiddenUseCase,
      ),
    );
    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _testApp(
        action: _Action.unarchive,
        item: archivedItem,
        archiveMediaItemUseCase: archivedUseCase,
      ),
    );
    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);
  });

  for (final outcome in ['既読', '未読', '読込失敗', '画面破棄']) {
    testWidgets('既読状態が遅れて届く場合もアーカイブ完了を正しく扱う: $outcome', (tester) async {
      final useCase = _MockArchiveMediaItemUseCase();
      final item = _actionItem();
      when(
        () => useCase.call(item: item, collection: null, isArchived: true),
      ).thenAnswer((_) async => Result.success(null));
      final prefs = await SharedPreferences.getInstance();
      if (outcome == '未読') {
        await prefs.setBool('tutorial.first_archive.completed', false);
      }
      final loaded = Completer<SharedPreferences>();
      await tester.pumpWidget(
        _testApp(
          action: _Action.archive,
          item: item,
          archiveMediaItemUseCase: useCase,
          preferences: loaded.future,
        ),
      );
      await tester.tap(find.text('メニューを開く'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('実行'));
      await tester.pumpAndSettle();
      verify(
        () => useCase.call(item: item, collection: null, isArchived: true),
      ).called(1);
      expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);
      expect(find.byType(ModernDialog), findsNothing);
      if (outcome == '画面破棄') await tester.pumpWidget(const SizedBox.shrink());
      if (outcome == '読込失敗') {
        loaded.completeError(StateError('preferences unavailable'));
      } else {
        loaded.complete(prefs);
      }
      await tester.pumpAndSettle();
      if (outcome == '未読') {
        expect(find.byType(ModernDialog), findsOneWidget);
        expect(find.byKey(const ValueKey('action-menu')), findsOneWidget);
        expect(prefs.getBool('tutorial.first_archive.completed'), isFalse);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ModernDialog)),
        )!;
        await tester.tap(shared_find.findAppText(l10n.tutorialSkip));
        await tester.pumpAndSettle();
        expect(find.byType(ModernDialog), findsNothing);
        expect(find.byKey(const ValueKey('action-menu')), findsNothing);
        expect(prefs.getBool('tutorial.first_archive.completed'), isTrue);
      } else {
        expect(find.byType(ModernDialog), findsNothing);
        expect(find.byKey(const ValueKey('action-menu')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ごみ箱への移動確認は対象と復元案内だけを分けて表示する', (tester) async {
    await tester.pumpWidget(_testApp(action: _Action.moveToTrash));

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    expect(find.text('ごみ箱へ移動'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('trash-dialog-target')), findsOneWidget);
    expect(find.text('image.jpg'), findsOneWidget);
    expect(find.text('ファイル'), findsOneWidget);
    expect(find.text('ごみ箱を空にするまでは復元できます。'), findsOneWidget);
    expect(find.textContaining('チャームやメモ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('外部フォルダ参照解除後は表示中のフォルダを抜けて成功を表示する', (tester) async {
    final folders = _RecordingExternalFolderList(
      const RemoveExternalFolderReferenceOutcome(
        permissionCleanupPending: false,
      ),
    );
    await tester.pumpWidget(_decatalogifyTestApp(folders));

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '参照のみ削除'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    expect(folders.removeCallCount, 1);
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.external)).parentPath,
      isNull,
    );
    expect(find.byKey(const ValueKey('action-menu')), findsNothing);
    expect(find.text('参照を削除しました'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('権限の後片付けが残った場合は正直な完了通知を表示する', (tester) async {
    final folders = _RecordingExternalFolderList(
      const RemoveExternalFolderReferenceOutcome(
        permissionCleanupPending: true,
      ),
    );
    await tester.pumpWidget(_decatalogifyTestApp(folders));

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '参照のみ削除'));
    await tester.pumpAndSettle();

    expect(find.text('参照を解除しました。端末側の後片付けは後で自動的に行います'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

enum _Action {
  copyPath,
  setAsFolderCover,
  moveToTrash,
  hide,
  unhide,
  archive,
  unarchive,
}

MediaItem _actionItem() {
  return MediaItem()
    ..id = 1
    ..path = 'folder/image.jpg'
    ..parentPath = 'folder';
}

Widget _testApp({
  required _Action action,
  _RecordingLibraryViewModel? viewModel,
  MediaItem? item,
  _MockToggleHiddenUseCase? toggleHiddenUseCase,
  _MockArchiveMediaItemUseCase? archiveMediaItemUseCase,
  Future<SharedPreferences>? preferences,
}) {
  final targetItem = item ?? _actionItem();
  final security = _MockSecurityRepository();
  when(security.hasPasscode).thenAnswer((_) async => Result.success(false));

  return ProviderScope(
    overrides: [
      securityRepositoryProvider.overrideWithValue(security),
      if (preferences != null)
        sharedPreferencesProvider.overrideWith((ref) => preferences),
      if (viewModel != null)
        libraryViewModelProvider.overrideWith(() => viewModel),
      parentCatalogProvider(
        parentPath: targetItem.parentPath,
      ).overrideWith((ref) async => null),
      collectionNotifierProvider(
        targetItem.path,
      ).overrideWith(_EmptyCollection.new),
      if (toggleHiddenUseCase != null)
        toggleHiddenUseCaseProvider.overrideWith(
          (ref) async => toggleHiddenUseCase,
        ),
      if (archiveMediaItemUseCase != null)
        archiveMediaItemUseCaseProvider.overrideWith(
          (ref) async => archiveMediaItemUseCase,
        ),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => Consumer(
                  builder: (context, ref, _) {
                    final controller = LibraryActionSheetController(ref);
                    return SizedBox(
                      key: const ValueKey('action-menu'),
                      height: 160,
                      child: Center(
                        child: FilledButton(
                          onPressed: () {
                            switch (action) {
                              case _Action.copyPath:
                                controller.copyPath(context, targetItem.path);
                              case _Action.setAsFolderCover:
                                controller.setAsFolderCover(
                                  context,
                                  targetItem,
                                );
                              case _Action.moveToTrash:
                                controller.deleteItem(context, targetItem);
                              case _Action.hide:
                              case _Action.unhide:
                                controller.toggleHidden(
                                  context,
                                  item: targetItem,
                                );
                              case _Action.archive:
                              case _Action.unarchive:
                                controller.toggleArchive(
                                  context,
                                  item: targetItem,
                                );
                            }
                          },
                          child: const Text('実行'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              child: const Text('メニューを開く'),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _decatalogifyTestApp(_RecordingExternalFolderList folders) {
  final collection = MediaCollection()
    ..id = 10
    ..path = 'content://provider/root'
    ..title = 'root'
    ..type = CollectionType.externalFolder;

  return ProviderScope(
    overrides: [
      externalFolderListProvider.overrideWith(() => folders),
      mediaFilterNotifierProvider(
        AppMode.external,
      ).overrideWith(_ExternalFolderFilter.new),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(mediaFilterNotifierProvider(AppMode.external));
          return Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => Consumer(
                      builder: (context, ref, _) {
                        final controller = LibraryActionSheetController(ref);
                        return SizedBox(
                          key: const ValueKey('action-menu'),
                          height: 160,
                          child: Center(
                            child: FilledButton(
                              onPressed: () =>
                                  controller.decatalogify(context, collection),
                              child: const Text('実行'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  child: const Text('メニューを開く'),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
