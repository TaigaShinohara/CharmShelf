import '../../domain/models/legacy_import_labels.dart';
import '../../domain/models/tag_facet.dart';
import 'dart:async';
import 'package:private_shelf/features/library/domain/models/media_items_snapshot.dart';
import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/folder_summary.dart';
import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';

class IsarMediaRepository implements MediaRepository {
  final Isar _isar;
  final Uuid _uuid = const Uuid();

  IsarMediaRepository(this._isar, {this.legacyLabels});
  final Future<LegacyImportLabels?> Function(String originalPath)? legacyLabels;

  Future<void> _applyLegacyLabels(
    MediaItem item,
    LegacyImportLabels labels,
  ) async {
    item.isFavorite = labels.favorite;
    await _isar.mediaItems.put(item);
    if (labels.tags.isEmpty && labels.catalog.isEmpty) return;
    final col =
        (await _isar.mediaCollections
            .filter()
            .pathEqualTo(item.path)
            .findFirst()) ??
        (MediaCollection()
          ..uid = _uuid.v4()
          ..path = item.path
          ..title = p.basename(item.path)
          ..createdAt = item.addedAt);
    col.type = item.type == MediaType.folder
        ? CollectionType.folder
        : CollectionType.file;
    col.isCatalog = labels.catalog.isNotEmpty;
    if (labels.catalog.isNotEmpty) col.alias = labels.catalog;
    col.isFavorite = labels.favorite;
    await _isar.mediaCollections.put(col);
    await col.items.load();
    col.items.add(item);
    await col.items.save();
    await col.tags.load();
    var facet = await _isar.tagFacets.filter().nameEqualTo('未分類').findFirst();
    facet ??= TagFacet()
      ..name = '未分類'
      ..createdAt = DateTime.now();
    await _isar.tagFacets.put(facet);
    for (final name in labels.tags) {
      final key = Tag.buildKey(facet.id, name);
      final tag =
          (await _isar.tags.filter().keyEqualTo(key).findFirst()) ??
          (Tag()
            ..key = key
            ..name = name
            ..facetId = facet.id
            ..createdAt = DateTime.now());
      if (!col.tags.any((t) => t.key == key)) {
        tag.usageCount++;
        await _isar.tags.put(tag);
        col.tags.add(tag);
      }
    }
    await col.tags.save();
    await _upsertStorageRefForCollectionInTxn(col);
  }

  String _ensureUid(String? value) {
    if (value != null && value.isNotEmpty) return value;
    return _uuid.v4();
  }

  void _ensureItemUids(List<MediaItem> items) {
    for (final item in items) {
      if (item.uid == null || item.uid!.isEmpty) {
        item.uid = _ensureUid(item.uid);
      }
    }
  }

  void _ensureCollectionUids(List<MediaCollection> collections) {
    for (final collection in collections) {
      if (collection.uid == null || collection.uid!.isEmpty) {
        collection.uid = _ensureUid(collection.uid);
      }
    }
  }

