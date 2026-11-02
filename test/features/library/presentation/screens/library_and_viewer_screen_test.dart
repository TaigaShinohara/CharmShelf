import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/feedback_service.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/selected_document.dart';
import 'package:private_shelf/features/library/presentation/helpers/system_file_picker.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_summary_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/library_fab_visibility_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/catalog_resume_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/internal_library_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/breadcrumb_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_header.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_app_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_grid.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_item_card.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import 'package:private_shelf/features/library/presentation/widgets/resume_banner.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_selection_indicator.dart';
import 'package:private_shelf/features/library/presentation/widgets/filter_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/unsupported_file_view.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/shared/widgets/dialogs/paged_dialog.dart';
import 'package:private_shelf/shared/widgets/states/error_state_widget.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../shared/finders.dart' as shared_find;

class _TestMediaFilterNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return MediaFilter(
      rootOnly: true,
      onlyCatalogs: true,
      sourceType: mode == AppMode.internal
          ? MediaSourceType.localCopy
          : MediaSourceType.externalReference,
    );
  }
}

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockFeedbackService extends Mock implements FeedbackService {}

class _CancelledSystemPicker extends SystemFilePicker {
  final calls = <String>[];
  @override
  Future<SelectedDocument?> openFile() async {
    calls.add('open');
    return null;
  }

  @override
  Future<List<SelectedDocument>?> pickFiles() async {
    calls.add('files');
    return null;
  }

  @override
  Future<PickedFolder?> pickFolder() async {
    calls.add('folder');
    return null;
  }
}

class _TestMediaFilterAllNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return MediaFilter(
      rootOnly: true,
      onlyCatalogs: false,
      sourceType: mode == AppMode.internal
          ? MediaSourceType.localCopy
          : MediaSourceType.externalReference,
    );
  }
}

class _TestMediaFilterGridNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return MediaFilter(
      rootOnly: true,
      onlyCatalogs: false,
      sourceType: mode == AppMode.internal
          ? MediaSourceType.localCopy
          : MediaSourceType.externalReference,
    );
  }
}

class _TestMediaFilterSearchNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return const MediaFilter(
      rootOnly: true,
      searchQuery: 'missing',
      sourceType: MediaSourceType.localCopy,
    );
  }
}

class _SeededMediaFilterNotifier extends MediaFilterNotifier {
  _SeededMediaFilterNotifier(this.initialFilter);

  final MediaFilter initialFilter;

  @override
  MediaFilter build(AppMode mode) => initialFilter;
}

class _RecoveryLibraryViewModel extends LibraryViewModel {
  _RecoveryLibraryViewModel({required this.hasMatch});

  final bool Function(MediaFilter) hasMatch;

  @override
  FutureOr<List<MediaItem>> build() {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.internal));
    return hasMatch(filter) ? _buildManyMediaItems(1) : <MediaItem>[];
  }
}

class _TestMediaFilterConditionsNotifier extends MediaFilterNotifier {
  _TestMediaFilterConditionsNotifier({this.searching = true});
  final bool searching;

  @override
  MediaFilter build(AppMode mode) {
    return MediaFilter(
      rootOnly: true,
      searchQuery: searching ? 'sample' : null,
      searchTarget: searching ? SearchTarget.catalogsOnly : null,
      onlyCatalogs: true,
      tiers: [1, 2],
      hasTags: false,
      isFavorite: true,
      mediaTypes: [MediaType.file],
      sortOrder: SortOrder.nameAsc,
      sourceType: MediaSourceType.localCopy,
    );
  }
}

class _TestMediaFilterFolderPathNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return const MediaFilter(
      rootOnly: false,
      parentPath: 'subfolder',
      onlyCatalogs: false,
      sourceType: MediaSourceType.localCopy,
    );
  }
}

class _DelayedSearchLibrary extends LibraryViewModel {
  _DelayedSearchLibrary(this.result);
  final Future<List<MediaItem>> result;
  @override
  FutureOr<List<MediaItem>> build() {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.internal));
    return (filter.searchQuery?.isNotEmpty ?? false) ? result : <MediaItem>[];
  }
}

class _TestLibraryViewModelSuccess extends LibraryViewModel {
  @override
  FutureOr<List<MediaItem>> build() => <MediaItem>[];
}

class _TestLibraryViewModelWithItems extends LibraryViewModel {
  _TestLibraryViewModelWithItems(this.items);

  final List<MediaItem> items;

  @override
  FutureOr<List<MediaItem>> build() => items;
}

