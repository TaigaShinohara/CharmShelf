import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _Repository extends Mock implements MediaRepository {}

class _SecretMode extends SecretMode {
  final bool value;

  _SecretMode(this.value);

  @override
  FutureOr<bool> build() => value;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('初期状態はデフォルトのMediaFilterであること', () {
    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(
      state,
      const MediaFilter(rootOnly: true, sourceType: MediaSourceType.localCopy),
    );
  });

  test('シークレットモード中は通常ライブラリの非表示条件を解除する', () async {
    final scopedContainer = ProviderContainer(
      overrides: [secretModeProvider.overrideWith(() => _SecretMode(true))],
    );
    addTearDown(scopedContainer.dispose);

    await scopedContainer.read(secretModeProvider.future);
    final state = scopedContainer.read(
      mediaFilterNotifierProvider(AppMode.internal),
    );

    expect(state.isHidden, isNull);
  });

  test('updateSearchQueryで検索クエリが更新されること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchQuery('test');

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.searchQuery, 'test');
  });

  test('空白だけの検索クエリは未指定へ正規化されること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchQuery('  test  ');
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).searchQuery,
      'test',
    );

    notifier.updateSearchQuery('   ');
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).searchQuery,
      isNull,
    );
  });

  test('検索対象をカタログのみへ切り替えられること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );

    notifier.updateSearchTarget(SearchTarget.catalogsOnly);

    expect(
      container
          .read(mediaFilterNotifierProvider(AppMode.internal))
          .searchTarget,
      SearchTarget.catalogsOnly,
    );
  });

  for (final onlyCatalogs in [false, true]) {
    test('検索の初期対象は一覧onlyCatalogs=$onlyCatalogsでもファイルを含む', () {
      final notifier = container.read(
        mediaFilterNotifierProvider(AppMode.internal).notifier,
      );
      notifier.updateOnlyCatalogs(onlyCatalogs);
      notifier.updateSearchQuery('旅行');
      final state = container.read(
        mediaFilterNotifierProvider(AppMode.internal),
      );
      expect(state.searchTarget, isNull);
      expect(state.effectiveSearchTarget, SearchTarget.filesIncluded);
      expect(state.onlyCatalogs, onlyCatalogs);
    });
  }

  test('検索中の明示対象は入力と一覧表示変更後も維持される', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchTarget(SearchTarget.catalogsOnly);
    notifier.updateSearchQuery('旅行');
    notifier.updateOnlyCatalogs(false);
    notifier.updateSearchQuery('資料');
    expect(
      container
          .read(mediaFilterNotifierProvider(AppMode.internal))
          .effectiveSearchTarget,
      SearchTarget.catalogsOnly,
    );
  });

  test('検索終了はクエリと対象だけを解除し一覧条件を保持する', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateOnlyCatalogs(true);
    notifier.updateIsFavorite(true);
    notifier.updateSearchQuery('旅行');
    notifier.updateSearchTarget(SearchTarget.catalogsOnly);
    notifier.endSearch();
    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.searchQuery, isNull);
    expect(state.searchTarget, isNull);
    expect(state.effectiveSearchTarget, SearchTarget.filesIncluded);
    expect(state.onlyCatalogs, isTrue);
    expect(state.isFavorite, isTrue);
    expect(state.sourceType, MediaSourceType.localCopy);
    expect(state.isHidden, isFalse);
  });

  test('updateSortOrderでソート順が更新されること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    const newOrder = SortOrder.dateAsc;
    notifier.updateSortOrder(newOrder);

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.sortOrder, newOrder);
  });

  test('フォルダの並び順が同じなら状態を再通知しない', () async {
    final repository = _Repository();
    final collection = MediaCollection()..path = 'library/album';
    when(() => repository.getCollectionByPath(collection.path)).thenAnswer(
      (_) async => Result<MediaCollection?, AppError>.success(collection),
    );
    final scopedContainer = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(scopedContainer.dispose);
    await scopedContainer.read(secretModeProvider.future);
    final notifications = <MediaFilter>[];
    final provider = mediaFilterNotifierProvider(AppMode.internal);
    final subscription = scopedContainer.listen(
      provider,
      (_, next) => notifications.add(next),
    );
    addTearDown(subscription.close);

    scopedContainer.read(provider.notifier).updateParentPath(collection.path);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, hasLength(1));
    expect(scopedContainer.read(provider).parentPath, collection.path);
  });

  test('前のフォルダの読み込み結果を移動先に適用しない', () async {
    final repository = _Repository();
    final previousResult = Completer<Result<MediaCollection?, AppError>>();
    final previous = MediaCollection()
      ..path = 'library/previous'
      ..defaultSortOrder = SortOrder.nameAsc;
    final current = MediaCollection()..path = 'library/current';
    when(
      () => repository.getCollectionByPath(previous.path),
    ).thenAnswer((_) => previousResult.future);
    when(() => repository.getCollectionByPath(current.path)).thenAnswer(
      (_) async => Result<MediaCollection?, AppError>.success(current),
    );
    final scopedContainer = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(scopedContainer.dispose);
    final provider = mediaFilterNotifierProvider(AppMode.internal);
    final subscription = scopedContainer.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final notifier = scopedContainer.read(provider.notifier);

    notifier.updateParentPath(previous.path);
    notifier.updateParentPath(current.path);
    previousResult.complete(
      Result<MediaCollection?, AppError>.success(previous),
    );
    await Future<void>.delayed(Duration.zero);

    expect(scopedContainer.read(provider).parentPath, current.path);
    expect(scopedContainer.read(provider).sortOrder, SortOrder.addedDesc);
  });

  test('resetで初期状態に戻ること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchQuery('test');
    notifier.updateSortOrder(SortOrder.dateAsc);

    notifier.reset();

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(
      state,
      const MediaFilter(rootOnly: true, sourceType: MediaSourceType.localCopy),
    );
  });

  test('条件の全解除は表示位置と並び順を保持し全絞り込みを解除する', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchQuery('query');
    notifier.updateTiers([1, 2]);
    notifier.updateHasTags(false);
    notifier.updateIsFavorite(true);
    notifier.updateMediaTypes([MediaType.file]);
    notifier.updateOnlyCatalogs(true);
    notifier.updateSearchTarget(SearchTarget.catalogsOnly);
    notifier.updateSortOrder(SortOrder.nameAsc);

    notifier.clearDiscoveryConditions();

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.searchQuery, isNull);
    expect(state.tiers, isNull);
    expect(state.hasTags, isNull);
    expect(state.isFavorite, isNull);
    expect(state.mediaTypes, isNull);
    expect(state.onlyCatalogs, isFalse);
    expect(state.searchTarget, isNull);
    expect(state.parentPath, isNull);
    expect(state.sortOrder, SortOrder.nameAsc);
  });

  test('フィルター条件一式を一度に反映できる', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );

    notifier.applyFilterConditions(
      const MediaFilter(
        tagIds: [1],
        excludedTagIds: [2],
        tiers: [3],
        hasTags: true,
        isFavorite: true,
        mediaTypes: [MediaType.file],
      ),
    );

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.tagIds, [1]);
    expect(state.excludedTagIds, [2]);
    expect(state.tiers, [3]);
    expect(state.hasTags, isTrue);
    expect(state.isFavorite, isTrue);
    expect(state.mediaTypes, [MediaType.file]);
  });

  test('フィルター解除は検索語を保持する', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateSearchQuery('keep');
    notifier.updateTiers([1]);

    notifier.clearFilterConditions();

    final state = container.read(mediaFilterNotifierProvider(AppMode.internal));
    expect(state.searchQuery, 'keep');
    expect(state.tiers, isNull);
  });

  test('updateParentPathで内部ストレージのlibraryルートがnullに正規化されること', () {
    final notifier = container.read(
      mediaFilterNotifierProvider(AppMode.internal).notifier,
    );
    notifier.updateParentPath('library/folderA');
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).parentPath,
      'library/folderA',
    );

    notifier.updateParentPath('library');
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).parentPath,
      isNull,
    );

    notifier.updateParentPath('library/');
    expect(
      container.read(mediaFilterNotifierProvider(AppMode.internal)).parentPath,
      isNull,
    );
  });
}
