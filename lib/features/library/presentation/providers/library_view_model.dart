import 'dart:async';
import 'dart:ui' show Rect;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/get_media_stream_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/bulk_update_tags_use_case.dart';
import 'package:private_shelf/features/library/presentation/controllers/library_batch_action_controller.dart';
import 'package:private_shelf/features/library/presentation/controllers/library_import_controller.dart';
import 'package:private_shelf/features/library/presentation/controllers/library_item_operation_controller.dart';
import 'package:private_shelf/features/library/presentation/models/import_catalog_options.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

part 'library_view_model.g.dart';

@Riverpod(keepAlive: true)
class LibraryViewModel extends _$LibraryViewModel {
  static const _initialPageSize = 80;
  static const _pageSize = 200;
  String _appDocumentsPath = '';
  MediaFilter? _lastFilter;
  MediaFilter? _browseFilter;
  int _browseLimit = _initialPageSize;
  int _visibleLimit = _initialPageSize;
  bool _paged = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  StreamController<int>? _pageRequests;
  Completer<void>? _loadMoreCompletion;

  bool get isSelectionMode =>
      ref.read(librarySelectionNotifierProvider).isSelectionMode;
  Set<int> get selectedIds =>
      ref.read(librarySelectionNotifierProvider).selectedIds;
  String get appDocumentsPath => _appDocumentsPath;