class _TestLibrarySelectionPreselectedNotifier
    extends LibrarySelectionNotifier {
  _TestLibrarySelectionPreselectedNotifier(this.initialSelectedIds);

  final Set<int> initialSelectedIds;

  @override
  LibrarySelectionState build() {
    return LibrarySelectionState(
      isSelectionMode: initialSelectedIds.isNotEmpty,
      selectedIds: initialSelectedIds,
    );
  }
}

class _TestLibraryViewModelLoading extends LibraryViewModel {
  @override
  FutureOr<List<MediaItem>> build() => Completer<List<MediaItem>>().future;
}

class _TestExternalFolderItemsLoading extends ExternalFolderItems {
  @override
  FutureOr<List<MediaItem>> build(String? folderPath) =>
      Completer<List<MediaItem>>().future;
}

class _TestExternalFolderItemsWithItems extends ExternalFolderItems {
  _TestExternalFolderItemsWithItems(this.items);

  final List<MediaItem> items;

  @override
  FutureOr<List<MediaItem>> build(String? folderPath) => items;
}

class _TestCollectionNotifier extends CollectionNotifier {
  _TestCollectionNotifier(this.collection);

  final MediaCollection collection;

  @override
  Future<MediaCollection?> build(String path) async => collection;
}

List<MediaItem> _buildManyMediaItems(int count) {
  return List<MediaItem>.generate(count, (index) {
    return MediaItem()
      ..id = index + 1
      ..path = 'library/item_$index.jpg'
      ..originalPath = '/tmp/item_$index.jpg'
      ..sourceType = MediaSourceType.localCopy
      ..type = MediaType.file
      ..parentPath = null;
  });
}

