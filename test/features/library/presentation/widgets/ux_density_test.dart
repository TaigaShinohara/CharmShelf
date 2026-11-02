import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/screens/internal_library_screen.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/active_condition_chips.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/compact_tag_preview.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_sort_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_selector_widget.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';

import '../../../../helpers/test_helpers.dart';
import '../../../../shared/finders.dart' as shared_find;

class _Secret extends SecretMode {
  _Secret(this.initial);
  final FutureOr<bool> initial;
  @override
  FutureOr<bool> build() => initial;
  void setForTest(bool value) => state = AsyncData(value);
}

class _Facets extends TagFacetListViewModel {
  @override
  Stream<List<TagFacet>> build() => Stream.value([
    TagFacet()
      ..id = 1
      ..name = 'ジャンル'
      ..createdAt = DateTime(2026),
  ]);
}

class _Tags extends TagListViewModel {
  _Tags(this.tags);
  final List<Tag> tags;
  int? savedParent;
  bool? savedHidden;
  @override
  Stream<List<Tag>> build() => Stream.value(tags);
  @override
  Future<void> updateTag(
    Tag tag, {
    required String name,
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool? isHidden,
  }) async {
    savedParent = parentId;
    savedHidden = isHidden;
  }
}

class _RecordingSyncTags extends SyncCollectionTagsUseCase {
  _RecordingSyncTags() : super(Completer<MediaRepository>().future);

  final calls = <List<int>>[];

  @override
  Future<Result<void, AppError>> invoke(
    MediaItem item,
    List<Tag> targetTags,
  ) async {
    calls.add(targetTags.map((tag) => tag.id).toList());
    return Result.success(null);
  }
}

class _Filter extends MediaFilterNotifier {
  _Filter({this.inFolder = false});
  final bool inFolder;
  @override
  MediaFilter build(AppMode mode) => MediaFilter(
    parentPath: inFolder ? 'subfolder' : null,
    rootOnly: !inFolder,
    onlyCatalogs: false,
    sourceType: MediaSourceType.localCopy,
  );
}

class _Items extends LibraryViewModel {
  @override
  FutureOr<List<MediaItem>> build() => [];
}

class _Collection extends CollectionNotifier {
  _Collection(this.collection);
  final MediaCollection? collection;
  @override
  Future<MediaCollection?> build(String path) async => collection;
}