  String _normalizeLocator(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'file') {
        return p.normalize(uri.toFilePath());
      }
      return uri.toString();
    }
    return p.normalize(value);
  }

  StorageSourceType _sourceTypeForItem(MediaItem item) {
    return item.sourceType == MediaSourceType.externalReference
        ? StorageSourceType.external
        : StorageSourceType.local;
  }

  StorageSourceType _sourceTypeForCollection(MediaCollection collection) {
    return collection.type == CollectionType.externalFolder
        ? StorageSourceType.external
        : StorageSourceType.local;
  }

  Future<StorageRef> _upsertStorageRefForItemInTxn(MediaItem item) async {
    final uid = item.uid = _ensureUid(item.uid);
    final locator = item.path;
    final normalized = _normalizeLocator(locator);
    final existing = await _isar.storageRefs
        .filter()
        .ownerUidEqualTo(uid)
        .ownerTypeEqualTo(StorageOwnerType.item)
        .isPrimaryEqualTo(true)
        .findFirst();
    if (existing != null) {
      existing
        ..sourceType = _sourceTypeForItem(item)
        ..locator = locator
        ..normalizedLocator = normalized
        ..updatedAt = DateTime.now();
      await _isar.storageRefs.put(existing);
      return existing;
    }
    final ref = StorageRef()
      ..uid = _ensureUid(null)
      ..ownerUid = uid
      ..ownerType = StorageOwnerType.item
      ..sourceType = _sourceTypeForItem(item)
      ..locator = locator
      ..normalizedLocator = normalized
      ..isPrimary = true
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await _isar.storageRefs.put(ref);
    return ref;
  }

  Future<StorageRef> _upsertStorageRefForCollectionInTxn(
    MediaCollection collection,
  ) async {
    final uid = collection.uid = _ensureUid(collection.uid);
    final locator = collection.path;
    final normalized = _normalizeLocator(locator);
    final existing = await _isar.storageRefs
        .filter()
        .ownerUidEqualTo(uid)
        .ownerTypeEqualTo(StorageOwnerType.collection)
        .isPrimaryEqualTo(true)
        .findFirst();
    if (existing != null) {
      existing
        ..sourceType = _sourceTypeForCollection(collection)
        ..locator = locator
        ..normalizedLocator = normalized
        ..updatedAt = DateTime.now();
      await _isar.storageRefs.put(existing);
      return existing;
    }
    final ref = StorageRef()
      ..uid = _ensureUid(null)
      ..ownerUid = uid
      ..ownerType = StorageOwnerType.collection
      ..sourceType = _sourceTypeForCollection(collection)
      ..locator = locator
      ..normalizedLocator = normalized
      ..isPrimary = true
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await _isar.storageRefs.put(ref);
    return ref;
  }

  /// 安全にDB操作を実行するヘルパーメソッド
  ///
  /// エラー発生時にログ出力を行い、Result.failureを返します。
  /// コンテキスト情報を追加してエラーの追跡を容易にします。
  Future<Result<T, AppError>> _safeRun<T>(
    Future<T> Function() action,
    String operationName, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final result = await action();
      return Result.success(result);
    } catch (e, st) {
      AppLogger.e(LogTag.db, '$operationName failed', e, st);
      return Result.failure(
        AppError.database(
          '$operationName failed: $e',
          original: e,
          stackTrace: st,
          context: 'IsarMediaRepository.$operationName',
        ).withAdditionalData(additionalData ?? {}),
      );
    }
  }

  Future<void> _validateLibraryWrite(MediaItem item) async {
    if (item.isImportPreview) {
      throw StateError('Import previews cannot be saved');
    }
    if (item.sourceType == MediaSourceType.localCopy &&
        (p.isAbsolute(item.path) ||
            Uri.tryParse(item.path)?.hasScheme == true)) {
      throw StateError('Library copies must use managed relative paths');
    }
    if (item.sourceType == MediaSourceType.externalReference) {
      final old = await _isar.mediaItems.get(item.id);
      if (old == null ||
          old.sourceType != item.sourceType ||
          old.path != item.path) {
        throw StateError('External reference registration has been retired');
      }
    }
  }

  @override
  Future<Result<void, AppError>> save(MediaItem item) {
    return _safeRun(
      () async {
        await _validateLibraryWrite(item);
        final previous = await _isar.mediaItems.get(item.id);
        final labels =
            item.sourceType == MediaSourceType.localCopy &&
                item.originalPath.isNotEmpty &&
                (previous == null || previous.originalPath.isEmpty)
            ? await legacyLabels?.call(item.originalPath)
            : null;
        item.uid = _ensureUid(item.uid);
        await _isar.writeTxn(() async {
          await _isar.mediaItems.put(item);
          await _upsertStorageRefForItemInTxn(item);
          if (labels != null) await _applyLegacyLabels(item, labels);
          await CollectionItemLinkService(_isar).linkItemInTransaction(item);
        });
      },
      'Save MediaItem',
      additionalData: {'itemId': item.id, 'path': item.path},
    );
  }

  @override
  Future<Result<void, AppError>> saveGeneratedThumbnailPath(
    int id,
    String itemPath,
    String thumbnailPath,
  ) {
    return _safeRun(
      () async {
        await _isar.writeTxn(() async {
          final current = await _isar.mediaItems.get(id);
          if (current == null ||
              current.path != itemPath ||
              current.thumbnailPath?.isNotEmpty == true) {
            return;
          }
          current.thumbnailPath = thumbnailPath;
          await _isar.mediaItems.put(current);
        }, silent: true);
      },
      'Save generated thumbnail path',
      additionalData: {'itemId': id},
    );
  }

  @override
  Future<Result<void, AppError>> saveAll(List<MediaItem> items) {
    return _safeRun(() async {
      for (final item in items) {
        await _validateLibraryWrite(item);
        item.uid = _ensureUid(item.uid);
      }
      await _isar.writeTxn(() async {
        await _isar.mediaItems.putAll(items);
        for (final item in items) {
          await _upsertStorageRefForItemInTxn(item);
          await CollectionItemLinkService(_isar).linkItemInTransaction(item);
        }
      });
    }, 'SaveAll MediaItems');
  }

  @override
  Future<Result<MediaItem?, AppError>> getById(int id) {
    return _safeRun(
      () async {
        final item = await _isar.mediaItems.get(id);
        if (item == null) return null;
        if (item.uid == null || item.uid!.isEmpty) {
          item.uid = _ensureUid(item.uid);
        }
        return item;
      },
      'GetById MediaItem',
      additionalData: {'id': id},
    );
  }

  @override
  Future<Result<MediaItem?, AppError>> getByUid(String uid) {
    return _safeRun(
      () async {
        return _isar.mediaItems.filter().uidEqualTo(uid).findFirst();
      },
      'GetByUid MediaItem',
      additionalData: {'uid': uid},
    );
  }

  /// 全件取得（検証用・初期ロード用）
  @override
  Stream<void> watchLibraryChanges({required MediaFilter filter}) =>
      Stream<void>.multi((controller) {
        final itemChanges = _usesCatalogSearch(filter)
            ? _isar.mediaItems.watchLazy()
            : _buildMediaQuery(filter).watchLazy();
        final items = itemChanges.listen(
          (_) => controller.add(null),
          onError: controller.addError,
        );
        final collections = _isar.mediaCollections.watchLazy().listen(
          (_) => controller.add(null),
          onError: controller.addError,
        );
        controller.onCancel = () async {
          await items.cancel();
          await collections.cancel();
        };
      });

  @override
  Future<Result<List<MediaItem>, AppError>> getPage({
    required MediaFilter filter,
    required int offset,
    required int limit,
  }) => _safeRun(() async {
    if (offset < 0 || limit <= 0) throw ArgumentError('Invalid page bounds');
    final pageFilter = filter.copyWith(limit: limit);
    if (!_usesCatalogSearch(filter) &&
        !await _hasPinnedItemsForFilter(filter)) {
      final query = _buildMediaQuery(filter);
      if (filter.sortOrder == SortOrder.addedDesc) {
        final items = await _executeDefaultCandidates(
          query,
          limit,
          offset: offset,
        );
        return _sortAndLoadItems(items, pageFilter);
      }
      if (_supportsDatabaseSort(filter.sortOrder)) {
        final items = await _executeDatabaseSorted(
          query,
          filter.sortOrder,
          limit,
          offset: offset,
        );
        return _sortAndLoadItems(items, pageFilter);
      }
    }
    // Related-metadata sorts and pinned legacy links require a global ordering.
    // Keep their correct ordering; only ordinary pages use the fast delta path.
    final result = await getAll(filter: filter.copyWith(limit: offset + limit));
    if (result.isFailure) throw result.errorOrNull!;
    return result.dataOrNull!.skip(offset).take(limit).toList();
  }, 'GetPage');

  @override
  Future<Result<List<MediaItem>, AppError>> getAll({MediaFilter? filter}) {
    return _safeRun(() async {
      if (_usesCatalogSearch(filter)) {
        final items = await _getCatalogItems(filter!);
        return items;
      }
      final query = _buildMediaQuery(filter);
      final items = await _applySortAndExecute(query, filter);
      return items;
    }, 'GetAll');
  }

  @override
  Stream<List<MediaItem>> watchAll({MediaFilter? filter}) {
    if (_usesCatalogSearch(filter)) {
      return _watchLatest(
        triggers: [
          _isar.mediaCollections.watchLazy(fireImmediately: true),
          _isar.mediaItems.watchLazy(fireImmediately: false),
        ],
        load: () => _getCatalogItems(filter!),
      );
    }

    final query = _buildMediaQuery(filter).build();
    final watchVisibleCollections = _canWatchVisibleCollections(filter);
    return _watchLatest(
      triggers: [
        query.watchLazy(fireImmediately: true),
        watchVisibleCollections
            ? _isar.mediaCollections
                  .filter()
                  .isPinnedEqualTo(true)
                  .watchLazy(fireImmediately: false)
            : _isar.mediaCollections.watchLazy(fireImmediately: false),
      ],
      load: () => _applySortAndExecute(_buildMediaQuery(filter), filter),
      suppressUnchangedResults: true,
      visibleCollectionTrigger: watchVisibleCollections
          ? (items) {
              final paths = <String>{};
              for (final item in items) {
                paths.add(item.path);
                if (item.parentPath != null) paths.add(item.parentPath!);
                final linkedPath = item.collection.value?.path;
                if (linkedPath != null) paths.add(linkedPath);
              }
              return (
                paths: paths,
                stream: paths.isEmpty
                    ? const Stream<void>.empty()
                    : _isar.mediaCollections
                          .filter()
                          .anyOf(
                            paths.toList(growable: false),
                            (q, String path) => q.pathEqualTo(path),
                          )
                          .watchLazy(fireImmediately: false),
              );
            }
          : null,
    );
  }

  bool _canWatchVisibleCollections(MediaFilter? filter) {
    if (filter == null || filter.onlyCatalogs) return false;
    if (filter.searchQuery?.trim().isNotEmpty == true ||
        filter.tagIds?.isNotEmpty == true ||
        filter.excludedTagIds?.isNotEmpty == true ||
        filter.tiers?.isNotEmpty == true ||
        filter.hasTags != null ||
        filter.isFavorite != null) {
      return false;
    }
    return _supportsDatabaseSort(filter.sortOrder);
  }

  bool _usesCatalogSearch(MediaFilter? filter) {
    if (filter == null) return false;
    final hasSearchQuery = filter.searchQuery?.trim().isNotEmpty ?? false;
    return hasSearchQuery
        ? filter.effectiveSearchTarget == SearchTarget.catalogsOnly
        : filter.onlyCatalogs;
  }

  Stream<List<MediaItem>> _watchLatest({
    required List<Stream<void>> triggers,
    required Future<List<MediaItem>> Function() load,
    bool suppressUnchangedResults = false,
    ({Set<String> paths, Stream<void> stream}) Function(List<MediaItem>)?
    visibleCollectionTrigger,
  }) {
    late final StreamController<List<MediaItem>> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var generation = 0;
    var isLoading = false;
    var pending = false;
    Timer? reloadTimer;
    var firstTrigger = true;
    List<Object?>? previousSnapshot;
    StreamSubscription<void>? visibleCollectionSubscription;
    var watchedPaths = <String>{};
    late void Function() scheduleReload;

    Future<void> emitLatest() async {
      generation++;
      pending = true;
      if (isLoading) return;

      isLoading = true;
      try {
        while (pending && !controller.isClosed) {
          pending = false;
          final currentGeneration = generation;
          try {
            final items = await load();
            if (!controller.isClosed && currentGeneration == generation) {
              if (visibleCollectionTrigger != null) {
                final visible = visibleCollectionTrigger(items);
                if (visible.paths.length != watchedPaths.length ||
                    !watchedPaths.containsAll(visible.paths)) {
                  final previous = visibleCollectionSubscription;
                  visibleCollectionSubscription = visible.stream.listen(
                    (_) => scheduleReload(),
                  );
                  watchedPaths = visible.paths;
                  await previous?.cancel();
                  if (controller.isClosed || currentGeneration != generation) {
                    continue;
                  }
                }
              }
              if (!controller.isClosed && currentGeneration == generation) {
                final snapshot = suppressUnchangedResults
                    ? mediaItemsSnapshot(items)
                    : null;
                if (!suppressUnchangedResults ||
                    !const DeepCollectionEquality().equals(
                      previousSnapshot,
                      snapshot,
                    )) {
                  previousSnapshot = snapshot;
                  controller.add(items);
                }
              }
            }
          } catch (e, st) {
            if (!controller.isClosed && currentGeneration == generation) {
              // A successful reload must clear the consumer's error state,
              // even when it returns the same items as before the failure.
              previousSnapshot = null;
              controller.addError(e, st);
            }
          }
        }
      } finally {
        isLoading = false;
      }
    }

    scheduleReload = () {
      if (firstTrigger) {
        firstTrigger = false;
        unawaited(emitLatest());
        return;
      }
      reloadTimer?.cancel();
      reloadTimer = Timer(
        const Duration(milliseconds: 40),
        () => unawaited(emitLatest()),
      );
    };

    controller = StreamController<List<MediaItem>>.broadcast(
      onListen: () {
        for (final trigger in triggers) {
          subscriptions.add(trigger.listen((_) => scheduleReload()));
        }
      },
      onCancel: () {
        generation++;
        reloadTimer?.cancel();
        unawaited(visibleCollectionSubscription?.cancel());
        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getRecentMedia({
    int limit = 10,
    MediaSourceType? sourceType,
    bool? isHidden,
  }) {
    return _safeRun(
      () => _queryRecentMedia(
        limit: limit,
        sourceType: sourceType,
        isHidden: isHidden,
      ),
      'GetRecentMedia',
    );
  }

  @override
  Stream<List<MediaItem>> watchRecentMedia({
    int limit = 10,
    MediaSourceType? sourceType,
    bool? isHidden,
  }) {
    late final StreamController<List<MediaItem>> controller;
    StreamSubscription<void>? itemSubscription;
    StreamSubscription<void>? collectionSubscription;
    var generation = 0;

    Future<void> emitLatest() async {
      final currentGeneration = ++generation;
      try {
        final items = await _queryRecentMedia(
          limit: limit,
          sourceType: sourceType,
          isHidden: isHidden,
        );
        if (!controller.isClosed && currentGeneration == generation) {
          controller.add(items);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed && currentGeneration == generation) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<List<MediaItem>>.broadcast(
      onListen: () {
        collectionSubscription = _isar.mediaCollections
            .watchLazy(fireImmediately: true)
            .listen((_) => unawaited(emitLatest()));
        itemSubscription = _isar.mediaItems
            .watchLazy(fireImmediately: false)
            .listen((_) => unawaited(emitLatest()));
      },
      onCancel: () {
        generation++;
        itemSubscription?.cancel();
        collectionSubscription?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Future<List<MediaItem>> _queryRecentMedia({
    required int limit,
    required MediaSourceType? sourceType,
    required bool? isHidden,
  }) async {
    if (limit <= 0) return const [];

    final result = <MediaItem>[];
    final batchSize = limit < 10 ? 20 : limit * 2;
    var offset = 0;

    while (result.length < limit) {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .lastViewedAtIsNotNull()
          .lastViewedItemIdIsNotNull()
          .not()
          .pathEqualTo('library');

      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      }
      if (sourceType == MediaSourceType.externalReference) {
        query = query.typeEqualTo(CollectionType.externalFolder);
      } else if (sourceType == MediaSourceType.localCopy) {
        query = query.not().typeEqualTo(CollectionType.externalFolder);
      }

      final collections = await query
          .sortByLastViewedAtDesc()
          .offset(offset)
          .limit(batchSize)
          .findAll();
      if (collections.isEmpty) break;
      offset = offset + collections.length;

      final ids = collections
          .map((collection) => collection.lastViewedItemId!)
          .toList(growable: false);
      final items = await _isar.mediaItems.getAll(ids);
      for (var index = 0; index < collections.length; index++) {
        final item = items[index];
        if (item == null || item.isTrashed || item.isArchived) continue;
        if (sourceType != null && item.sourceType != sourceType) continue;
        if (isHidden != null && item.isHidden != isHidden) continue;
        item.collection.value = collections[index];
        result.add(item);
        if (result.length == limit) break;
      }

      if (collections.length < batchSize) break;
    }

    _ensureItemUids(result);
    return result;
  }

  /// カタログ一覧モード用のアイテム取得ロジック
  Future<List<MediaItem>> _getCatalogItems(MediaFilter filter) async {
    var colQuery = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isCatalogEqualTo(true);

    // 基本フィルタの適用
    if (filter.isArchived != null) {
      colQuery = colQuery.isArchivedEqualTo(filter.isArchived!);
    }
    if (filter.isHidden != null) {
      colQuery = colQuery.isHiddenEqualTo(filter.isHidden!);
    }
    if (filter.isFavorite != null) {
      colQuery = colQuery.isFavoriteEqualTo(filter.isFavorite!);
    }
    if (filter.sourceType == MediaSourceType.externalReference) {
      colQuery = colQuery.typeEqualTo(CollectionType.externalFolder);
    } else if (filter.sourceType == MediaSourceType.localCopy) {
      colQuery = colQuery.not().typeEqualTo(CollectionType.externalFolder);
    }

    // ティアフィルタ
    if (filter.tiers != null && filter.tiers!.isNotEmpty) {
      colQuery = colQuery.group((q) {
        return q.anyOf(filter.tiers!, (q, int tier) => q.tierEqualTo(tier));
      });
    }

    // タグフィルタ
    if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
      for (final tagId in filter.tagIds!) {
        colQuery = colQuery.tags(
          (t) => t.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
        );
      }
    }

    // 除外タグ
    if (filter.excludedTagIds != null && filter.excludedTagIds!.isNotEmpty) {
      for (final tagId in filter.excludedTagIds!) {
        colQuery = colQuery.not().tags(
          (t) => t.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
        );
      }
    }

    if (filter.hasTags == true) {
      colQuery = colQuery.tagsLengthGreaterThan(0);
    } else if (filter.hasTags == false) {
      colQuery = colQuery.tagsLengthEqualTo(0);
    }

    // 検索クエリ
    final searchQuery = filter.searchQuery?.trim();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final words = searchQuery
          .split(RegExp(r'[\s　]+'))
          .where((w) => w.isNotEmpty);
      for (final word in words) {
        colQuery = colQuery.group((q) {
          return q
              .titleContains(word, caseSensitive: false)
              .or()
              .aliasContains(word, caseSensitive: false)
              .or()
              .notesContains(word, caseSensitive: false)
              .or()
              .pathContains(word, caseSensitive: false)
              .or()
              .tags((tag) => tag.nameContains(word, caseSensitive: false));
        });
      }
    }

    // コレクションを取得
    final loadedCollections = await colQuery.findAll();
    final collections = filter.keepsParentWhileSearching
        ? loadedCollections.where((collection) {
            final parent = filter.parentPath!.replaceAll('\\', '/');
            final path = collection.path.replaceAll('\\', '/');
            return p.dirname(path) == parent;
          }).toList()
        : loadedCollections;
    if (collections.isEmpty) return [];

    final rawPaths = collections.map((c) => c.path).toSet();
    final searchPaths = <String>{};
    for (final p in rawPaths) {
      searchPaths.add(p);
      final normalized = p.replaceAll('\\', '/');
      searchPaths.add(normalized);
      if (normalized.startsWith('library/')) {
        searchPaths.add(normalized.substring('library/'.length));
      } else {
        searchPaths.add('library/$normalized');
      }
    }

    // 対応する MediaItem を取得
    var itemQuery = _isar.mediaItems
        .filter()
        .isTrashedEqualTo(false)
        .anyOf(
          searchPaths.toList(growable: false),
          (q, String p) => q.pathEqualTo(p),
        );

    // 非表示・アーカイブフィルターの適用
    if (filter.isArchived != null) {
      itemQuery = itemQuery.isArchivedEqualTo(filter.isArchived!);
    }
    if (filter.isHidden != null) {
      itemQuery = itemQuery.isHiddenEqualTo(filter.isHidden!);
    }

    // メディアタイプなどの追加フィルターがあれば適用
    if (filter.mediaTypes != null && filter.mediaTypes!.isNotEmpty) {
      itemQuery = itemQuery.anyOf(
        filter.mediaTypes!,
        (q, MediaType type) => q.typeEqualTo(type),
      );
    }

    final limit = filter.limit;
    List<MediaItem> items;
    if (limit != null && limit > 0 && _supportsDatabaseSort(filter.sortOrder)) {
      items = await _executeDatabaseSorted(itemQuery, filter.sortOrder, limit);
      final pinnedPaths = await _isar.mediaCollections
          .filter()
          .isPinnedEqualTo(true)
          .pathProperty()
          .findAll();
      if (pinnedPaths.isNotEmpty) {
        final pinnedItems = await itemQuery
            .group(
              (q) => q
                  .collection((cq) => cq.isPinnedEqualTo(true))
                  .or()
                  .anyOf(pinnedPaths, (q, String path) => q.pathEqualTo(path)),
            )
            .findAll();
        final byId = <Id, MediaItem>{for (final item in items) item.id: item};
        for (final item in pinnedItems) {
          byId[item.id] = item;
        }
        items = byId.values.toList();
      }
    } else {
      items = await itemQuery.findAll();
    }

    // 最適化: 取得済みのコレクションをマップ化して _sortAndLoadItems に渡す
    final collectionByPath = <String, MediaCollection>{};
    for (final c in collections) {
      collectionByPath[c.path] = c;
      final normalized = c.path.replaceAll('\\', '/');
      collectionByPath[normalized] = c;
      if (normalized.startsWith('library/')) {
        collectionByPath[normalized.substring('library/'.length)] = c;
      } else {
        collectionByPath['library/$normalized'] = c;
      }
    }

    // ソートと関連データのロード
    return _sortAndLoadItems(
      items,
      filter,
      preloadedCollections: collectionByPath,
    );
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> _buildMediaQuery(
    MediaFilter? filter,
  ) {
    final searching = filter?.searchQuery?.trim().isNotEmpty == true;
    // 検索中の範囲は、通常一覧のカタログ表示設定と独立して適用する。
    final restrictToHierarchy =
        filter != null &&
        (searching ? filter.searchWithinParent : !filter.onlyCatalogs);
    final indexedParentPath = restrictToHierarchy ? filter.parentPath : null;
    var query = indexedParentPath != null
        ? _isar.mediaItems
              .where()
              .parentPathEqualTo(indexedParentPath)
              .filter()
              .isTrashedEqualTo(false)
              .idGreaterThan(-1)
        : _isar.mediaItems.filter().isTrashedEqualTo(false).idGreaterThan(-1);

    if (filter != null) {
      if (filter.isArchived != null) {
        query = query.isArchivedEqualTo(filter.isArchived!);
      }

      if (filter.isHidden != null) {
        query = query.isHiddenEqualTo(filter.isHidden!);
      }

      final searchQuery = filter.searchQuery?.trim();
      final hasSearchQuery = searchQuery != null && searchQuery.isNotEmpty;

      // 通常のカタログ一覧と棚全体の検索では、親パスの制限を外す。
      if (restrictToHierarchy) {
        if (filter.parentPath != null) {
          if (indexedParentPath == null) {
            query = query.parentPathEqualTo(filter.parentPath);
          }
        } else if (filter.rootOnly == true) {
          // or() を外部に出すと全体の isArchivedEqualTo(false) と競合するため、
          // group() 内で処理して論理構造を保護する
          query = query.group(
            (q) => q
                .parentPathIsNull()
                .or()
                .parentPathEqualTo('')
                .or()
                .parentPathEqualTo('library'),
          );
        }
      }

      if (filter.onlyCatalogs == true) {
        // worksモードの時は _buildMediaQuery では限定的なフィルタのみ行い、
        // 実際の抽出は _getCatalogItems で行うため、ここではカタログ抽出条件を削除
      }

      if (hasSearchQuery) {
        final words = searchQuery
            .split(RegExp(r'[\s　]+'))
            .where((w) => w.isNotEmpty);
        for (final word in words) {
          query = query.group((q) {
            return q
                .pathContains(word, caseSensitive: false)
                .or()
                .collection(
                  (cq) => cq
                      .titleContains(word, caseSensitive: false)
                      .or()
                      .aliasContains(word, caseSensitive: false)
                      .or()
                      .notesContains(word, caseSensitive: false)
                      .or()
                      .tags(
                        (tag) => tag.nameContains(word, caseSensitive: false),
                      ),
                );
          });
        }
      }

      if (filter.tiers != null && filter.tiers!.isNotEmpty) {
        query = query.collection(
          (q) => q.anyOf(filter.tiers!, (q, int tier) => q.tierEqualTo(tier)),
        );
      }

      if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
        for (final tagId in filter.tagIds!) {
          query = query.collection(
            (q) => q.tags(
              (t) => t.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
            ),
          );
        }
      }

      if (filter.excludedTagIds != null && filter.excludedTagIds!.isNotEmpty) {
        for (final tagId in filter.excludedTagIds!) {
          query = query.not().collection(
            (q) => q.tags(
              (t) => t.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
            ),
          );
        }
      }

      if (filter.hasTags == true) {
        query = query.collection((q) => q.tagsLengthGreaterThan(0));
      } else if (filter.hasTags == false) {
        query = query.collection((q) => q.tagsLengthEqualTo(0));
      }

      if (filter.isFavorite != null) {
        query = query.group(
          (q) => q
              .isFavoriteEqualTo(filter.isFavorite!)
              .or()
              .collection((cq) => cq.isFavoriteEqualTo(filter.isFavorite!)),
        );
      }

      if (filter.mediaTypes != null && filter.mediaTypes!.isNotEmpty) {
        query = query.anyOf(
          filter.mediaTypes!,
          (q, MediaType type) => q.typeEqualTo(type),
        );
      }

      // データソース
      if (filter.sourceType != null) {
        query = query.sourceTypeEqualTo(filter.sourceType!);
      }

      if (filter.path != null) {
        query = query.pathEqualTo(filter.path!);
      }
    }
    return query;
  }

  Future<List<MediaItem>> _applySortAndExecute(
    QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> query,
    MediaFilter? filter,
  ) async {
    final limit = filter?.limit;
    final sortOrder = filter?.sortOrder ?? SortOrder.addedDesc;
    if (limit != null &&
        limit > 0 &&
        (_supportsDatabaseSort(sortOrder) ||
            sortOrder == SortOrder.addedDesc)) {
      final hasPinned = await _hasPinnedItemsForFilter(filter);
      final items = sortOrder == SortOrder.addedDesc
          ? await _executeDefaultCandidates(query, limit)
          : await _executeDatabaseSorted(query, sortOrder, limit);
      if (!hasPinned) return _sortAndLoadItems(items, filter);

      // 古い関連付けを含むピン留めだけを追加取得し、全件ロードを避ける。
      final pinnedItems = await _buildMediaQuery(
        filter,
      ).collection((q) => q.isPinnedEqualTo(true)).findAll();
      final pinnedPaths = await _isar.mediaCollections
          .filter()
          .isPinnedEqualTo(true)
          .pathProperty()
          .findAll();
      if (pinnedPaths.isNotEmpty) {
        pinnedItems.addAll(
          await _buildMediaQuery(filter)
              .group(
                (q) => q
                    .anyOf(pinnedPaths, (q, String path) => q.pathEqualTo(path))
                    .or()
                    .anyOf(
                      pinnedPaths,
                      (q, String path) => q.parentPathEqualTo(path),
                    ),
              )
              .findAll(),
        );
      }
      final byId = <Id, MediaItem>{for (final item in items) item.id: item};
      for (final item in pinnedItems) {
        byId[item.id] = item;
      }
      return _sortAndLoadItems(byId.values.toList(), filter);
    }
    final items = await query.build().findAll();
    return _sortAndLoadItems(items, filter);
  }

  /// Each category contributes at most one page. Cutting a single date-sorted
  /// query first would lose older folders/catalogs that precede newer files.
  Future<List<MediaItem>> _executeDefaultCandidates(
    QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> query,
    int limit, {
    int offset = 0,
  }) async {
    final catalogPaths = await _isar.mediaCollections
        .filter()
        .isCatalogEqualTo(true)
        .pathProperty()
        .findAll();
    final ordinary = catalogPaths.isEmpty
        ? query
        : query.not().anyOf(
            catalogPaths,
            (q, String path) => q.pathEqualTo(path),
          );
    final result = <MediaItem>[];
    var skip = offset;
    Future<void> takeCategory(
      QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> category,
    ) async {
      final remaining = limit - result.length;
      if (remaining <= 0) return;
      if (skip > 0) {
        final count = await category.count();
        if (skip >= count) {
          skip -= count;
          return;
        }
      }
      result.addAll(
        await category
            .sortByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(skip)
            .limit(remaining)
            .findAll(),
      );
      skip = 0;
    }

    await takeCategory(ordinary.typeEqualTo(MediaType.folder));
    if (catalogPaths.isNotEmpty) {
      await takeCategory(
        query.anyOf(catalogPaths, (q, String path) => q.pathEqualTo(path)),
      );
    }
    await takeCategory(ordinary.typeEqualTo(MediaType.file));
    return result;
  }

  Future<bool> _hasPinnedItemsForFilter(MediaFilter? filter) async {
    final allPinnedPaths = await _isar.mediaCollections
        .filter()
        .isPinnedEqualTo(true)
        .pathProperty()
        .findAll();
    if (allPinnedPaths.isEmpty) return false;

    // 内部フォルダの一覧には、フォルダ自身と直下の項目のピン留めだけが影響する。
    // 他のフォルダに多数のピン留めがあっても全件取得へ切り替えない。
    final parentPath = filter?.parentPath;
    final paths =
        filter?.sourceType == MediaSourceType.localCopy &&
            parentPath != null &&
            (filter?.searchQuery?.trim().isNotEmpty != true ||
                filter?.searchWithinParent == true) &&
            filter?.onlyCatalogs != true
        ? allPinnedPaths
              .where(
                (path) => path == parentPath || p.dirname(path) == parentPath,
              )
              .toList()
        : allPinnedPaths;

    // ピン留めが多い場合は従来の全件ソートに戻し、判定用クエリが
    // かえって高コストになるのを避ける。
    if (paths.length > 8) return true;

    // アイテムとコレクションの関連がパスと一致しない古いデータも対象にする。
    if (await _buildMediaQuery(
          filter,
        ).collection((q) => q.isPinnedEqualTo(true)).findFirst() !=
        null) {
      return true;
    }
    if (paths.isEmpty) return false;
    if (await _buildMediaQuery(
          filter,
        ).anyOf(paths, (q, String path) => q.pathEqualTo(path)).findFirst() !=
        null) {
      return true;
    }
    return await _buildMediaQuery(filter)
            .anyOf(paths, (q, String path) => q.parentPathEqualTo(path))
            .findFirst() !=
        null;
  }

  bool _supportsDatabaseSort(SortOrder sortOrder) {
    return switch (sortOrder) {
      SortOrder.addedAsc ||
      SortOrder.dateAsc ||
      SortOrder.dateDesc ||
      SortOrder.updatedAsc ||
      SortOrder.updatedDesc ||
      SortOrder.nameAsc ||
      SortOrder.nameDesc => true,
      _ => false,
    };
  }

  Future<List<MediaItem>> _executeDatabaseSorted(
    QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> query,
    SortOrder sortOrder,
    int limit, {
    int offset = 0,
  }) {
    return switch (sortOrder) {
      SortOrder.addedAsc || SortOrder.dateAsc =>
        query
            .sortByAddedAt()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
      SortOrder.updatedAsc =>
        query
            .sortByUpdatedAt()
            .thenByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
      SortOrder.updatedDesc =>
        query
            .sortByUpdatedAtDesc()
            .thenByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
      SortOrder.nameAsc =>
        query
            .sortByPath()
            .thenByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
      SortOrder.nameDesc =>
        query
            .sortByPathDesc()
            .thenByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
      _ =>
        query
            .sortByAddedAtDesc()
            .thenByPath()
            .thenByUid()
            .offset(offset)
            .limit(limit)
            .findAll(),
    };
  }

  Future<List<MediaItem>> _sortAndLoadItems(
    List<MediaItem> items,
    MediaFilter? filter, {
    Map<String, MediaCollection>? preloadedCollections,
  }) async {
    final sortOrder = filter?.sortOrder ?? SortOrder.addedDesc;

    // フォルダ（カタログ）とファイルのコレクションを一括ロードし、マップを作成
    final collectionMap = preloadedCollections ?? <String, MediaCollection>{};

    if (preloadedCollections == null && items.isNotEmpty) {
      final allRelevantPaths = <String>{};
      for (final item in items) {
        allRelevantPaths.add(item.path);
        if (item.parentPath != null && item.parentPath!.isNotEmpty) {
          allRelevantPaths.add(item.parentPath!);
        }
      }
      if (allRelevantPaths.isNotEmpty) {
        final collections = await _isar.mediaCollections
            .filter()
            .anyOf(
              allRelevantPaths.toList(growable: false),
              (q, String path) => q.pathEqualTo(path),
            )
            .findAll();
        for (final col in collections) {
          collectionMap[col.path] = col;
        }
      }
    }

    // 各アイテムにコレクション（自身または親）をセット
    for (final item in items) {
      final col =
          collectionMap[item.path] ??
          (item.parentPath != null && item.parentPath!.isNotEmpty
              ? collectionMap[item.parentPath!]
              : null);
      if (col != null) {
        item.collection.value = col;
      }
    }

    // Most loose files have no backlink. Resolve which links exist in bounded
    // batches instead of issuing one empty link query per file. Legacy links
    // whose catalog path differs from the item/parent still participate in sort.
    final unresolved = items
        .where(
          (item) =>
              !collectionMap.containsKey(item.path) &&
              item.collection.value == null,
        )
        .toList(growable: false);
    for (var start = 0; start < unresolved.length; start += 256) {
      final batch = unresolved.skip(start).take(256).toList(growable: false);
      final linkedIds =
          (await _isar.mediaItems
                  .filter()
                  .anyOf(
                    batch.map((item) => item.id).toList(),
                    (q, Id id) => q.idEqualTo(id),
                  )
                  .not()
                  .collectionIsNull()
                  .idProperty()
                  .findAll())
              .toSet();
      final linked = batch
          .where((item) => linkedIds.contains(item.id))
          .toList();
      for (var offset = 0; offset < linked.length; offset += 32) {
        await Future.wait(
          linked.skip(offset).take(32).map((item) => item.collection.load()),
        );
      }
    }

    items.sort((a, b) {
      // 1. マップ（カタログ自身）にあるか、2. バックリンク（カタログの中身）にあるか
      final collectionA = collectionMap[a.path] ?? a.collection.value;
      final collectionB = collectionMap[b.path] ?? b.collection.value;

      // 1. ピン留め状態を最優先
      final pinnedA = collectionA?.isPinned ?? false;
      final pinnedB = collectionB?.isPinned ?? false;
      if (pinnedA != pinnedB) {
        return pinnedA ? -1 : 1;
      }

      // デフォルト表示では、通常フォルダ・カタログ・通常ファイルの順にする。
      // カタログは、アイテム自身をコレクションとして登録しているものだけを指す。
      // （フォルダ内のファイルが親カタログに属しているだけの場合は通常ファイル。）
      if (sortOrder == SortOrder.addedDesc) {
        final categoryA = _defaultDisplayCategory(a, collectionA);
        final categoryB = _defaultDisplayCategory(b, collectionB);
        if (categoryA != categoryB) return categoryA.compareTo(categoryB);
      }

      var cmp = 0;

      switch (sortOrder) {
        case SortOrder.addedAsc:
          cmp = a.addedAt.compareTo(b.addedAt);
          break;
        case SortOrder.addedDesc:
        case SortOrder.dateDesc:
          cmp = b.addedAt.compareTo(a.addedAt);
          break;
        case SortOrder.updatedAsc:
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
        case SortOrder.updatedDesc:
          cmp = b.updatedAt.compareTo(a.updatedAt);
          break;
        case SortOrder.dateAsc:
          cmp = a.addedAt.compareTo(b.addedAt);
          break;
        case SortOrder.nameAsc:
          cmp = a.path.compareTo(b.path);
          break;
        case SortOrder.nameDesc:
          cmp = b.path.compareTo(a.path);
          break;
        case SortOrder.sizeDesc:
          cmp = (b.size ?? 0).compareTo(a.size ?? 0);
          break;
        case SortOrder.sizeAsc:
          cmp = (a.size ?? 0).compareTo(b.size ?? 0);
          break;
        case SortOrder.tierDesc:
          final tierA = collectionA?.tier ?? 0;
          final tierB = collectionB?.tier ?? 0;
          cmp = tierB.compareTo(tierA);
          break;
        case SortOrder.tierAsc:
          final tierA = collectionA?.tier ?? 0;
          final tierB = collectionB?.tier ?? 0;
          cmp = tierA.compareTo(tierB);
          break;
        case SortOrder.favoriteDesc:
          final favA = collectionA?.isFavorite ?? false;
          final favB = collectionB?.isFavorite ?? false;
          cmp = (favB ? 1 : 0).compareTo(favA ? 1 : 0);
          break;
        case SortOrder.lastViewedDesc:
          final dateA = collectionA?.lastViewedAt?.millisecondsSinceEpoch ?? 0;
          final dateB = collectionB?.lastViewedAt?.millisecondsSinceEpoch ?? 0;
          cmp = dateB.compareTo(dateA);
          break;
      }

      if (cmp != 0) return cmp;
      // Stable ties are essential when adjacent pages are fetched separately.
      final added = b.addedAt.compareTo(a.addedAt);
      if (added != 0) return added;
      final path = a.path.compareTo(b.path);
      if (path != 0) return path;
      final uid = (a.uid ?? '').compareTo(b.uid ?? '');
      return uid != 0 ? uid : a.id.compareTo(b.id);
    });

    final visibleItems = filter?.limit != null
        ? items.take(filter!.limit!).toList()
        : items;

    // コレクションのタグを一括並列ロード
    final collectionsWithTags = visibleItems
        .map((i) => i.collection.value)
        .whereType<MediaCollection>()
        .toSet();
    if (collectionsWithTags.isNotEmpty) {
      await Future.wait(collectionsWithTags.map((c) => c.tags.load()));
    }

    _ensureItemUids(visibleItems);
    return visibleItems;
  }

  int _defaultDisplayCategory(MediaItem item, MediaCollection? collection) {
    final isCatalog =
        collection != null &&
        collection.path == item.path &&
        collection.isCatalog;
    if (item.type == MediaType.folder && !isCatalog) return 0;
    if (isCatalog) return 1;
    return 2;
  }

  @override
  Future<Result<void, AppError>> delete(int id) {
    return _safeRun(
      () async {
        final item = await _isar.mediaItems.get(id);
        await _isar.writeTxn(() async {
          final uid = item?.uid;
          if (uid != null && uid.isNotEmpty) {
            await _isar.storageRefs
                .filter()
                .ownerUidEqualTo(uid)
                .ownerTypeEqualTo(StorageOwnerType.item)
                .deleteAll();
          }
          await _isar.mediaItems.delete(id);
        });
      },
      'Delete MediaItem',
      additionalData: {'id': id},
    );
  }

  @override
  Future<Result<void, AppError>> deleteAll(List<int> ids) {
    return _safeRun(() async {
      final items = await _isar.mediaItems.getAll(ids);
      final ownerUids = items
          .map((item) => item?.uid)
          .whereType<String>()
          .where((uid) => uid.isNotEmpty)
          .toSet()
          .toList(growable: false);
      await _isar.writeTxn(() async {
        if (ownerUids.isNotEmpty) {
          await _isar.storageRefs
              .filter()
              .ownerTypeEqualTo(StorageOwnerType.item)
              .anyOf(ownerUids, (q, uid) => q.ownerUidEqualTo(uid))
              .deleteAll();
        }
        await _isar.mediaItems.deleteAll(ids);
      });
    }, 'DeleteAll MediaItems');
  }

  @override
  Future<Result<void, AppError>> deleteGraph(
    List<int> itemIds,
    List<int> collectionIds,
  ) {
    return _safeRun(() async {
      final items = await _isar.mediaItems.getAll(itemIds);
      final collections = await _isar.mediaCollections.getAll(collectionIds);
      final itemUids = items
          .map((item) => item?.uid)
          .whereType<String>()
          .where((uid) => uid.isNotEmpty)
          .toList(growable: false);
      final collectionUids = collections
          .map((collection) => collection?.uid)
          .whereType<String>()
          .where((uid) => uid.isNotEmpty)
          .toList(growable: false);

      await _isar.writeTxn(() async {
        for (final collection in collections.whereType<MediaCollection>()) {
          await collection.tags.load();
          for (final tag in collection.tags) {
            if (tag.usageCount > 0) tag.usageCount--;
          }
          await _isar.tags.putAll(collection.tags.toList());
        }
        if (itemUids.isNotEmpty) {
          await _isar.storageRefs
              .filter()
              .ownerTypeEqualTo(StorageOwnerType.item)
              .anyOf(itemUids, (q, uid) => q.ownerUidEqualTo(uid))
              .deleteAll();
        }
        if (collectionUids.isNotEmpty) {
          await _isar.storageRefs
              .filter()
              .ownerTypeEqualTo(StorageOwnerType.collection)
              .anyOf(collectionUids, (q, uid) => q.ownerUidEqualTo(uid))
              .deleteAll();
        }
        await _isar.mediaItems.deleteAll(itemIds);
        await _isar.mediaCollections.deleteAll(collectionIds);
      });
    }, 'DeleteGraph');
  }

  @override
  Future<Result<void, AppError>> moveGraphToTrash(
    List<int> itemIds,
    List<int> collectionIds, {
    required int rootItemId,
    required String? trashPath,
    required DateTime trashedAt,
  }) {
    return _safeRun(() async {
      final items = await _isar.mediaItems.getAll(itemIds);
      final collections = await _isar.mediaCollections.getAll(collectionIds);
      final rootItem = items
          .whereType<MediaItem>()
          .where((candidate) => candidate.id == rootItemId)
          .firstOrNull;
      if (rootItem == null) {
        throw StateError('Root item with id $rootItemId not found in targets');
      }
      final trashRootPath = rootItem.path;
      await _isar.writeTxn(() async {
        final updatedItems = <MediaItem>[];
        for (final item in items.whereType<MediaItem>()) {
          item
            ..isTrashed = true
            ..isTrashRoot = item.id == rootItemId
            ..trashRootPath = trashRootPath
            ..trashedAt = trashedAt
            ..updatedAt = trashedAt;
          if (item.id == rootItemId) item.trashPath = trashPath;
          updatedItems.add(item);
        }
        final updatedCollections = <MediaCollection>[];
        for (final collection in collections.whereType<MediaCollection>()) {
          collection
            ..isTrashed = true
            ..trashRootPath = trashRootPath
            ..updatedAt = trashedAt;
          updatedCollections.add(collection);
        }
        if (updatedItems.isNotEmpty) {
          await _isar.mediaItems.putAll(updatedItems);
        }
        if (updatedCollections.isNotEmpty) {
          await _isar.mediaCollections.putAll(updatedCollections);
        }
      });
    }, 'MoveGraphToTrash');
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getTrashedRoots() {
    return _safeRun(() async {
      return _isar.mediaItems
          .filter()
          .isTrashedEqualTo(true)
          .isTrashRootEqualTo(true)
          .sortByTrashedAtDesc()
          .findAll();
    }, 'GetTrashedRoots');
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getTrashedItems(String rootPath) {
    return _safeRun(() async {
      return _isar.mediaItems
          .filter()
          .isTrashedEqualTo(true)
          .trashRootPathEqualTo(rootPath)
          .findAll();
    }, 'GetTrashedItems');
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getTrashedCollections(
    String rootPath,
  ) {
    return _safeRun(() async {
      return _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(true)
          .trashRootPathEqualTo(rootPath)
          .findAll();
    }, 'GetTrashedCollections');
  }

  @override
  Future<Result<List<String>, AppError>> getTrashRestoreConflicts(
    String rootPath,
  ) {
    return _safeRun(() async {
      final trashedItems = await _isar.mediaItems
          .filter()
          .isTrashedEqualTo(true)
          .trashRootPathEqualTo(rootPath)
          .findAll();
      final trashedCollections = await _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(true)
          .trashRootPathEqualTo(rootPath)
          .findAll();
      final itemPaths = trashedItems.map((item) => item.path).toSet();
      final collectionPaths = trashedCollections
          .map((collection) => collection.path)
          .toSet();
      final conflicts = <String>{};
      if (itemPaths.isNotEmpty) {
        final activeItems = await _isar.mediaItems
            .filter()
            .isTrashedEqualTo(false)
            .anyOf(itemPaths, (query, path) => query.pathEqualTo(path))
            .findAll();
        conflicts.addAll(activeItems.map((item) => item.path));
      }
      if (collectionPaths.isNotEmpty) {
        final activeCollections = await _isar.mediaCollections
            .filter()
            .isTrashedEqualTo(false)
            .anyOf(collectionPaths, (query, path) => query.pathEqualTo(path))
            .findAll();
        conflicts.addAll(
          activeCollections.map((collection) => collection.path),
        );
      }
      final sorted = conflicts.toList()..sort();
      return sorted;
    }, 'GetTrashRestoreConflicts');
  }

  @override
  Future<Result<void, AppError>> restoreGraphFromTrash(
    String rootPath, {
    String? targetRootPath,
    String? targetParentPath,
  }) {
    return _safeRun(() async {
      // 復元先・子孫・表紙・StorageRefとごみ箱状態を一つのトランザクションで更新する。
      await _isar.writeTxn(() async {
        final items = await _isar.mediaItems
            .filter()
            .isTrashedEqualTo(true)
            .trashRootPathEqualTo(rootPath)
            .findAll();
        final collections = await _isar.mediaCollections
            .filter()
            .isTrashedEqualTo(true)
            .trashRootPathEqualTo(rootPath)
            .findAll();
        if (!items.any((item) => item.isTrashRoot && item.path == rootPath)) {
          throw StateError('復元対象のごみ箱ルートがありません');
        }
        final itemIds = items.map((item) => item.id).toSet();
        final collectionIds = collections
            .map((collection) => collection.id)
            .toSet();
        final target = targetRootPath ?? rootPath;
        String mapPath(String path) {
          if (path == rootPath) return target;
          if (p.isWithin(rootPath, path)) {
            return p.join(target, p.relative(path, from: rootPath));
          }
          throw StateError('ごみ箱グラフに復元元の範囲外のパスがあります');
        }

        final targets = {
          ...items.map((item) => mapPath(item.path)),
          ...collections.map((collection) => mapPath(collection.path)),
        };
        // 事前確認とDBコミットの間に別のアイテムが作成された場合も上書きしない。
        for (final path in targets) {
          final activeItem = await _isar.mediaItems
              .filter()
              .pathEqualTo(path)
              .findFirst();
          final activeCollection = await _isar.mediaCollections
              .filter()
              .pathEqualTo(path)
              .findFirst();
          if ((activeItem != null && !itemIds.contains(activeItem.id)) ||
              (activeCollection != null &&
                  !collectionIds.contains(activeCollection.id))) {
            throw StateError('復元先に使用中のアイテムがあります');
          }
        }
        for (final item in items) {
          final wasRoot = item.isTrashRoot;
          final parent = item.parentPath;
          item.path = mapPath(item.path);
          if (targetRootPath != null && target != rootPath) {
            if (wasRoot) {
              item.parentPath = targetParentPath;
            } else if (parent != null &&
                (parent == rootPath || p.isWithin(rootPath, parent))) {
              item.parentPath = mapPath(parent);
            }
          }
          item
            ..isTrashed = false
            ..isTrashRoot = false
            ..trashedAt = null
            ..trashPath = null
            ..trashRootPath = null
            ..updatedAt = DateTime.now();
        }
        for (final collection in collections) {
          collection.path = mapPath(collection.path);
          final cover = collection.coverImagePath;
          if (cover != null &&
              (cover == rootPath || p.isWithin(rootPath, cover))) {
            collection.coverImagePath = mapPath(cover);
          }
          collection
            ..isTrashed = false
            ..trashRootPath = null
            ..updatedAt = DateTime.now();
        }
        if (items.isNotEmpty) {
          await _isar.mediaItems.putAll(items);
          for (final item in items) {
            await _upsertStorageRefForItemInTxn(item);
          }
        }
        if (collections.isNotEmpty) {
          await _isar.mediaCollections.putAll(collections);
          for (final collection in collections) {
            await _upsertStorageRefForCollectionInTxn(collection);
          }
        }
      });
    }, 'RestoreGraphFromTrash');
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getCoverCandidates(
    String parentPath,
  ) {
    return _safeRun(() async {
      final items = await _isar.mediaItems
          .where()
          .parentPathEqualTo(parentPath)
          .filter()
          .typeEqualTo(MediaType.file)
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .findAll();
      return items
          .where(
            (item) =>
                item.isImage ||
                item.sourceType == MediaSourceType.externalReference ||
                (item.thumbnailPath?.isNotEmpty ?? false),
          )
          .toList();
    }, 'GetCoverCandidates');
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getByParentPath(
    String? parentPath,
  ) {
    return _safeRun(() async {
      final items = await _isar.mediaItems
          .where()
          .parentPathEqualTo(parentPath)
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false) // アーカイブ除外を追加
          .findAll();

      // 親パスでの取得時もピン留め優先でソート
      return _sortAndLoadItems(items, null);
    }, 'GetByParentPath MediaItems');
  }

  @override
  Future<Result<MediaItem?, AppError>> getByPath(
    String path, {
    bool includeTrashed = true,
  }) {
    return _safeRun(() async {
      return _isar.mediaItems
          .filter()
          .pathEqualTo(path)
          .optional(!includeTrashed, (q) => q.isTrashedEqualTo(false))
          .findFirst();
    }, 'GetByPath MediaItem');
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getPinnedCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .isPinnedEqualTo(true);

      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      } else {
        query = query.isHiddenEqualTo(false);
      }

      if (type != null) {
        query = query.typeEqualTo(type);
      }

      final collections = await query.sortByTitle().findAll();
      _ensureCollectionUids(collections);
      return collections;
    }, 'GetPinnedCollections');
  }

  @override
  Stream<List<MediaCollection>> watchPinnedCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    var query = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isArchivedEqualTo(false)
        .isPinnedEqualTo(true);

    if (isHidden != null) {
      query = query.isHiddenEqualTo(isHidden);
    } else {
      query = query.isHiddenEqualTo(false);
    }

    if (type != null) {
      query = query.typeEqualTo(type);
    }

    return query.sortByTitle().watch(fireImmediately: true);
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getFavoriteCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .isFavoriteEqualTo(true);

      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      } else {
        query = query.isHiddenEqualTo(false);
      }

      if (type != null) {
        query = query.typeEqualTo(type);
      }

      final collections = await query.sortByTitle().findAll();
      _ensureCollectionUids(collections);
      return collections;
    }, 'GetFavoriteCollections');
  }

  @override
  Stream<List<MediaCollection>> watchFavoriteCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    var query = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isArchivedEqualTo(false)
        .isFavoriteEqualTo(true);

    if (isHidden != null) {
      query = query.isHiddenEqualTo(isHidden);
    } else {
      query = query.isHiddenEqualTo(false);
    }

    if (type != null) {
      query = query.typeEqualTo(type);
    }

    return query.sortByTitle().watch(fireImmediately: true);
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getArchivedCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(true);

      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      } else {
        query = query.isHiddenEqualTo(false);
      }

      if (type != null) {
        query = query.typeEqualTo(type);
      }

      final collections = await query.sortByTitle().findAll();
      _ensureCollectionUids(collections);
      return collections;
    }, 'GetArchivedCollections');
  }

  @override
  Stream<List<MediaCollection>> watchArchivedCollections({
    CollectionType? type,
    bool? isHidden,
  }) {
    var query = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isArchivedEqualTo(true);

    if (isHidden != null) {
      query = query.isHiddenEqualTo(isHidden);
    } else {
      query = query.isHiddenEqualTo(false);
    }

    if (type != null) {
      query = query.typeEqualTo(type);
    }

    return query.sortByTitle().watch(fireImmediately: true);
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getHiddenCollections({
    CollectionType? type,
    bool? isArchived,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isHiddenEqualTo(true);

      if (isArchived != null) {
        query = query.isArchivedEqualTo(isArchived);
      }

      if (type != null) {
        query = query.typeEqualTo(type);
      }

      final collections = await query.sortByTitle().findAll();
      _ensureCollectionUids(collections);
      return collections;
    }, 'GetHiddenCollections');
  }

  @override
  Stream<List<MediaCollection>> watchHiddenCollections({
    CollectionType? type,
    bool? isArchived,
  }) {
    var query = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isHiddenEqualTo(true);

    if (isArchived != null) {
      query = query.isArchivedEqualTo(isArchived);
    }

    if (type != null) {
      query = query.typeEqualTo(type);
    }

    return query.sortByTitle().watch(fireImmediately: true);
  }

  @override
  Stream<List<MediaItem>> watchHiddenItems({bool? isArchived}) {
    var query = _isar.mediaItems
        .filter()
        .isTrashedEqualTo(false)
        .isHiddenEqualTo(true);

    if (isArchived != null) {
      query = query.isArchivedEqualTo(isArchived);
    }

    return query.sortByPath().watch(fireImmediately: true);
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getRecentlyViewedCollections({
    int limit = 10,
    bool? isExternal,
    bool? isHidden,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .lastViewedAtIsNotNull()
          .lastViewedItemIdIsNotNull()
          .not()
          .pathEqualTo('library');

      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      }

      List<MediaCollection> collections;
      if (isExternal == true) {
        collections = await query
            .typeEqualTo(CollectionType.externalFolder)
            .sortByLastViewedAtDesc()
            .limit(limit)
            .findAll();
      } else if (isExternal == false) {
        collections = await query
            .not()
            .typeEqualTo(CollectionType.externalFolder)
            .sortByLastViewedAtDesc()
            .limit(limit)
            .findAll();
      } else {
        collections = await query
            .sortByLastViewedAtDesc()
            .limit(limit)
            .findAll();
      }

      _ensureCollectionUids(collections);
      return collections;
    }, 'GetRecentlyViewedCollections');
  }

  @override
  Stream<List<MediaCollection>> watchRecentlyViewedCollections({
    int limit = 10,
    bool? isExternal,
    bool? isHidden,
  }) {
    var query = _isar.mediaCollections
        .filter()
        .isTrashedEqualTo(false)
        .isArchivedEqualTo(false)
        .lastViewedAtIsNotNull()
        .lastViewedItemIdIsNotNull()
        .not()
        .pathEqualTo('library');

    if (isHidden != null) {
      query = query.isHiddenEqualTo(isHidden);
    }

    QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortedQuery;
    if (isExternal == true) {
      sortedQuery = query
          .typeEqualTo(CollectionType.externalFolder)
          .sortByLastViewedAtDesc();
    } else if (isExternal == false) {
      sortedQuery = query
          .not()
          .typeEqualTo(CollectionType.externalFolder)
          .sortByLastViewedAtDesc();
    } else {
      sortedQuery = query.sortByLastViewedAtDesc();
    }

    return sortedQuery.limit(limit).watch(fireImmediately: true).map((
      collections,
    ) {
      _ensureCollectionUids(collections);
      return collections;
    });
  }

  @override
  Future<Result<void, AppError>> saveCollection(MediaCollection collection) {
    return _safeRun(() async {
      if (collection.type == CollectionType.externalFolder ||
          Uri.tryParse(collection.path)?.hasScheme == true ||
          p.isAbsolute(collection.path)) {
        final old = await _isar.mediaCollections.get(collection.id);
        if (old == null || old.path != collection.path) {
          throw StateError('External catalog registration has been retired');
        }
      }
      collection.uid = _ensureUid(collection.uid);
      await _isar.writeTxn(() async {
        await _isar.mediaCollections.put(collection);
        await collection.tags.save();
        await CollectionItemLinkService(
          _isar,
        ).linkCollectionInTransaction(collection);
        await collection.items.save();
        await _upsertStorageRefForCollectionInTxn(collection);
      });
    }, 'SaveCollection');
  }

  @override
  Future<Result<MediaCollection?, AppError>> decatalogifyCollection(int id) {
    return _safeRun(
      () => _isar.writeTxn(() async {
        // Read an independent, current object inside the transaction. Failed
        // writes must not mutate the provider's previously displayed object.
        final collection = await _isar.mediaCollections.get(id);
        if (collection == null) return null;
        await collection.tags.load();
        final tags = collection.tags.toList();
        for (final tag in tags) {
          if (tag.usageCount > 0) tag.usageCount--;
        }
        if (tags.isNotEmpty) await _isar.tags.putAll(tags);
        collection
          ..isCatalog = false
          ..tier = MediaTier.none.value
          ..isPinned = false
          ..coverImagePath = null
          ..updatedAt = DateTime.now();
        await _isar.mediaCollections.put(collection);
        // IsarLinks.clear() only clears the in-memory set and its change
        // tracking. reset() actually unlinks the persisted relationship.
        await collection.tags.reset();
        // The retained item links and storage references do not change when
        // only registration is removed.
        return collection;
      }),
      'DecatalogifyCollection',
      additionalData: {'id': id},
    );
  }

  @override
  Future<Result<bool, AppError>> updateCollectionLastViewed(
    String path, {
    required int itemId,
    required DateTime viewedAt,
  }) {
    return _safeRun(
      () async {
        if (path == 'library' || path.trim().isEmpty) {
          return false;
        }
        var updated = false;
        await _isar.writeTxn(() async {
          var collection = await _isar.mediaCollections
              .filter()
              .pathEqualTo(path)
              .findFirst();
          if (collection == null) {
            final normalized = _normalizeLocator(path);
            final storageReference = await _isar.storageRefs
                .filter()
                .ownerTypeEqualTo(StorageOwnerType.collection)
                .isPrimaryEqualTo(true)
                .group(
                  (query) => query
                      .locatorEqualTo(path)
                      .or()
                      .normalizedLocatorEqualTo(normalized),
                )
                .findFirst();
            if (storageReference != null &&
                storageReference.ownerUid.isNotEmpty) {
              collection = await _isar.mediaCollections
                  .filter()
                  .uidEqualTo(storageReference.ownerUid)
                  .findFirst();
            }
          }
          if (collection == null) return;
          await collection.items.load();
          final item = await _isar.mediaItems.get(itemId);
          if (item == null ||
              (!collection.items.any((linkedItem) => linkedItem.id == itemId) &&
                  item.path != collection.path &&
                  item.parentPath != collection.path)) {
            return;
          }
          final needsStorageReference =
              collection.uid == null || collection.uid!.isEmpty;
          if (needsStorageReference) {
            collection.uid = _ensureUid(collection.uid);
          }
          collection
            ..lastViewedAt = viewedAt
            ..lastViewedItemId = itemId;
          await _isar.mediaCollections.put(collection);
          await CollectionItemLinkService(
            _isar,
          ).linkCollectionInTransaction(collection);
          if (needsStorageReference) {
            await _upsertStorageRefForCollectionInTxn(collection);
          }
          updated = true;
        });
        return updated;
      },
      'UpdateCollectionLastViewed',
      additionalData: {'path': path, 'itemId': itemId},
    );
  }

  @override
  Future<Result<void, AppError>> toggleTagOnCollection(
    MediaCollection collection,
    Tag tag,
  ) {
    return _safeRun(() async {
      await _isar.writeTxn(() async {
        await collection.tags.load();
        final contains = collection.tags.contains(tag);
        if (contains) {
          collection.tags.remove(tag);
          if (tag.usageCount > 0) {
            tag.usageCount--;
          }
        } else {
          collection.tags.add(tag);
          tag.usageCount++;
        }
        collection.updatedAt = DateTime.now();
        await _isar.tags.put(tag);
        await _isar.mediaCollections.put(collection);
        await collection.tags.save();
        await CollectionItemLinkService(
          _isar,
        ).linkCollectionInTransaction(collection);
      });
    }, 'ToggleTagOnCollection');
  }

  @override
  Future<Result<void, AppError>> syncTagsOnCollection(
    MediaCollection collection,
    List<Tag> targetTags,
  ) {
    return _safeRun(() async {
      await _isar.writeTxn(() async {
        await collection.tags.load();
        await CollectionItemLinkService(
          _isar,
        ).linkCollectionInTransaction(collection);
        final currentTags = collection.tags.toList();
        final currentTagIds = currentTags.map((t) => t.id).toSet();
        final targetTagIds = targetTags.map((t) => t.id).toSet();

        final tagsToAdd = targetTags
            .where((t) => !currentTagIds.contains(t.id))
            .toList();
        final tagsToRemove = currentTags
            .where((t) => !targetTagIds.contains(t.id))
            .toList();

        if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
          return;
        }

        final modifiedTags = <Tag>[];

        for (final tag in tagsToAdd) {
          collection.tags.add(tag);
          tag.usageCount++;
          modifiedTags.add(tag);
        }

        for (final tag in tagsToRemove) {
          collection.tags.remove(tag);
          if (tag.usageCount > 0) {
            tag.usageCount--;
          }
          modifiedTags.add(tag);
        }

        collection.updatedAt = DateTime.now();
        if (modifiedTags.isNotEmpty) {
          await _isar.tags.putAll(modifiedTags);
        }
        await _isar.mediaCollections.put(collection);
        await collection.tags.save();
      });
    }, 'SyncTagsOnCollection');
  }

  @override
  Future<Result<MediaCollection?, AppError>> getCollectionByUid(String uid) {
    return _safeRun(() async {
      return _isar.mediaCollections.filter().uidEqualTo(uid).findFirst();
    }, 'GetCollectionByUid');
  }

  @override
  Future<Result<MediaCollection?, AppError>> getCollectionByPath(
    String path, {
    bool includeTrashed = true,
  }) {
    return _safeRun(() async {
      final collection = await _isar.mediaCollections
          .filter()
          .pathEqualTo(path)
          .optional(!includeTrashed, (q) => q.isTrashedEqualTo(false))
          .findFirst();
      if (collection != null) {
        if (collection.uid != null && collection.uid!.isNotEmpty) {
          return collection;
        }
        collection.uid = _ensureUid(collection.uid);
        await _isar.writeTxn(() async {
          await _isar.mediaCollections.put(collection);
        });
        return collection;
      }
      final normalized = _normalizeLocator(path);
      final ref = await _isar.storageRefs
          .filter()
          .ownerTypeEqualTo(StorageOwnerType.collection)
          .isPrimaryEqualTo(true)
          .group(
            (q) => q
                .locatorEqualTo(path)
                .or()
                .normalizedLocatorEqualTo(normalized),
          )
          .findFirst();
      if (ref == null || ref.ownerUid.isEmpty) return null;
      final byUid = await _isar.mediaCollections
          .filter()
          .uidEqualTo(ref.ownerUid)
          .findFirst();
      if (byUid == null || (!includeTrashed && byUid.isTrashed)) return null;
      if (byUid.uid != null && byUid.uid!.isNotEmpty) return byUid;
      byUid.uid = _ensureUid(byUid.uid);
      await _isar.writeTxn(() async {
        await _isar.mediaCollections.put(byUid);
      });
      return byUid;
    }, 'GetCollectionByPath');
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getExternalCollections({
    MediaFilter? filter,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .isArchivedEqualTo(false)
          .typeEqualTo(CollectionType.externalFolder);

      if (filter?.isHidden != null) {
        query = query.isHiddenEqualTo(filter!.isHidden!);
      }
      if (filter?.isFavorite != null) {
        query = query.isFavoriteEqualTo(filter!.isFavorite!);
      }
      if (filter?.tiers?.isNotEmpty == true) {
        query = query.group(
          (q) => q.anyOf(filter!.tiers!, (q, tier) => q.tierEqualTo(tier)),
        );
      }
      if (filter?.tagIds?.isNotEmpty == true) {
        for (final tagId in filter!.tagIds!) {
          query = query.tags(
            (tag) => tag.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
          );
        }
      }
      if (filter?.excludedTagIds?.isNotEmpty == true) {
        for (final tagId in filter!.excludedTagIds!) {
          query = query.not().tags(
            (tag) => tag.idEqualTo(tagId).or().ancestorIdsElementEqualTo(tagId),
          );
        }
      }
      if (filter?.hasTags == true) {
        query = query.tagsLengthGreaterThan(0);
      } else if (filter?.hasTags == false) {
        query = query.tagsLengthEqualTo(0);
      }

      final searchQuery = filter?.searchQuery?.trim();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final words = searchQuery
            .split(RegExp(r'[\s　]+'))
            .where((word) => word.isNotEmpty);
        for (final word in words) {
          query = query.group(
            (q) => q
                .titleContains(word, caseSensitive: false)
                .or()
                .aliasContains(word, caseSensitive: false)
                .or()
                .notesContains(word, caseSensitive: false)
                .or()
                .pathContains(word, caseSensitive: false)
                .or()
                .tags((tag) => tag.nameContains(word, caseSensitive: false)),
          );
        }
      }

      if (filter?.mediaTypes?.isNotEmpty == true &&
          !filter!.mediaTypes!.contains(MediaType.folder)) {
        return <MediaCollection>[];
      }

      final sortOrder = filter?.sortOrder ?? SortOrder.addedDesc;

      // カタログ一覧（フォルダ一覧）でのソート対応
      QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortedQuery;

      // ピン留めを最優先にするため、まずは query を orderByPinnedDesc() で始める
      final pinnedSorted = query.sortByIsPinnedDesc();

      switch (sortOrder) {
        case SortOrder.nameAsc:
          sortedQuery = pinnedSorted.thenByTitle();
        case SortOrder.nameDesc:
          sortedQuery = pinnedSorted.thenByTitleDesc();
        case SortOrder.addedAsc:
          sortedQuery = pinnedSorted.thenByCreatedAt();
        case SortOrder.addedDesc:
          sortedQuery = pinnedSorted.thenByCreatedAtDesc();
        case SortOrder.dateAsc:
          sortedQuery = pinnedSorted.thenByCreatedAt();
        case SortOrder.dateDesc:
          sortedQuery = pinnedSorted.thenByCreatedAtDesc();
        case SortOrder.updatedAsc:
          sortedQuery = pinnedSorted.thenByUpdatedAt();
        case SortOrder.updatedDesc:
          sortedQuery = pinnedSorted.thenByUpdatedAtDesc();
        case SortOrder.tierDesc:
          sortedQuery = pinnedSorted.thenByTierDesc().thenByCreatedAtDesc();
        case SortOrder.tierAsc:
          sortedQuery = pinnedSorted.thenByTier().thenByCreatedAtDesc();
        case SortOrder.favoriteDesc:
          sortedQuery = pinnedSorted
              .thenByIsFavoriteDesc()
              .thenByCreatedAtDesc();
        case SortOrder.lastViewedDesc:
          sortedQuery = pinnedSorted
              .thenByLastViewedAtDesc()
              .thenByCreatedAtDesc();
        default:
          sortedQuery = pinnedSorted.thenByCreatedAtDesc();
      }

      final loadedCollections = await sortedQuery.findAll();
      final collections = filter?.keepsParentWhileSearching == true
          ? loadedCollections.where((collection) {
              final parent = filter!.parentPath!.replaceAll('\\', '/');
              final path = collection.path.replaceAll('\\', '/');
              return p.dirname(path) == parent;
            }).toList()
          : loadedCollections;
      _ensureCollectionUids(collections);
      return collections;
    }, 'GetExternalCollections');
  }

  @override
  Future<Result<void, AppError>> deleteCollection(int id) {
    return _safeRun(
      () async {
        await _isar.writeTxn(() async {
          final collection = await _isar.mediaCollections.get(id);
          if (collection == null) return;

          // 1. タグの使用回数を減らす
          await collection.tags.load();
          if (collection.tags.isNotEmpty) {
            final tags = collection.tags.toList();
            for (final tag in tags) {
              if (tag.usageCount > 0) {
                tag.usageCount--;
              }
            }
            await _isar.tags.putAll(tags);
          }

          // 2. StorageRefを削除
          if (collection.uid != null && collection.uid!.isNotEmpty) {
            await _isar.storageRefs
                .filter()
                .ownerUidEqualTo(collection.uid!)
                .ownerTypeEqualTo(StorageOwnerType.collection)
                .deleteAll();
          }

          // 3. 本体を削除
          await _isar.mediaCollections.delete(id);
        });
      },
      'DeleteCollection',
      additionalData: {'id': id},
    );
  }

  @override
  Future<Result<void, AppError>> saveStorageRef(StorageRef ref) {
    return _safeRun(() async {
      ref.uid = _ensureUid(ref.uid);
      await _isar.writeTxn(() async {
        await _isar.storageRefs.put(ref);
      });
    }, 'SaveStorageRef');
  }

  @override
  Future<Result<StorageRef?, AppError>> getStorageRefByUid(String uid) {
    return _safeRun(() async {
      return _isar.storageRefs.filter().uidEqualTo(uid).findFirst();
    }, 'GetStorageRefByUid');
  }

  @override
  Future<Result<List<StorageRef>, AppError>> getStorageRefsByOwner(
    String ownerUid,
    StorageOwnerType ownerType,
  ) {
    return _safeRun(() async {
      return _isar.storageRefs
          .filter()
          .ownerUidEqualTo(ownerUid)
          .ownerTypeEqualTo(ownerType)
          .findAll();
    }, 'GetStorageRefsByOwner');
  }

  @override
  Future<Result<void, AppError>> deleteStorageRef(int id) {
    return _safeRun(() async {
      await _isar.writeTxn(() async {
        await _isar.storageRefs.delete(id);
      });
    }, 'DeleteStorageRef');
  }

  @override
  Future<Result<void, AppError>> updatePathsForMovedDirectory(
    String oldPath,
    String newPath,
  ) {
    return _safeRun(
      () async {
        // oldPath配下のアイテムを全て取得
        // Isarのクエリでは単純な前方一致しかできないため、
        // まず広めに取得してからメモリ上でフィルタリング＆置換を行う。
        final items = await _isar.mediaItems
            .filter()
            .pathStartsWith(oldPath)
            .findAll();
        final pathCollections = await _isar.mediaCollections
            .filter()
            .pathStartsWith(oldPath)
            .findAll();
        final coverCollections = await _isar.mediaCollections
            .filter()
            .coverImagePathStartsWith(oldPath)
            .findAll();
        final collectionMap = <int, MediaCollection>{};
        for (final col in pathCollections) {
          collectionMap[col.id] = col;
        }
        for (final col in coverCollections) {
          collectionMap[col.id] = col;
        }
        final collections = collectionMap.values.toList();

        final updatedItems = <MediaItem>[];
        final updatedCollections = <MediaCollection>[];

        for (final item in items) {
          // p.isWithin は、pathがoldPathの内部にあるかを確認する（サブディレクトリ/ファイル）
          // oldPath自身や、oldPath_suffix のような名前は除外される
          if (p.isWithin(oldPath, item.path)) {
            // パスの書き換え
            final relative = p.relative(item.path, from: oldPath);
            final newChildPath = p.join(newPath, relative);

            item.path = newChildPath;

            // parentPath の書き換え
            // アイテムが oldPath 直下の場合、parentPath == oldPath となる
            if (item.parentPath == oldPath) {
              item.parentPath = newPath;
            } else if (item.parentPath != null &&
                p.isWithin(oldPath, item.parentPath!)) {
              final parentRelative = p.relative(
                item.parentPath!,
                from: oldPath,
              );
              item.parentPath = p.join(newPath, parentRelative);
            }

            item.updatedAt = DateTime.now();
            updatedItems.add(item);
          }
        }

        for (final collection in collections) {
          final isPathWithin = p.isWithin(oldPath, collection.path);
          final coverPath = collection.coverImagePath;
          final isCoverWithin =
              coverPath != null &&
              (coverPath == oldPath || p.isWithin(oldPath, coverPath));

          if (!isPathWithin && !isCoverWithin) continue;

          if (isPathWithin) {
            final relative = p.relative(collection.path, from: oldPath);
            collection.path = p.join(newPath, relative);
          }

          if (isCoverWithin) {
            collection.coverImagePath = p.join(
              newPath,
              p.relative(coverPath, from: oldPath),
            );
          }

          collection.updatedAt = DateTime.now();
          updatedCollections.add(collection);
        }

        if (updatedItems.isNotEmpty || updatedCollections.isNotEmpty) {
          await _isar.writeTxn(() async {
            if (updatedItems.isNotEmpty) {
              await _isar.mediaItems.putAll(updatedItems);
              for (final item in updatedItems) {
                await _upsertStorageRefForItemInTxn(item);
              }
            }
            if (updatedCollections.isNotEmpty) {
              await _isar.mediaCollections.putAll(updatedCollections);
              for (final collection in updatedCollections) {
                await _upsertStorageRefForCollectionInTxn(collection);
              }
            }
          });
        }
      },
      'UpdatePathsForMovedDirectory',
      additionalData: {'oldPath': oldPath, 'newPath': newPath},
    );
  }

  @override
  Future<Result<void, AppError>> updateCoverImagePath(
    String oldPath,
    String newPath,
  ) {
    return _safeRun(
      () async {
        final collections = await _isar.mediaCollections
            .filter()
            .coverImagePathEqualTo(oldPath)
            .findAll();

        if (collections.isEmpty) return;

        final now = DateTime.now();
        for (final col in collections) {
          col.coverImagePath = newPath;
          col.updatedAt = now;
        }

        await _isar.writeTxn(() async {
          await _isar.mediaCollections.putAll(collections);
          for (final collection in collections) {
            await _upsertStorageRefForCollectionInTxn(collection);
          }
        });
      },
      'UpdateCoverImagePath',
      additionalData: {'oldPath': oldPath, 'newPath': newPath},
    );
  }

  @override
  Future<Result<List<MediaCollection>, AppError>> getDescendantCollections(
    String path,
  ) {
    return _safeRun(() async {
      final collections = await _isar.mediaCollections
          .filter()
          .pathStartsWith(path)
          .findAll();

      final descendants = <MediaCollection>[];
      for (final collection in collections) {
        if (p.isWithin(path, collection.path)) {
          descendants.add(collection);
        }
      }
      return descendants;
    }, 'GetDescendantCollections');
  }

  @override
  Future<Result<List<MediaItem>, AppError>> getDescendants(String path) {
    return _safeRun(() async {
      final items = await _isar.mediaItems
          .filter()
          .pathStartsWith(path)
          .findAll();

      final descendants = <MediaItem>[];
      for (final item in items) {
        if (p.isWithin(path, item.path)) {
          descendants.add(item);
        }
      }
      return descendants;
    }, 'GetDescendants');
  }

  @override
  Future<Result<void, AppError>> updateThumbnail(int id, int positionMs) {
    return _safeRun(
      () async {
        final item = await _isar.mediaItems.get(id);
        if (item == null) return;

        item.updatedAt = DateTime.now();
        await _isar.writeTxn(() async {
          await _isar.mediaItems.put(item);
        });
      },
      'UpdateThumbnail',
      additionalData: {'id': id, 'positionMs': positionMs},
    );
  }

  @override
  Future<Result<void, AppError>> updateCollectionHeaderExpanded(
    int id,
    bool expanded,
  ) {
    return _safeRun(
      () async {
        final collection = await _isar.mediaCollections.get(id);
        if (collection == null) return;

        collection.isHeaderExpanded = expanded;
        collection.updatedAt = DateTime.now();
        await _isar.writeTxn(() async {
          await _isar.mediaCollections.put(collection);
        });
      },
      'UpdateCollectionHeaderExpanded',
      additionalData: {'id': id, 'expanded': expanded},
    );
  }

  @override
  Future<Result<MediaCollection?, AppError>> getCollectionById(int id) {
    return _safeRun(
      () async {
        final collection = await _isar.mediaCollections.get(id);
        if (collection != null) {
          _ensureCollectionUids([collection]);
        }
        return collection;
      },
      'GetCollectionById',
      additionalData: {'id': id},
    );
  }

  @override
  Future<Result<FolderSummary, AppError>> getFolderSummary(
    String folderPath, {
    bool? isHidden,
  }) {
    return _safeRun(
      () async {
        var query = _isar.mediaItems
            .filter()
            .isTrashedEqualTo(false)
            .parentPathEqualTo(folderPath);

        if (isHidden != null) {
          query = query.isHiddenEqualTo(isHidden);
        }

        final items = await query.findAll();
        final paths = items.map((item) => item.path).toList(growable: false);
        final catalogs = paths.isEmpty
            ? <MediaCollection>[]
            : await _isar.mediaCollections
                  .filter()
                  .isTrashedEqualTo(false)
                  .anyOf(paths, (query, path) => query.pathEqualTo(path))
                  .findAll();
        final catalogCount = catalogs
            .where((collection) => collection.isCatalog)
            .length;
        var folders = 0;
        var files = 0;
        var images = 0;
        var videos = 0;
        var docs = 0;
        String? firstThumb;
        String? firstImg;

        for (final item in items) {
          if (item.type == MediaType.folder) {
            folders++;
          } else {
            files++;
            if (item.isImage) {
              images++;
              firstImg ??= item.path;
              firstThumb ??= item.thumbnailPath ?? item.path;
            } else if (item.isVideo) {
              videos++;
              firstThumb ??= item.thumbnailPath;
            } else if (item.isDocument || item.isText || item.isPdf) {
              docs++;
            }
          }
        }

        return FolderSummary(
          folderCount: folders,
          catalogCount: catalogCount,
          fileCount: files,
          totalCount: items.length,
          imageCount: images,
          videoCount: videos,
          documentCount: docs,
          firstThumbnailPath: firstThumb,
          firstImagePath: firstImg,
        );
      },
      'GetFolderSummary',
      additionalData: {'folderPath': folderPath},
    );
  }

  @override
  Future<Result<bool, AppError>> hasAnyItems({
    MediaSourceType? sourceType,
    bool? isArchived,
    bool? isHidden,
  }) {
    return _safeRun(() async {
      var query = _isar.mediaItems.filter().isTrashedEqualTo(false);

      if (sourceType != null) {
        query = query.sourceTypeEqualTo(sourceType);
      }
      if (isArchived != null) {
        query = query.isArchivedEqualTo(isArchived);
      }
      if (isHidden != null) {
        query = query.isHiddenEqualTo(isHidden);
      }

      final first = await query.findFirst();
      return first != null;
    }, 'HasAnyItems');
  }

  @override
  Stream<bool> watchHasAnyItems({
    MediaSourceType? sourceType,
    bool? isArchived,
    bool? isHidden,
  }) {
    var query = _isar.mediaItems.filter().isTrashedEqualTo(false);

    if (sourceType != null) {
      query = query.sourceTypeEqualTo(sourceType);
    }
    if (isArchived != null) {
      query = query.isArchivedEqualTo(isArchived);
    }
    if (isHidden != null) {
      query = query.isHiddenEqualTo(isHidden);
    }

    return query.watch(fireImmediately: true).map((items) => items.isNotEmpty);
  }
}