void main() {
  setUp(() {
    setupMockSharedPreferences();
  });

  group('InternalLibraryScreen', () {
    testWidgets('AndroidのAppBarに端末入口を出さず追加メニューから取り込める', (tester) async {
      final picker = _CancelledSystemPicker();
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            systemFilePickerIsAndroidProvider.overrideWithValue(true),
            systemFilePickerProvider.overrideWithValue(picker),
            hapticsEnabledProvider.overrideWith((ref) => false),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(_TestMediaFilterAllNotifier.new),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems(_buildManyMediaItems(2)),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('端末のファイル'), findsNothing);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(shared_find.findAppText('ファイルを取り込む'), findsOneWidget);
      expect(shared_find.findAppText('フォルダを取り込む'), findsOneWidget);
      expect(
        tester.getTopLeft(shared_find.findAppText('フォルダを取り込む')).dy,
        lessThan(tester.getTopLeft(shared_find.findAppText('ファイルを取り込む')).dy),
      );
      expect(shared_find.findAppText('ファイルを開く'), findsNothing);
      await tester.tap(shared_find.findAppText('フォルダを取り込む'));
      await tester.pumpAndSettle();
      expect(picker.calls, ['folder']);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(shared_find.findAppText('ファイルを取り込む'));
      await tester.pumpAndSettle();
      expect(picker.calls, ['folder', 'files']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Androidの空の棚にもファイルとフォルダの直接選択がある', (tester) async {
      final picker = _CancelledSystemPicker();
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            systemFilePickerIsAndroidProvider.overrideWithValue(true),
            systemFilePickerProvider.overrideWithValue(picker),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(_TestMediaFilterAllNotifier.new),
            libraryViewModelProvider.overrideWith(
              _TestLibraryViewModelSuccess.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty-library-add')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('empty-library-add-folder')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('empty-library-add-folder')),
      );
      await tester.tap(find.byKey(const ValueKey('empty-library-add-folder')));
      await tester.pumpAndSettle();
      expect(picker.calls, ['folder']);
      expect(find.byType(InternalLibraryScreen), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('empty-library-add-folder')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('empty-library-add'))).dy,
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('empty-library-add')),
      );
      await tester.tap(find.byKey(const ValueKey('empty-library-add')));
      await tester.pumpAndSettle();
      expect(picker.calls, ['folder', 'files']);
      expect(find.byType(InternalLibraryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('スクロール連動の追加ボタン切替は一覧を再構築しない', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(_TestMediaFilterAllNotifier.new),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems(_buildManyMediaItems(40)),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final screen = tester.element(find.byType(InternalLibraryScreen));
      final container = ProviderScope.containerOf(screen);
      final list = tester.widget<MediaListView>(find.byType(MediaListView));
      final fab = container.read(libraryFabVisibilityProvider.notifier);
      fab.hide();
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        tester.widget<MediaListView>(find.byType(MediaListView)),
        same(list),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        tester.widget<MediaListView>(find.byType(MediaListView)),
        same(list),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('所属カタログの3点メニューにも通常カタログと同じファイル操作を表示する', (tester) async {
      final collection = MediaCollection()
        ..path = 'subfolder'
        ..title = '所属カタログ'
        ..isCatalog = true;
      final item = MediaItem()
        ..id = 10
        ..path = 'subfolder'
        ..type = MediaType.folder
        ..sourceType = MediaSourceType.localCopy;
      final repository = _MockMediaRepository();
      final feedbackService = _MockFeedbackService();
      when(
        () => repository.getByPath('subfolder'),
      ).thenAnswer((_) async => Result.success(item));
      when(() => feedbackService.lightImpact()).thenAnswer((_) async {});

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterFolderPathNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
            collectionNotifierProvider(
              'subfolder',
            ).overrideWith(() => _TestCollectionNotifier(collection)),
            folderSummaryProvider(
              'subfolder',
            ).overrideWith((ref) async => const FolderSummary()),
            mediaRepositoryProvider.overrideWith((ref) async => repository),
            feedbackServiceProvider.overrideWith((ref) => feedbackService),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final header = find.byType(CollectionHeader);
      await tester.tap(
        find.descendant(of: header, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pumpAndSettle();

      verify(() => repository.getByPath('subfolder')).called(1);
      final actionSheet = tester.widget<CollectionActionSheet>(
        find.byType(CollectionActionSheet),
      );
      expect(actionSheet.item, same(item));
      expect(find.text('カタログの中身を表示'), findsNothing);
      expect(find.text('選択'), findsOneWidget);
      expect(find.text('ファイル名を変更'), findsOneWidget);
      expect(find.text('移動'), findsOneWidget);
      expect(find.text('カタログの中に複製'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('移動')).dy,
        lessThan(tester.getTopLeft(find.text('カタログの中に複製')).dy),
      );
      expect(find.text('情報をコピー'), findsOneWidget);
      expect(find.text('アプリ外へ保存'), findsOneWidget);
      expect(find.text('ごみ箱へ移動'), findsOneWidget);

      // Path copying now lives in the copy options sheet. Verify the actual
      // destination action, not just the presence of its parent entry.
      await tester.ensureVisible(find.text('情報をコピー'));
      await tester.tap(find.text('情報をコピー'));
      await tester.pumpAndSettle();
      expect(shared_find.findAppText('パス'), findsOneWidget);
    });

    testWidgets('文字サイズ200%でもカタログ情報と再開UIが一覧と一緒にスクロールする', (tester) async {
      final collection = MediaCollection()
        ..path = 'subfolder'
        ..title = '長い名前でも一覧に重ならない所属カタログ'
        ..isCatalog = true
        ..lastViewedItemId = 42;
      final resumeItem = MediaItem()
        ..id = 42
        ..path = 'subfolder/resume.jpg'
        ..parentPath = 'subfolder';

      await tester.pumpWidget(
        createProviderApp(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: InternalLibraryScreen(),
          ),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterFolderPathNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems(_buildManyMediaItems(40)),
            ),
            collectionNotifierProvider(
              'subfolder',
            ).overrideWith(() => _TestCollectionNotifier(collection)),
            catalogResumeTargetProvider((
              collectionId: collection.id,
              collectionPath: collection.path,
              itemId: 42,
            )).overrideWith(
              (ref) => Stream.value(CatalogResumeTarget(item: resumeItem)),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final header = find.byType(CollectionHeader);
      final resume = find.byType(ResumeBanner);
      final contents = find.byType(RefreshIndicator);
      expect(header, findsOneWidget);
      expect(resume, findsOneWidget);
      expect(
        find.ancestor(of: header, matching: find.byType(LibraryAppBar)),
        findsNothing,
      );
      expect(
        tester.getBottomLeft(header).dy,
        lessThanOrEqualTo(tester.getTopLeft(resume).dy),
      );
      expect(find.ancestor(of: header, matching: contents), findsOneWidget);
      expect(find.ancestor(of: resume, matching: contents), findsOneWidget);

      await tester.drag(contents, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(header.hitTestable(), findsNothing);
      expect(resume.hitTestable(), findsNothing);
    });

    testWidgets('初回の空の棚ではファイル追加がそのまま始まり、フォルダ作成も残る', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(shared_find.findAppText('ファイルやフォルダを追加しましょう'), findsOneWidget);
      expect(find.text('追加'), findsNothing);
      expect(find.text('対応形式を見る'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const ValueKey('empty-library-add')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'ファイルを取り込む'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'フォルダを取り込む'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '新規フォルダ作成'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('empty-library-add')));
      await tester.pump();
      expect(find.text('カタログにする'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('empty-library-new-folder')),
      );
      await tester.tap(find.byKey(const ValueKey('empty-library-new-folder')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('対応形式を見る'));
      await tester.tap(find.text('対応形式を見る'));
      await tester.pumpAndSettle();

      expect(find.byType(PagedDialog), findsOneWidget);
      expect(find.textContaining('対応形式'), findsOneWidget);
      expect(find.textContaining('JPG, PNG, GIF'), findsOneWidget);
      final scrollbar = tester.widget<Scrollbar>(
        find
            .descendant(
              of: find.byType(PagedDialog),
              matching: find.byType(Scrollbar),
            )
            .first,
      );
      expect(scrollbar.thumbVisibility, isTrue);
      expect(scrollbar.trackVisibility, isTrue);
    });

    testWidgets('対応形式は幅360dp・文字サイズ200%でもスクロール案内と全ページ操作を保つ', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createProviderApp(
          const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: InternalLibraryScreen(),
          ),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('対応形式を見る'));
      await tester.tap(find.text('対応形式を見る'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ScrollableDialogPage), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(PagedDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
      expect(find.byType(ScrollableDialogPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('検索0件では条件解除を提示し初回空状態へ戻れる', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterSearchNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-clear-filters')),
        findsNothing,
      );

      await tester.tap(find.text('検索を解除'));
      await tester.pumpAndSettle();

      expect(find.text('追加'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const ValueKey('empty-library-add')), findsOneWidget);
    });

    for (final recovery in ['scope', 'target', 'filters']) {
      testWidgets('0件の$recovery解除は検索語と他の状態を保ち結果を更新する', (tester) async {
        final initial = MediaFilter(
          parentPath: 'subfolder',
          rootOnly: false,
          searchQuery: 'missing',
          searchWithinParent: true,
          searchTarget: recovery == 'scope'
              ? SearchTarget.filesIncluded
              : SearchTarget.catalogsOnly,
          onlyCatalogs: true,
          isFavorite: true,
          hasTags: false,
          tiers: const [1],
          sortOrder: SortOrder.nameAsc,
          sourceType: MediaSourceType.localCopy,
        );
        final expected = switch (recovery) {
          'scope' => initial.copyWith(searchWithinParent: false),
          'target' => initial.copyWith(
            searchTarget: SearchTarget.filesIncluded,
          ),
          _ => initial.copyWith(isFavorite: null, hasTags: null, tiers: null),
        };
        final actionKey = switch (recovery) {
          'scope' => 'discovery-search-entire-library',
          'target' => 'discovery-include-files',
          _ => 'discovery-clear-filters',
        };
        await tester.pumpWidget(
          createProviderApp(
            const InternalLibraryScreen(),
            overrides: [
              mediaFilterNotifierProvider(
                AppMode.internal,
              ).overrideWith(() => _SeededMediaFilterNotifier(initial)),
              libraryViewModelProvider.overrideWith(
                () => _RecoveryLibraryViewModel(
                  hasMatch: (filter) => filter == expected,
                ),
              ),
              appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);

        final action = find.byKey(ValueKey(actionKey));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(InternalLibraryScreen)),
        );
        expect(
          container.read(mediaFilterNotifierProvider(AppMode.internal)),
          expected,
        );
        expect(find.text('条件に一致するアイテムがありません'), findsNothing);
        expect(find.byType(MediaListTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final onlyCatalogs in [false, true]) {
      testWidgets('語だけ解除はカタログ表示$onlyCatalogsと位置を保ち古い入力を再検索しない', (tester) async {
        final initial = MediaFilter(
          parentPath: 'subfolder',
          rootOnly: false,
          onlyCatalogs: onlyCatalogs,
          sortOrder: SortOrder.nameAsc,
          sourceType: MediaSourceType.localCopy,
        );
        await tester.pumpWidget(
          createProviderApp(
            const InternalLibraryScreen(),
            overrides: [
              mediaFilterNotifierProvider(
                AppMode.internal,
              ).overrideWith(() => _SeededMediaFilterNotifier(initial)),
              libraryViewModelProvider.overrideWith(
                _TestLibraryViewModelSuccess.new,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('ライブラリを検索'));
        await tester.pump();
        final field = find.byType(TextField);
        await tester.enterText(field, 'missing');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('検索を解除'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('discovery-clear-filters')),
          findsNothing,
        );

        final action = find.byKey(const ValueKey('discovery-clear-search'));
        await tester.ensureVisible(action);
        await tester.enterText(field, 'stale pending input');
        await tester.pump();
        // Progress appears after 120ms; clear before the 180ms search commit.
        await tester.pump(const Duration(milliseconds: 130));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(action);
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.pump(const Duration(milliseconds: 500));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(InternalLibraryScreen)),
        );
        expect(
          container.read(mediaFilterNotifierProvider(AppMode.internal)),
          initial,
        );
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('語なしのカタログ0件ではファイル表示に広げ初回追加と区別する', (tester) async {
      const initial = MediaFilter(
        rootOnly: true,
        onlyCatalogs: true,
        searchTarget: SearchTarget.catalogsOnly,
        searchWithinParent: true,
        sourceType: MediaSourceType.localCopy,
      );
      final expected = initial.copyWith(onlyCatalogs: false);
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _SeededMediaFilterNotifier(initial)),
            libraryViewModelProvider.overrideWith(
              () => _RecoveryLibraryViewModel(
                hasMatch: (filter) => !filter.onlyCatalogs,
              ),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);
      expect(find.byKey(const ValueKey('empty-library-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('discovery-search-entire-library')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('discovery-clear-search')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('discovery-clear-filters')),
        findsNothing,
      );
      final action = find.byKey(const ValueKey('discovery-include-files'));
      expect(
        find.descendant(of: action, matching: find.text('ファイルも表示')),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container.read(mediaFilterNotifierProvider(AppMode.internal)),
        expected,
      );
      expect(find.byType(MediaListTile), findsOneWidget);
      expect(find.text('条件に一致するアイテムがありません'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('語なしの非表示条件0件では絞り込みを外せて初回追加と区別する', (tester) async {
      const initial = MediaFilter(
        rootOnly: true,
        isHidden: true,
        sourceType: MediaSourceType.localCopy,
      );
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _SeededMediaFilterNotifier(initial)),
            libraryViewModelProvider.overrideWith(
              _TestLibraryViewModelSuccess.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);
      expect(find.byKey(const ValueKey('empty-library-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('discovery-clear-search')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('discovery-include-files')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('discovery-clear-filters')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container.read(mediaFilterNotifierProvider(AppMode.internal)),
        initial.copyWith(isHidden: false),
      );
      expect(find.byKey(const ValueKey('empty-library-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('範囲を広げた後の読み込み失敗は語と条件を保持して再試行する', (tester) async {
      const initial = MediaFilter(
        parentPath: 'subfolder',
        rootOnly: false,
        searchQuery: 'missing',
        searchWithinParent: true,
        onlyCatalogs: true,
        isFavorite: true,
        sortOrder: SortOrder.nameAsc,
        sourceType: MediaSourceType.localCopy,
      );
      var attempts = 0;
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            hapticsEnabledProvider.overrideWith((ref) => false),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _SeededMediaFilterNotifier(initial)),
            libraryViewModelProvider.overrideWith(
              () => _RecoveryLibraryViewModel(
                hasMatch: (filter) {
                  if (filter.searchWithinParent) return false;
                  if (++attempts == 1) throw StateError('test read failed');
                  return true;
                },
              ),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('discovery-search-entire-library')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ErrorStateWidget), findsOneWidget);
      expect(find.text('条件に一致するアイテムがありません'), findsNothing);
      expect(find.byKey(const ValueKey('empty-library-add')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      final expected = initial.copyWith(searchWithinParent: false);
      expect(
        container.read(mediaFilterNotifierProvider(AppMode.internal)),
        expected,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(ErrorStateWidget),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        container.read(mediaFilterNotifierProvider(AppMode.internal)),
        expected,
      );
      expect(find.byType(ErrorStateWidget), findsNothing);
      expect(find.byType(MediaListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ロード状態を直接検証できる', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelLoading(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('常用操作を固定表示し管理操作をその他メニューへ分離する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byTooltip('ライブラリを検索'), findsOneWidget);
      expect(find.byTooltip('設定'), findsNothing);
      expect(find.byTooltip('並べ替え設定'), findsNothing);
      expect(find.byTooltip('グリッド表示'), findsNothing);
      expect(find.byTooltip('フィルター'), findsNothing);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.ancestor(
                of: find.byTooltip('管理とその他の操作'),
                matching: find.byType(PopupMenuButton<String>),
              ),
            )
            .useRootNavigator,
        isTrue,
      );

      await tester.tap(find.byTooltip('管理とその他の操作'));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(
              find
                  .byWidgetPredicate(
                    (widget) => widget is PopupMenuItem<String>,
                  )
                  .first,
            )
            .width,
        greaterThan(280),
      );
      expect(find.text('フィルター'), findsOneWidget);
      expect(find.text('グリッド表示'), findsOneWidget);
      expect(find.text('コンパクト表示'), findsOneWidget);
      expect(find.text('オフ'), findsNothing);
      expect(find.text('詳細情報も表示中'), findsOneWidget);
      expect(find.text('カタログのみ表示'), findsOneWidget);
      expect(find.text('すべての項目を表示中'), findsOneWidget);
      expect(find.text('チャーム管理'), findsOneWidget);
      expect(find.text('シークレットモードをオン'), findsOneWidget);
      expect(find.text('アーカイブ表示'), findsOneWidget);
      expect(find.text('ごみ箱'), findsOneWidget);
      expect(find.text('フォルダを手動同期'), findsNothing);
      expect(find.text('並べ替え設定'), findsOneWidget);
    });

    testWidgets('カタログタブ選択時でもルートでは戻るボタンを表示せずCharmShelfタイトルを維持する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      // カタログ選択時でもルート画面では「CharmShelf」が表示され、戻るボタンはない
      expect(find.text('CharmShelf'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('すべてのカタログを表示'), findsNothing);
    });

    testWidgets('外側Navigatorに戻り先があってもライブラリルートへ暗黙の戻るボタンを出さない', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const _PushInternalLibraryHarness(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CharmShelf'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('フォルダ内ではパンくずリストを表示する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterFolderPathNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      // パンくずリストが表示されていること
      expect(find.byType(BreadcrumbBar), findsOneWidget);
    });

    testWidgets('検索開始時に検索バーが表示される', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('検索語を入力してください'), findsOneWidget);
    });

    testWidgets('検索中にフィルターを開くとキーボードを閉じて内容領域を確保する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();
      await tester.showKeyboard(find.byType(TextField));
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byTooltip('フィルター'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(FilterSheet), findsOneWidget);
    });

    testWidgets('適用中の検索・範囲・並び順・絞り込みをすべて可視化する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterConditionsNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('検索: sample'), findsOneWidget);
      expect(find.text('カタログの情報だけを検索'), findsOneWidget);
      expect(find.text('名前順 (昇順)'), findsOneWidget);
      expect(find.textContaining('ティア:'), findsOneWidget);
      expect(find.text('お気に入りのみ表示'), findsOneWidget);
      expect(find.text('種類: ファイル'), findsOneWidget);
      expect(find.text('チャームなし'), findsOneWidget);
      expect(find.text('条件をすべて解除'), findsOneWidget);
    });

    testWidgets('検索開始後も取得が完了するまで進捗表示を維持する', (tester) async {
      final pending = Completer<List<MediaItem>>();
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _DelayedSearchLibrary(pending.future),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'sample');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete([]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('日本語入力の変換中は検索せず確定後にdebounce更新する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();

      final field = find.byType(TextField);
      await tester.tap(field);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'に',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(tester.element(field));
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        isNull,
      );

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'に',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        'に',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('検索欄のカーソル移動では検索を再実行しない', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();

      final field = find.byType(TextField);
      await tester.enterText(field, '風景');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '風景',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('キーボードの検索操作でdebounceを待たずに検索を確定する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();

      final field = find.byType(TextField);
      final keyedField = find.byKey(const ValueKey('library-search-field'));
      expect(keyedField, findsOneWidget);
      final fieldRect = tester.getRect(keyedField);
      expect(fieldRect.left, greaterThanOrEqualTo(0));
      expect(
        fieldRect.right,
        lessThanOrEqualTo(tester.view.physicalSize.width),
      );
      expect(fieldRect.height, greaterThanOrEqualTo(48));
      await tester.enterText(field, '風景');
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(field));
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        isNull,
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        '風景',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('検索を閉じると検索語を破棄して通常操作へ戻る', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'temporary');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('検索を閉じる'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        isNull,
      );
      expect(find.byTooltip('ライブラリを検索'), findsOneWidget);
    });

    testWidgets('AppBarのばつボタンは待ち時間なしで検索条件を解除する', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'temporary');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        'temporary',
      );

      await tester.tap(find.byTooltip('消去'));
      await tester.pump();

      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        isNull,
      );
    });

    testWidgets('条件をすべて解除すると検索語を含む条件が一括で消える', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterConditionsNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('条件をすべて解除'));
      await tester.tap(find.text('条件をすべて解除'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      final filter = container.read(
        mediaFilterNotifierProvider(AppMode.internal),
      );
      expect(filter.searchQuery, isNull);
      expect(filter.tiers, isNull);
      expect(filter.hasTags, isNull);
      expect(filter.isFavorite, isNull);
      expect(filter.mediaTypes, isNull);
      expect(filter.onlyCatalogs, isFalse);
      expect(filter.searchTarget, isNull);
    });

    testWidgets('通常表示の棚のみ条件は個別のばつボタンで解除できる', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(AppMode.internal).overrideWith(
              () => _TestMediaFilterConditionsNotifier(searching: false),
            ),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();

      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'カタログのみ表示'),
      );
      chip.onDeleted!();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .onlyCatalogs,
        isFalse,
      );
    });

    testWidgets('検索中の棚情報限定は表示設定を変えず検索語を保持して解除できる', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterConditionsNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelSuccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.widgetWithText(InputChip, 'カタログのみ表示'), findsNothing);
      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'カタログの情報だけを検索'),
      );
      chip.onDeleted!();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      final filter = container.read(
        mediaFilterNotifierProvider(AppMode.internal),
      );
      expect(filter.effectiveSearchTarget, SearchTarget.filesIncluded);
      expect(filter.searchQuery, 'sample');
      expect(filter.onlyCatalogs, isTrue);
      expect(find.widgetWithText(InputChip, 'カタログの情報だけを検索'), findsNothing);
    });

    testWidgets('1万件相当の一覧でも表示は仮想化され入力の進行状態が見える', (tester) async {
      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems(_buildManyMediaItems(10000)),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(MediaListTile).evaluate().length, lessThan(25));

      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'item');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        'item',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('フィルタ適用時に表示モードが画面に反映される', (tester) async {
      final item = MediaItem()
        ..id = 11
        ..path = 'library/toggle_target.jpg'
        ..originalPath = '/tmp/toggle_target.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            globalViewModeProvider.overrideWith((ref) => ViewMode.grid),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterGridNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MediaGrid), findsOneWidget);
      expect(find.byType(MediaListView), findsNothing);
      final grid = tester.widget<ListView>(find.byType(ListView).first);
      final gridPadding = grid.padding! as EdgeInsets;
      expect(gridPadding.top, 12);
      expect(gridPadding.bottom, greaterThanOrEqualTo(96));
    });

    testWidgets('選択件数と操作をAppBarへ表示し下部バーを出さない', (tester) async {
      final item = MediaItem()
        ..id = 21
        ..path = 'library/selection_target.jpg'
        ..originalPath = '/tmp/selection_target.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            appModeProvider.overrideWith((ref) => AppMode.internal),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _TestLibrarySelectionPreselectedNotifier({item.id}),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1件選択中'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      final scaffold = tester.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(InternalLibraryScreen),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(scaffold.bottomNavigationBar, isNull);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.text('1件選択中'), findsNothing);
    });

    testWidgets('検索中の選択件数が更新され戻ると検索条件を保持する', (tester) async {
      final item = MediaItem()
        ..id = 21
        ..path = 'library/selection_target.jpg'
        ..originalPath = '/tmp/selection_target.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            appModeProvider.overrideWith((ref) => AppMode.internal),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _TestLibrarySelectionPreselectedNotifier({}),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('ライブラリを検索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'selection');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      final selection = container.read(
        librarySelectionNotifierProvider.notifier,
      );
      selection.toggleSelection(item.id);
      await tester.pumpAndSettle();
      expect(find.text('1件選択中'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      selection.deselectAll();
      await tester.pumpAndSettle();
      expect(find.text('0件選択中'), findsOneWidget);
      selection.selectAll([item.id]);
      await tester.pumpAndSettle();
      expect(find.text('1件選択中'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        container.read(librarySelectionNotifierProvider).isSelectionMode,
        isFalse,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('selection'), findsOneWidget);
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .searchQuery,
        'selection',
      );
    });

    testWidgets('グリッドのコンテンツ長押しでメニューではなく選択状態になる', (tester) async {
      final item = MediaItem()
        ..id = 22
        ..path = 'library/grid_long_press.jpg'
        ..originalPath = '/tmp/grid_long_press.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            appModeProvider.overrideWith((ref) => AppMode.internal),
            globalViewModeProvider.overrideWith((ref) => ViewMode.grid),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterGridNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(MediaItemCard));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(container.read(librarySelectionNotifierProvider).selectedIds, {
        item.id,
      });
      expect(find.byType(LibrarySelectionIndicator), findsOneWidget);
      expect(
        find.byKey(ValueKey('selected-overlay-${item.id}')),
        findsOneWidget,
      );
    });

    testWidgets('リストのコンテンツ長押しでメニューではなく選択状態になる', (tester) async {
      final item = MediaItem()
        ..id = 23
        ..path = 'library/list_long_press.jpg'
        ..originalPath = '/tmp/list_long_press.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          const InternalLibraryScreen(),
          overrides: [
            appModeProvider.overrideWith((ref) => AppMode.internal),
            globalViewModeProvider.overrideWith((ref) => ViewMode.list),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterAllNotifier()),
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(MediaListTile));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InternalLibraryScreen)),
      );
      expect(container.read(librarySelectionNotifierProvider).selectedIds, {
        item.id,
      });
      expect(find.byType(LibrarySelectionIndicator), findsOneWidget);
    });
  });

  group('MediaViewerScreen', () {
    testWidgets('内部モードのロード表示を直接検証できる', (tester) async {
      final item = MediaItem()
        ..id = 1
        ..path = 'library/sample.jpg'
        ..originalPath = '/tmp/sample.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          MediaViewerScreen(initialItem: item),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelLoading(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('旧参照は再生せず移行案内を表示する', (tester) async {
      final item = MediaItem()
        ..id = 2
        ..path = 'content://sample/video.mp4'
        ..originalPath = 'content://sample/video.mp4'
        ..sourceType = MediaSourceType.externalReference
        ..type = MediaType.file
        ..parentPath = '/external/folder';

      await tester.pumpWidget(
        createProviderApp(
          MediaViewerScreen(initialItem: item),
          overrides: [
            externalFolderItemsProvider(
              item.parentPath,
            ).overrideWith(() => _TestExternalFolderItemsLoading()),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pump();

      expect(find.textContaining('ライブラリは取り込んだコピー'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('未対応拡張子はファイルビューを表示する', (tester) async {
      final item = MediaItem()
        ..id = 3
        ..path = 'library/archive.zip'
        ..originalPath = '/tmp/archive.zip'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          MediaViewerScreen(initialItem: item),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnsupportedFileView), findsOneWidget);
    });

    testWidgets('未対応形式の旧参照も移行案内を表示する', (tester) async {
      final item = MediaItem()
        ..id = 4
        ..path = 'content://sample/archive.zip'
        ..originalPath = 'archive.zip'
        ..sourceType = MediaSourceType.externalReference
        ..type = MediaType.file
        ..parentPath = '/external/folder';

      await tester.pumpWidget(
        createProviderApp(
          MediaViewerScreen(initialItem: item),
          overrides: [
            externalFolderItemsProvider(
              item.parentPath,
            ).overrideWith(() => _TestExternalFolderItemsWithItems([item])),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ライブラリは取り込んだコピー'), findsOneWidget);
      expect(find.byType(UnsupportedFileView), findsNothing);
    });

    testWidgets('ビューアの主要アイコン操作にはツールチップがある', (tester) async {
      final item = MediaItem()
        ..id = 5
        ..path = 'library/sample.jpg'
        ..originalPath = '/tmp/sample.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = null;

      await tester.pumpWidget(
        createProviderApp(
          MediaViewerScreen(initialItem: item),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _TestLibraryViewModelWithItems([item]),
            ),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('閉じる'), findsOneWidget);
      expect(find.byTooltip('管理とその他の操作'), findsOneWidget);
      expect(find.byTooltip('カタログ内の一覧へ戻る'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('カタログから開いたビューアはAppBarからカタログ内一覧へ戻れる', (tester) async {
      final item = MediaItem()
        ..id = 6
        ..path = 'catalog/sample.jpg'
        ..originalPath = '/tmp/sample.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file
        ..parentPath = 'catalog';

      await tester.pumpWidget(
        createProviderApp(
          Consumer(
            builder: (context, ref, _) {
              final filter = ref.watch(
                mediaFilterNotifierProvider(AppMode.internal),
              );
              return Scaffold(
                body: Column(
                  children: [
                    Text(filter.parentPath ?? 'root'),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => MediaViewerScreen(
                            initialItem: item,
                            sourceContext: ViewerSourceContext.catalog(
                              items: [item],
                              parentPath: 'catalog',
                              appMode: AppMode.internal,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('viewerを開く'),
                    ),
                  ],
                ),
              );
            },
          ),
          overrides: [
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _TestMediaFilterNotifier()),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('viewerを開く'));
      await tester.pumpAndSettle();

      final backToContents = find.byTooltip('カタログ内の一覧へ戻る');
      expect(backToContents, findsOneWidget);

      await tester.tap(backToContents);
      await tester.pumpAndSettle();

      expect(find.byType(MediaViewerScreen), findsNothing);
      expect(find.text('catalog'), findsOneWidget);
    });

    testWidgets('小型画面と200%文字サイズでも初回空状態の主要操作が崩れない', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: createProviderApp(
            const InternalLibraryScreen(),
            overrides: [
              mediaFilterNotifierProvider(
                AppMode.internal,
              ).overrideWith(() => _TestMediaFilterAllNotifier()),
              libraryViewModelProvider.overrideWith(
                () => _TestLibraryViewModelSuccess(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const ValueKey('empty-library-add')), findsOneWidget);
      expect(find.text('追加'), findsNothing);
      expect(find.byTooltip('ライブラリを検索'), findsOneWidget);
      expect(find.byTooltip('管理とその他の操作'), findsOneWidget);
    });
  });
}

class _PushInternalLibraryHarness extends StatefulWidget {
  const _PushInternalLibraryHarness();

  @override
  State<_PushInternalLibraryHarness> createState() =>
      _PushInternalLibraryHarnessState();
}

class _PushInternalLibraryHarnessState
    extends State<_PushInternalLibraryHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const InternalLibraryScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