  @override
  FutureOr<List<MediaItem>> build() async {
    // 内部用のフィルタを監視
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.internal));
    if (_lastFilter != filter) {
      if (_lastFilter != null && (_lastFilter!.searchQuery?.isEmpty ?? true)) {
        _browseFilter = _lastFilter!.copyWith(searchTarget: null);
        _browseLimit = _visibleLimit;
      }
      _lastFilter = filter;
      // Search has its own 80-item window. Returning to the same browse view
      // restores its loaded window so a retained scroll position is still valid.
      final browseFilter = (filter.searchQuery?.isEmpty ?? true)
          ? filter.copyWith(searchTarget: null)
          : null;
      _visibleLimit = browseFilter != null && browseFilter == _browseFilter
          ? _browseLimit
          : _initialPageSize;
      _hasMore = false;
      _loadingMore = false;
    }
    _paged = filter.limit == null;
    final effectiveFilter = _paged
        ? filter.copyWith(limit: _visibleLimit)
        : filter;
    // パスの初期化
    try {
      _appDocumentsPath = ref.watch(appDocumentsPathSyncProvider);
    } catch (_) {
      final docsDir = await getPrivateStorageDirectory();
      _appDocumentsPath = docsDir.path;
    }
    if (!ref.mounted) return const [];

    // ストリームを購読して最新の状態を維持
    final useCase = ref.read(getMediaStreamUseCaseProvider);
    final requests = StreamController<int>();
    _pageRequests = requests;
    final source = _paged
        ? useCase.invokePaged(effectiveFilter, requests.stream)
        : useCase.invoke(effectiveFilter);
    final itemsStream = source.map((items) {
      _hasMore = _paged && items.length == _visibleLimit;
      return _filterInternalItems(items);
    });

    final completer = Completer<List<MediaItem>>();

    final subscription = itemsStream.listen(
      (items) {
        _loadingMore = false;
        _loadMoreCompletion?.complete();
        _loadMoreCompletion = null;
        if (!completer.isCompleted) {
          completer.complete(items);
        } else {
          state = AsyncValue.data(items);
        }
      },
      onError: (Object err, StackTrace st) {
        _loadingMore = false;
        _loadMoreCompletion?.complete();
        _loadMoreCompletion = null;
        if (!completer.isCompleted) {
          completer.completeError(err, st);
        } else {
          state = AsyncValue.error(err, st);
        }
      },
    );

    ref.onDispose(() {
      subscription.cancel();
      _loadMoreCompletion?.complete();
      _loadMoreCompletion = null;
      requests.close();
      if (identical(_pageRequests, requests)) _pageRequests = null;
    });

    return completer.future;
  }

  Future<void> loadMore() async {
    if (!_paged || _loadingMore || state.isLoading) return;
    if (!_hasMore || state.value == null) return;
    _loadingMore = true;
    _visibleLimit += _pageSize;
    final completion = _loadMoreCompletion = Completer<void>();
    // Keep the visible page while loading; Riverpod 3 has no public constructor
    // for a loading AsyncValue that retains data. Covered by paging regressions.
    // ignore: invalid_use_of_internal_member
    state = const AsyncValue<List<MediaItem>>.loading().copyWithPrevious(state);
    _pageRequests?.add(_visibleLimit);
    await completion.future;
  }

  List<MediaItem> _filterInternalItems(List<MediaItem> items) {
    return items
        .where(
          (item) =>
              item.sourceType == MediaSourceType.localCopy &&
              !_isExternalPath(item.path),
        )
        .toList();
  }

  bool _isExternalPath(String rawPath) {
    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'file') return true;
      final filePath = p.normalize(uri.toFilePath());
      if (_appDocumentsPath.isNotEmpty &&
          (filePath == _appDocumentsPath ||
              p.isWithin(_appDocumentsPath, filePath) ||
              filePath.startsWith(_appDocumentsPath))) {
        return false;
      }
      return p.isAbsolute(filePath);
    }
    final normalized = p.normalize(rawPath);
    if (_appDocumentsPath.isNotEmpty &&
        (normalized == _appDocumentsPath ||
            p.isWithin(_appDocumentsPath, normalized) ||
            normalized.startsWith(_appDocumentsPath))) {
      return false;
    }
    return p.isAbsolute(normalized);
  }

  // --- 選択モード関連 (LibrarySelectionNotifier に委譲) ---

  void toggleSelectionMode() {
    ref.read(librarySelectionNotifierProvider.notifier).toggleSelectionMode();
  }

  void toggleSelection(int id) {
    ref.read(librarySelectionNotifierProvider.notifier).toggleSelection(id);
  }

  void clearSelection() {
    ref.read(librarySelectionNotifierProvider.notifier).clearSelection();
  }

  bool get areAllVisibleItemsSelected {
    final items = state.value;
    if (items == null || items.isEmpty) return false;
    final currentSelected = ref
        .read(librarySelectionNotifierProvider)
        .selectedIds;
    return items.every((item) => currentSelected.contains(item.id));
  }

  void selectAllVisibleItems() {
    final items = state.value;
    if (items == null || items.isEmpty) return;
    ref
        .read(librarySelectionNotifierProvider.notifier)
        .selectAll(items.map((item) => item.id));
  }

  /// 選択中のアイテムが全てカタログであり、タグ付け可能かどうか
  bool get canApplyBulkTags {
    final currentSelectedIds = selectedIds;
    if (currentSelectedIds.isEmpty) return false;
    final items = state.value ?? [];
    final selectedItems = items
        .where((item) => currentSelectedIds.contains(item.id))
        .toList();
    if (selectedItems.isEmpty) return false;
    return selectedItems.every(
      (item) =>
          item.collection.value != null &&
          item.collection.value!.path == item.path &&
          item.collection.value!.isCatalog,
    );
  }

  /// 選択中のアイテムが全てカタログであり、ティア設定可能かどうか
  bool get canApplyBulkTier => canApplyBulkTags;

  // --- 一括操作 (LibraryBatchActionController に委譲) ---

  Future<void> bulkUpdateTags(List<Tag> tags, {required bool add}) async {
    final items = state.value ?? [];
    await ref
        .read(libraryBatchActionControllerProvider.notifier)
        .bulkUpdateTags(items, tags, add: add);
  }

  Future<void> bulkUpdateTier(MediaTier tier) async {
    final items = state.value ?? [];
    await ref
        .read(libraryBatchActionControllerProvider.notifier)
        .bulkUpdateTier(items, tier);
  }

  Future<void> downloadItems(List<int> ids) async {
    final items = state.value ?? [];
    await ref
        .read(libraryBatchActionControllerProvider.notifier)
        .downloadItems(items, ids);
  }

  Future<void> shareItems(List<int> ids, {Rect? sharePositionOrigin}) async {
    final items = state.value ?? [];
    await ref
        .read(libraryBatchActionControllerProvider.notifier)
        .shareItems(items, ids, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> copyToClipboard(String text) async {
    await ref
        .read(libraryBatchActionControllerProvider.notifier)
        .copyToClipboard(text);
  }

  // --- インポート操作 (LibraryImportController に委譲) ---

  Future<void> importFiles({
    required Future<ImportCatalogOptions?> Function() askCatalogOptions,
  }) async {
    await ref
        .read(libraryImportControllerProvider.notifier)
        .importFiles(askCatalogOptions: askCatalogOptions);
  }

  Future<void> importFolder({
    required Future<ImportCatalogOptions?> Function() askCatalogOptions,
  }) async {
    await ref
        .read(libraryImportControllerProvider.notifier)
        .importFolder(askCatalogOptions: askCatalogOptions);
  }

  // --- アイテム・フォルダ操作 (LibraryItemOperationController に委譲) ---

  Future<void> createFolder(String name) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .createFolder(name);
  }

  Future<void> moveItem(MediaItem item, String? newParentPath) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .moveItem(item, newParentPath);
  }

  Future<void> duplicateItem(MediaItem item, {String? targetParentPath}) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .duplicateItem(item, targetParentPath: targetParentPath);
  }

  Future<void> renameItem(MediaItem item, String newName) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .renameItem(item, newName);
  }

  Future<void> bulkMoveItems(List<int> ids, String? newParentPath) async {
    final items = state.value ?? [];
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .bulkMoveItems(items, ids, newParentPath);
  }

  Future<void> bulkDuplicateItems(
    List<int> ids, {
    String? targetParentPath,
  }) async {
    final items = state.value ?? [];
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .bulkDuplicateItems(items, ids, targetParentPath: targetParentPath);
  }

  Future<void> deleteItem(MediaItem item) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .deleteItem(item);
  }

  Future<void> restoreDeletedItem(int itemId) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .restoreDeletedItem(itemId);
  }

  Future<void> updateItem(MediaItem item) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .updateItem(item);
  }

  Future<void> setAsFolderCover(MediaItem item) async {
    await ref
        .read(libraryItemOperationControllerProvider.notifier)
        .setAsFolderCover(item);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    ref.invalidateSelf();
    await future;
  }
}