void main() {
  setUp(setupMockSharedPreferences);

  Widget app(
    Widget child, {
    List<Override> overrides = const [],
    double scale = 1,
  }) {
    return createProviderApp(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        tagFacetListViewModelProvider.overrideWith(_Facets.new),
        ...overrides,
      ],
    );
  }

  testWidgets('空フォルダから追加メニューを開き、フォルダ作成へ進める', (tester) async {
    await tester.pumpWidget(
      app(
        const InternalLibraryScreen(),
        overrides: [
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(() => _Filter(inFolder: true)),
          libraryViewModelProvider.overrideWith(_Items.new),
          collectionNotifierProvider(
            'subfolder',
          ).overrideWith(() => _Collection(null)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('empty-folder-add'));
    expect(add, findsOneWidget);
    expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('ファイルを取り込む'), findsOneWidget);
    expect(shared_find.findAppText('フォルダを取り込む'), findsOneWidget);
    await tester.tap(shared_find.findAppText('新規フォルダ作成'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('作成'), findsOneWidget);
  });

  testWidgets('ライブラリの整理先としてごみ箱へ直接移動できる', (tester) async {
    await tester.pumpWidget(
      app(
        const InternalLibraryScreen(),
        overrides: [
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_Filter.new),
          libraryViewModelProvider.overrideWith(_Items.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('アーカイブ表示'), findsOneWidget);
    expect(find.text('シークレットモードをオン'), findsOneWidget);
    expect(find.text('ごみ箱'), findsOneWidget);
  });

  testWidgets('最近見た順の表示と実際のソート設定が一致する', (tester) async {
    final container = ProviderContainer(
      overrides: [
        mediaFilterNotifierProvider(AppMode.internal).overrideWith(_Filter.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      mediaFilterNotifierProvider(AppMode.internal),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: createLocalizedApp(
          Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () =>
                    showLibrarySortDialog(context, ref, mode: AppMode.internal),
                child: const Text('sort'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('sort'));
    await tester.pumpAndSettle();
    expect(find.text('最近追加された順'), findsNothing);
    final recent = find.text('最近見た順');
    await tester.ensureVisible(recent);
    await tester.tap(recent);
    await tester.pumpAndSettle();
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).sortOrder,
      SortOrder.lastViewedDesc,
    );
  });

  testWidgets('検索語は検索欄と重複表示せず、検索範囲だけをチップで示す', (tester) async {
    const filter = MediaFilter(
      searchQuery: '旅行',
      onlyCatalogs: false,
      sourceType: MediaSourceType.localCopy,
    );
    await tester.pumpWidget(
      app(
        const ActiveConditionChips(
          mode: AppMode.internal,
          filter: filter,
          sortOrderLabel: '追加順',
          showSearchQuery: false,
        ),
        overrides: [
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_Filter.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ActiveConditionChips)),
    )!;
    expect(find.text(l10n.libraryActiveSearchQuery('旅行')), findsNothing);
    expect(find.text(l10n.librarySearchFilesIncluded), findsNothing);
    expect(find.text(l10n.librarySearchCatalogsOnly), findsNothing);
  });

  testWidgets('条件が多くても、すべて解除をスクロールせずに押せる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var cleared = false;

    await tester.pumpWidget(
      app(
        ActiveConditionChips(
          mode: AppMode.internal,
          filter: const MediaFilter(
            searchQuery: '旅行',
            onlyCatalogs: true,
            sortOrder: SortOrder.nameAsc,
            isFavorite: true,
          ),
          sortOrderLabel: '名前順',
          onClearAll: () => cleared = true,
        ),
        overrides: [
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_Filter.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final clearButton = find.text('条件をすべて解除');
    expect(clearButton, findsOneWidget);
    expect(tester.getTopLeft(clearButton).dx, lessThan(320));
    await tester.tap(clearButton);
    expect(cleared, isTrue);
  });

  testWidgets('タグは3件だけ表示し、残りも選択できる。非表示タグは件数にも含めない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tags = List.generate(
      6,
      (i) => Tag()
        ..id = i + 1
        ..name = 'タグ$i'
        ..facetId = 1,
    );
    tags.last.isHidden = true;
    Tag? selected;
    await tester.pumpWidget(
      app(
        CompactTagPreview(tags: tags, onTagTap: (tag) => selected = tag),
        scale: 2,
        overrides: [secretModeProvider.overrideWith(() => _Secret(false))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('タグ2'), findsOneWidget);
    expect(find.text('タグ3'), findsNothing);
    expect(find.text('タグ5'), findsNothing);
    expect(find.text('ほか2件'), findsOneWidget);
    final more = find.byKey(const ValueKey('show-more-tags'));
    expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('タグ4'), findsOneWidget);
    expect(find.text('タグ5'), findsNothing);
    await tester.tap(find.text('タグ4'));
    await tester.pumpAndSettle();
    expect(selected?.id, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('グリッド用タグ一覧は12件まで小サイズで表示する', (tester) async {
    final tags = List.generate(
      14,
      (i) => Tag()
        ..id = i + 1
        ..name = 'タグ$i'
        ..facetId = 1,
    );

    await tester.pumpWidget(
      app(
        CompactTagPreview(
          tags: tags,
          maxVisibleTags: libraryTagPreviewLimit,
          compactRemainingCount: true,
          onTagTap: null,
        ),
        overrides: [secretModeProvider.overrideWith(() => _Secret(false))],
      ),
    );
    await tester.pumpAndSettle();

    for (final tag in tags.take(libraryTagPreviewLimit)) {
      expect(find.text(tag.name), findsOneWidget);
    }
    expect(find.text('タグ12'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('ほか2件'), findsNothing);
    final moreButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('show-more-tags')),
    );
    expect(
      moreButton.style?.alignment?.resolve(TextDirection.ltr),
      Alignment.centerLeft,
    );
    final moreChip = tester.widget<Container>(
      find
          .ancestor(of: find.text('+2'), matching: find.byType(Container))
          .first,
    );
    final decoration = moreChip.decoration! as BoxDecoration;
    expect(
      decoration.color,
      Theme.of(
        tester.element(find.text('+2')),
      ).colorScheme.surfaceContainerHighest,
    );
    expect(decoration.borderRadius, BorderRadius.circular(3));
    final moreText = tester.widget<Text>(find.text('+2'));
    expect(moreText.style?.fontSize, 8);
    expect(moreText.style?.fontWeight, FontWeight.w600);
    expect(
      tester
          .widgetList<AppTag>(find.byType(AppTag))
          .every((tag) => tag.size == AppTagSize.small && tag.onTap == null),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('グリッド用タグ一覧は左詰めで、幅を超えると次の行へ折り返す', (tester) async {
    final tags = List.generate(
      4,
      (i) => Tag()
        ..id = i + 1
        ..name = 'タグ$i'
        ..facetId = 1,
    );

    await tester.pumpWidget(
      app(
        SizedBox(
          width: 120,
          child: CompactTagPreview(tags: tags, onTagTap: null),
        ),
        overrides: [secretModeProvider.overrideWith(() => _Secret(false))],
      ),
    );
    await tester.pumpAndSettle();

    final wrap = find.byKey(const ValueKey('compact-tag-preview-wrap'));
    final wrapRect = tester.getRect(wrap);
    expect(wrapRect.width, 120);

    final tagRects = tester
        .widgetList<AppTag>(find.byType(AppTag))
        .map((tag) => tester.getRect(find.widgetWithText(AppTag, tag.label)))
        .toList();
    expect(tagRects[1].top, tagRects[0].top);
    for (final tag in tester.widgetList<AppTag>(find.byType(AppTag))) {
      final visual = find.descendant(
        of: find.widgetWithText(AppTag, tag.label),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.getRect(visual).left,
        tester.getRect(find.widgetWithText(AppTag, tag.label)).left,
      );
    }
    final secondRowRect = tagRects.firstWhere(
      (rect) => rect.top > tagRects.first.top + 1,
    );
    expect(tagRects.first.left, closeTo(wrapRect.left, 0.01));
    expect(secondRowRect.left, closeTo(wrapRect.left, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('残り件数の表示はチャームの中央にそろい操作領域が重ならない', (tester) async {
    final tags = [for (var i = 0; i < 4; i++) Tag()..name = 'A$i'];
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 240,
          child: CompactTagPreview(
            tags: tags,
            onTagTap: null,
            compactRemainingCount: true,
          ),
        ),
        overrides: [secretModeProvider.overrideWith(() => _Secret(false))],
      ),
    );
    await tester.pumpAndSettle();
    final last = find.byType(AppTag).last;
    final body = tester.getRect(
      find.descendant(of: last, matching: find.byType(AnimatedContainer)),
    );
    final more = tester.getRect(find.byKey(const ValueKey('show-more-tags')));
    final badge = tester.getRect(
      find
          .ancestor(of: find.text('+1'), matching: find.byType(Container))
          .first,
    );
    expect(more.width, greaterThanOrEqualTo(48));
    expect(more.height, greaterThanOrEqualTo(48));
    expect(badge.center.dy, closeTo(body.center.dy, .01));
    expect(more.left, greaterThanOrEqualTo(body.right + 2));
    await tester.tapAt(Offset(more.right - 8, more.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('A3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全タグでは長いタグ名も省略せず折り返して選択できる', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longName = '旅行の写真と動画をまとめた長い名前のタグ';
    final tags = [
      for (var i = 0; i < 3; i++) Tag()..name = 'タグ$i',
      Tag()..name = longName,
    ];
    Tag? selected;
    await tester.pumpWidget(
      app(
        CompactTagPreview(tags: tags, onTagTap: (tag) => selected = tag),
        scale: 2,
        overrides: [secretModeProvider.overrideWith(() => _Secret(false))],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('show-more-tags')));
    await tester.pumpAndSettle();
    final label = find.text(longName);
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(label);
    expect(text.maxLines, isNull);
    expect(text.softWrap, isTrue);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(selected?.name, longName);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非表示モードの読み込み中には秘密タグを表示しない', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      app(
        CompactTagPreview(
          tags: [
            Tag()
              ..name = '秘密'
              ..isHidden = true,
          ],
          onTagTap: (_) {},
        ),
        overrides: [
          secretModeProvider.overrideWith(() => _Secret(pending.future)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('秘密'), findsNothing);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('秘密'), findsNothing);
  });

  testWidgets('全タグの表示中も非表示モードを解除すると秘密タグが消える', (tester) async {
    final secret = _Secret(true);
    final tags = List.generate(
      5,
      (i) => Tag()
        ..id = i + 1
        ..name = 'タグ$i'
        ..isHidden = i == 4,
    );
    await tester.pumpWidget(
      app(
        CompactTagPreview(tags: tags, onTagTap: (_) {}),
        overrides: [secretModeProvider.overrideWith(() => secret)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('show-more-tags')));
    await tester.pumpAndSettle();
    expect(find.text('タグ4'), findsOneWidget);
    secret.setForTest(false);
    await tester.pumpAndSettle();
    expect(find.text('タグ4'), findsNothing);
    expect(find.text('タグ3'), findsOneWidget);
  });

  testWidgets('タグ新規作成では親タグ・非表示の詳細設定を表示しない', (tester) async {
    await tester.pumpWidget(
      app(
        const TagFormSheet(initialFacetId: 1),
        overrides: [tagListViewModelProvider.overrideWith(() => _Tags([]))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新しいチャームを作成して登録します。'), findsNothing);
    expect(find.byKey(const ValueKey('tag-advanced-settings')), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(DropdownButtonFormField<int?>), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('既存タグの親・非表示をマスクしつつ更新時に維持する', (tester) async {
    final parent = Tag()
      ..id = 1
      ..name = '親'
      ..facetId = 1;
    final child = Tag()
      ..id = 2
      ..name = '子'
      ..facetId = 1
      ..parentId = 1
      ..isHidden = true;
    final tags = _Tags([parent, child]);
    await tester.pumpWidget(
      app(
        TagFormSheet(tag: child),
        overrides: [tagListViewModelProvider.overrideWith(() => tags)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-advanced-settings')), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(DropdownButtonFormField<int?>), findsNothing);
    await tester.ensureVisible(find.text('更新'));
    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(tags.savedParent, 1);
    expect(tags.savedHidden, isTrue);
  });

  testWidgets('タグ追加は選択時に即時反映し、選択中表示をコンパクトに保つ', (tester) async {
    final tag = Tag()
      ..id = 1
      ..name = '写真'
      ..facetId = 1
      ..createdAt = DateTime(2026);
    final collection = MediaCollection()
      ..path = 'catalog'
      ..title = '作品'
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    final item = MediaItem()..collection.value = collection;
    final syncTags = _RecordingSyncTags();

    await tester.pumpWidget(
      app(
        SizedBox(height: 700, child: TagSelectorWidget(item: item)),
        overrides: [
          tagListViewModelProvider.overrideWith(() => _Tags([tag])),
          syncCollectionTagsUseCaseProvider.overrideWithValue(syncTags),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('適用 ('), findsNothing);
    await tester.tap(find.text('写真'));
    await tester.pumpAndSettle();

    expect(syncTags.calls, [
      [1],
    ]);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsOneWidget);
    final selectedSection = find.byKey(const ValueKey('tag-selected-section'));
    expect(tester.getSize(selectedSection).height, lessThanOrEqualTo(52));
    expect(
      tester.getTopLeft(selectedSection).dy,
      lessThan(tester.getTopLeft(find.byType(TextField).first).dy),
    );
    final selectedTag = tester.widget<AppTag>(
      find.descendant(of: selectedSection, matching: find.byType(AppTag)),
    );
    expect(selectedTag.size, AppTagSize.small);
    expect(selectedTag.isSelected, isFalse);
    expect(selectedTag.isDimmed, isFalse);
    final selectedTarget = find.descendant(
      of: selectedSection,
      matching: find.byType(AppTag),
    );
    expect(tester.getSize(selectedTarget).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(selectedTarget).height, greaterThanOrEqualTo(48));
    await tester.tap(selectedTarget);
    await tester.pumpAndSettle();
    expect(syncTags.calls.last, isEmpty);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsNothing);
  });

  testWidgets('カタログは主要操作を残し、詳細からエイリアスを編集できる', (tester) async {
    final collection = MediaCollection()
      ..path = 'catalog'
      ..title = '作品'
      ..isCatalog = true
      ..type = CollectionType.folder
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    await tester.pumpWidget(
      app(
        const SingleChildScrollView(
          child: CollectionActionSheet(collectionPath: 'catalog'),
        ),
        overrides: [
          collectionNotifierProvider(
            'catalog',
          ).overrideWith(() => _Collection(collection)),
          secretModeProvider.overrideWith(() => _Secret(false)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('チャーム'), findsOneWidget);
    expect(find.text('情報をコピー'), findsOneWidget);
    expect(find.text('表示と整理'), findsOneWidget);
    final openCatalogButton = find.byKey(
      const ValueKey('open-catalog-contents'),
    );
    expect(openCatalogButton, findsOneWidget);
    expect(tester.widget(openCatalogButton), isA<OutlinedButton>());
    expect(
      find.descendant(of: openCatalogButton, matching: find.text('カタログの中身を表示')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('ファイル情報')).dy,
      greaterThan(tester.getTopLeft(openCatalogButton).dy),
    );
    expect(
      tester.getTopLeft(openCatalogButton).dy,
      lessThan(tester.getTopLeft(find.text('お気に入りに追加')).dy),
    );
    expect(find.text('別名'), findsNothing);
    await tester.ensureVisible(find.text('情報をコピー'));
    await tester.tap(find.text('情報をコピー'));
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('パス'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('情報・メモ'));
    await tester.tap(find.text('情報・メモ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('別名'));
    await tester.tap(find.text('別名'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(TextField)))!;
    expect(find.text(l10n.settingsCollectionAliasDescription), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ファイルメニューは表紙、共有の順で、パスを移動の直下に置く', (tester) async {
    final item = MediaItem()
      ..id = 10
      ..path = '/tmp/album/cover.jpg'
      ..parentPath = '/tmp/album'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    await tester.pumpWidget(
      app(
        SingleChildScrollView(child: FileActionSheet(item: item)),
        overrides: [
          libraryViewModelProvider.overrideWith(_Items.new),
          collectionNotifierProvider(
            item.path,
          ).overrideWith(() => _Collection(null)),
          secretModeProvider.overrideWith(() => _Secret(false)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('カタログの表紙に設定'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('カタログの表紙に設定')).dx,
      lessThan(tester.getTopLeft(find.text('共有')).dx),
    );
    expect(
      tester.getTopLeft(find.text('移動')).dy,
      lessThan(tester.getTopLeft(find.text('パスをコピー')).dy),
    );
    expect(find.text('アプリ外へ保存'), findsOneWidget);
    expect(find.text('ごみ箱へ移動'), findsOneWidget);
    expect(find.text('削除'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200%表示の一覧は長い名前を優先し、その他と更新日時を反復しない', (tester) async {
    final collection = MediaCollection()
      ..path = '/tmp/long-file.bin'
      ..title = '内容が分かるように残した長いファイル名'
      ..isCatalog = true
      ..type = CollectionType.file
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    final item = MediaItem()
      ..id = 11
      ..path = collection.path
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    item.collection.value = collection;

    await tester.pumpWidget(
      app(
        Material(child: MediaListTile(item: item, isSimpleDisplay: false)),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text(collection.title));
    expect(title.maxLines, 2);
    expect(find.text('その他'), findsNothing);
    expect(find.textContaining('更新'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
