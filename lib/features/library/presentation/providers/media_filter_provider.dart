import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

import 'secret_mode_provider.dart';
import 'library_view_settings_provider.dart';

part 'media_filter_provider.g.dart';

/// Wait for a short typing pause, without delaying explicit submit or clear.
const librarySearchDebounce = Duration(milliseconds: 180);

@riverpod
class MediaFilterNotifier extends _$MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    // モードに応じた初期設定
    final sourceType = switch (mode) {
      AppMode.internal => MediaSourceType.localCopy,
      AppMode.external => MediaSourceType.externalReference,
    };

    final isHiddenModeOn = ref.read(secretModeProvider).value ?? false;

    ref.listen(secretModeProvider, (_, next) {
      final modeOn = next.value ?? false;
      state = state.copyWith(isHidden: modeOn ? null : false);
    });

    return MediaFilter(
      rootOnly: true,
      sourceType: sourceType,
      isHidden: isHiddenModeOn ? null : false,
    );
  }

  /// 簡易表示の切り替え（ライブラリ全体のグローバル設定として保存）
  Future<void> updateSimpleDisplay(bool value) async {
    await ref.read(globalSimpleDisplayAsyncProvider.notifier).setValue(value);
  }

  void updateSearchQuery(String query) {
    final normalized = query.trim();
    state = state.copyWith(searchQuery: normalized.isEmpty ? null : normalized);
  }

  void updateSearchTarget(SearchTarget target) {
    state = state.copyWith(searchTarget: target);
  }

  void updateSearchWithinParent(bool value) {
    state = state.copyWith(searchWithinParent: value);
  }

  void endSearch() {
    state = state.copyWith(
      searchQuery: null,
      searchTarget: null,
      searchWithinParent: false,
    );
  }

  void clearDiscoveryConditions() {
    state = state.copyWith(
      searchQuery: null,
      searchTarget: null,
      searchWithinParent: false,
      tagIds: null,
      excludedTagIds: null,
      tiers: null,
      hasTags: null,
      isFavorite: null,
      mediaTypes: null,
      onlyCatalogs: false,
      isHidden: _defaultHiddenFilter,
    );
  }

  void clearFilterConditions() {
    state = state.copyWith(
      tagIds: null,
      excludedTagIds: null,
      tiers: null,
      hasTags: null,
      isFavorite: null,
      mediaTypes: null,
      isHidden: _defaultHiddenFilter,
    );
  }

  bool? get _defaultHiddenFilter =>
      (ref.read(secretModeProvider).value ?? false) ? null : false;

  void updateOnlyCatalogs(bool value) {
    state = state.copyWith(onlyCatalogs: value);
  }

  void updateTiers(List<int>? tiers) {
    state = state.copyWith(tiers: tiers);
  }

  void updateHasTags(bool? value) {
    state = state.copyWith(hasTags: value);
  }

  void updateIsFavorite(bool? value) {
    state = state.copyWith(isFavorite: value);
  }

  void updateMediaTypes(List<MediaType>? types) {
    state = state.copyWith(mediaTypes: types);
  }

  void updateTagIds(List<int>? tagIds) {
    state = state.copyWith(tagIds: tagIds);
  }

  void applyFilterConditions(MediaFilter filter) {
    state = state.copyWith(
      tagIds: filter.tagIds,
      excludedTagIds: filter.excludedTagIds,
      tiers: filter.tiers,
      hasTags: filter.hasTags,
      isFavorite: filter.isFavorite,
      isHidden: filter.isHidden,
      mediaTypes: filter.mediaTypes,
    );
  }

  Future<void> updateSortOrder(SortOrder order) async {
    state = state.copyWith(sortOrder: order);
    await saveAsDefault();
  }

  /// 表示モードの切り替え（ライブラリ全体のグローバル設定として保存）
  Future<void> updateViewMode(ViewMode viewMode) async {
    await ref.read(globalViewModeAsyncProvider.notifier).setValue(viewMode);
  }

  void updateParentPath(String? path) {
    var resolvedPath = (path == null || path.isEmpty) ? null : path;
    if (resolvedPath != null &&
        mode == AppMode.internal &&
        _isInternalLibraryRoot(resolvedPath)) {
      resolvedPath = null;
    }

    state = state.copyWith(
      parentPath: resolvedPath,
      // 階層移動時はカタログ一覧表示を解除（ただし検索中でない場合のみ、などの考慮が必要な場合は呼び出し側で制御も可能だが、一旦現状維持）
      onlyCatalogs: false,
    );

    // ディレクトリ移動時に、そのカタログのデフォルト設定があれば適用する
    // ※ viewMode / isSimpleDisplay / isHidden はライブラリ全体設定のため引き継ぐ
    if (resolvedPath != null) {
      _applyDefaultSettings(resolvedPath);
    }
  }

  Future<void> _applyDefaultSettings(String path) async {
    try {
      final repository = await ref.read(mediaRepositoryProvider.future);
      final collectionResult = await repository.getCollectionByPath(path);

      collectionResult.when(
        success: (collection) {
          if (collection != null &&
              state.parentPath == path &&
              state.sortOrder != collection.defaultSortOrder) {
            // ソート順のみカタログ固有の設定を適用する
            // viewMode / isSimpleDisplay / isHidden はグローバル設定を引き継ぐ
            state = state.copyWith(sortOrder: collection.defaultSortOrder);
          }
        },
        failure: (_) {},
      );
    } catch (_) {
      // リポジトリ初期化前やテスト環境での安全なフォールバック
    }
  }

  /// 現在のソート順を、現在のディレクトリ（カタログ）のデフォルトとして保存する
  Future<void> saveAsDefault() async {
    final path = state.parentPath;
    if (path == null) return;

    try {
      final repository = await ref.read(mediaRepositoryProvider.future);
      final collectionResult = await repository.getCollectionByPath(path);

      await collectionResult.when(
        success: (collection) async {
          if (collection != null) {
            final updated = collection
              ..defaultSortOrder = state.sortOrder
              ..updatedAt = DateTime.now();
            await repository.saveCollection(updated);
          }
        },
        failure: (_) {},
      );
    } catch (_) {
      // リポジトリ初期化前やテスト環境での安全なフォールバック
    }
  }

  Future<void> goUp() async {
    final currentPath = state.parentPath;
    if (currentPath == null) return;

    final normalizedCurrentPath = p.normalize(currentPath);
    final parent = p.normalize(p.dirname(normalizedCurrentPath));

    final hasNoParent =
        parent == '.' || parent == normalizedCurrentPath || parent == '/';
    if (hasNoParent) {
      updateParentPath(null);
      return;
    }

    if (mode == AppMode.internal && _isInternalLibraryRoot(parent)) {
      updateParentPath(null);
      return;
    }

    updateParentPath(parent);
  }

  bool _isInternalLibraryRoot(String path) {
    final normalized = p.normalize(path);
    if (normalized == 'library') return true;
    return p.basename(normalized) == 'library';
  }

  void reset() {
    final sourceType = switch (mode) {
      AppMode.internal => MediaSourceType.localCopy,
      AppMode.external => MediaSourceType.externalReference,
    };
    state = MediaFilter(rootOnly: true, sourceType: sourceType);
  }
}