@Riverpod(keepAlive: true)
class ExternalLibraryViewModel extends _$ExternalLibraryViewModel {
  final Set<int> _selectedIds = {};
  final Set<String> _selectedCollectionPaths = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  Set<int> get selectedIds => _selectedIds;
  Set<String> get selectedCollectionPaths => _selectedCollectionPaths;
  int get selectionCount =>
      _selectedIds.length + _selectedCollectionPaths.length;

  @override
  FutureOr<List<MediaItem>> build() {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.external));

    final itemsAsync = ref.watch(
      externalFolderItemsProvider(filter.parentPath),
    );

    return itemsAsync.when(
      data: (items) => items,
      loading: () => [],
      error: (_, _) => [],
    );
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedIds.clear();
      _selectedCollectionPaths.clear();
    }
    ref.notifyListeners();
  }

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    ref.notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectedCollectionPaths.clear();
    _isSelectionMode = false;
    ref.notifyListeners();
  }

  void deselectAll() {
    _selectedIds.clear();
    _selectedCollectionPaths.clear();
    ref.notifyListeners();
  }

  bool get areAllVisibleItemsSelected {
    final items = state.value;
    if (items == null || items.isEmpty) return false;
    return items.every((item) => _selectedIds.contains(item.id));
  }

  void selectAllVisibleItems() {
    final items = state.value;
    if (items == null || items.isEmpty) return;
    _isSelectionMode = true;
    _selectedIds
      ..clear()
      ..addAll(items.map((item) => item.id));
    ref.notifyListeners();
  }

  bool areAllVisibleContentSelected({
    required Iterable<int> visibleItemIds,
    required Iterable<String> visibleCollectionPaths,
  }) {
    final itemIds = visibleItemIds.toList(growable: false);
    final collectionPaths = visibleCollectionPaths.toList(growable: false);
    if (itemIds.isEmpty && collectionPaths.isEmpty) return false;
    return itemIds.every(_selectedIds.contains) &&
        collectionPaths.every(_selectedCollectionPaths.contains);
  }

  void selectVisibleContent({
    required Iterable<int> visibleItemIds,
    required Iterable<String> visibleCollectionPaths,
  }) {
    final itemIds = visibleItemIds.toList(growable: false);
    final collectionPaths = visibleCollectionPaths.toList(growable: false);
    if (itemIds.isEmpty && collectionPaths.isEmpty) return;
    _isSelectionMode = true;
    _selectedIds
      ..clear()
      ..addAll(itemIds);
    _selectedCollectionPaths
      ..clear()
      ..addAll(collectionPaths);
    ref.notifyListeners();
  }

  void toggleCollectionSelection(String path) {
    if (_selectedCollectionPaths.contains(path)) {
      _selectedCollectionPaths.remove(path);
    } else {
      _selectedCollectionPaths.add(path);
    }
    ref.notifyListeners();
  }

  bool get canApplyBulkTags {
    if (_selectedIds.isEmpty && _selectedCollectionPaths.isEmpty) return false;
    final items =
        state.value?.where((item) => _selectedIds.contains(item.id)).toList() ??
        [];
    if (_selectedIds.isNotEmpty) {
      if (items.isEmpty) return false;
      final allItemsAreCatalogs = items.every(
        (item) => _isCatalogCollection(item.collection.value, item.path),
      );
      if (!allItemsAreCatalogs) return false;
    }
    if (_selectedCollectionPaths.isNotEmpty) {
      final folders = ref.read(externalFolderListProvider).value ?? [];
      final registeredPaths = folders
          .where((collection) => collection.isCatalog)
          .map((collection) => collection.path)
          .toSet();
      if (!_selectedCollectionPaths.every(registeredPaths.contains)) {
        return false;
      }
    }
    return true;
  }

  bool get canApplyBulkTier => canApplyBulkTags;

  Future<void> bulkUpdateTags(List<Tag> tags, {required bool add}) async {
    if (_selectedIds.isEmpty && _selectedCollectionPaths.isEmpty) return;

    final items =
        state.value?.where((item) => _selectedIds.contains(item.id)).toList() ??
        [];

    if (items.isEmpty && _selectedCollectionPaths.isEmpty) return;

    final targetCollectionPaths = _selectedCollectionPaths.toSet();
    targetCollectionPaths.addAll(items.map((item) => item.path));
    AppLogger.i(
      LogTag.storage,
      'Bulk update tags requested: mode=external, selectedItems=${items.length}, selectedCollections=${_selectedCollectionPaths.length}, selectedTags=${tags.length}, add=$add',
    );

    final result = await ref
        .read(bulkUpdateTagsUseCaseProvider)
        .invoke(
          items: items,
          tags: tags,
          add: add,
          collectionPaths: _selectedCollectionPaths.toList(growable: false),
        );

    if (result.isFailure) {
      AppLogger.e(LogTag.storage, 'Bulk update tags (external) failed');
      throw result.errorOrNull!;
    }

    for (final path in targetCollectionPaths) {
      ref.invalidate(collectionNotifierProvider(path));
    }
    clearSelection();
    ref.invalidateSelf();
    ref.invalidate(externalFolderListProvider);
    AppLogger.i(
      LogTag.storage,
      'Bulk update tags completed: mode=external, updatedCollections=${targetCollectionPaths.length}, selectedTags=${tags.length}',
    );
  }

  Future<void> bulkUpdateTier(MediaTier tier) async {
    if (_selectedIds.isEmpty && _selectedCollectionPaths.isEmpty) return;

    final items =
        state.value?.where((item) => _selectedIds.contains(item.id)).toList() ??
        [];

    if (items.isEmpty && _selectedCollectionPaths.isEmpty) return;

    final repo = await ref.read(mediaRepositoryProvider.future);
    final collections = await _collectTargetCollections(items, repo);

    if (collections.isEmpty) {
      return;
    }

    for (final collection in collections) {
      if (collection.tier == tier.value) continue;
      collection.tier = tier.value;
      collection.updatedAt = DateTime.now();
      final saveResult = await repo.saveCollection(collection);
      if (saveResult.isFailure) {
        AppLogger.e(
          LogTag.storage,
          'Bulk update tier (external) failed: ${saveResult.errorOrNull}',
        );
        throw saveResult.errorOrNull!;
      }
    }

    for (final collection in collections) {
      ref.invalidate(collectionNotifierProvider(collection.path));
    }
    clearSelection();
    ref.invalidateSelf();
    ref.invalidate(externalFolderListProvider);
  }

  Future<MediaCollection?> _resolveWorkCollection(
    MediaItem item,
    MediaRepository repo,
    Map<String, MediaCollection?> lookupCache,
  ) async {
    await item.collection.load();
    final linkedCollection = item.collection.value;
    if (_isCatalogCollection(linkedCollection, item.path)) {
      return linkedCollection;
    }
    return _loadCollectionByPath(item.path, repo, lookupCache);
  }

  Future<MediaCollection?> _loadCollectionByPath(
    String path,
    MediaRepository repo,
    Map<String, MediaCollection?> lookupCache,
  ) async {
    final cached = lookupCache[path];
    if (lookupCache.containsKey(path)) {
      return cached;
    }

    final byPath = await repo.getCollectionByPath(path);
    final collection = byPath.dataOrNull;
    if (_isCatalogCollection(collection, path)) {
      lookupCache[path] = collection;
      return collection;
    }
    lookupCache[path] = null;
    return null;
  }

  bool _isCatalogCollection(MediaCollection? collection, String path) {
    return collection != null &&
        collection.path == path &&
        collection.isCatalog;
  }

  Future<List<MediaCollection>> _collectTargetCollections(
    List<MediaItem> items,
    MediaRepository repo,
  ) async {
    final lookupCache = <String, MediaCollection?>{};
    final collectionsByPath = <String, MediaCollection>{};

    final fromItems = await Future.wait(
      items.map((item) => _resolveWorkCollection(item, repo, lookupCache)),
    );
    for (final collection in fromItems) {
      if (collection != null) {
        collectionsByPath[collection.path] = collection;
      }
    }

    if (_selectedCollectionPaths.isNotEmpty) {
      final fromPaths = await Future.wait(
        _selectedCollectionPaths.map(
          (path) => _loadCollectionByPath(path, repo, lookupCache),
        ),
      );
      for (final collection in fromPaths) {
        if (collection != null) {
          collectionsByPath[collection.path] = collection;
        }
      }
    }

    return collectionsByPath.values.toList(growable: false);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    ref.invalidateSelf();
    await future;
  }
}
