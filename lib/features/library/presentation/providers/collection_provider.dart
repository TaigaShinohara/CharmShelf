import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';

part 'collection_provider.g.dart';

@riverpod
class CollectionNotifier extends _$CollectionNotifier {
  @override
  bool updateShouldNotify(
    AsyncValue<MediaCollection?> previous,
    AsyncValue<MediaCollection?> next,
  ) {
    // Isar entities mutate in place. Preserve Riverpod 2's data/error
    // notifications when a save returns the same collection instance.
    if (previous.isLoading || next.isLoading) {
      return previous.isLoading != next.isLoading;
    }
    return true;
  }

  @override
  Future<MediaCollection?> build(String path) async {
    final repository = await ref.watch(mediaRepositoryProvider.future);
    final result = await repository.getCollectionByPath(path);
    final collection = result.dataOrNull;
    if (collection != null &&
        collection.tags.isAttached &&
        !collection.tags.isLoaded) {
      try {
        await collection.tags.load();
      } catch (_) {
        // 未アタッチまたはロード失敗時は無視
      }
    }
    return collection;
  }

  Future<MediaCollection> _ensureCollection() async {
    final current = state.value;
    if (current != null) return current;

    final repository = await ref.read(mediaRepositoryProvider.future);

    // 同じパスを持つ既存のアイテムがあれば、その非表示・アーカイブ状態を引き継ぐ
    final existingItemResult = await repository.getByPath(path);
    final existingItem = existingItemResult.dataOrNull;

    // カバー画像の探索
    String? coverPath;
    if (existingItem != null) {
      coverPath =
          existingItem.thumbnailPath ??
          (existingItem.isImage ? existingItem.path : null);
    }
    if (coverPath == null) {
      final childrenResult = await repository.getByParentPath(path);
      final children = (childrenResult.dataOrNull ?? []).toList()
        ..sort((a, b) => compareNatural(a.path, b.path));
      final firstCoverItem = children.firstWhereOrNull(
        (item) => item.thumbnailPath != null || item.isImage,
      );
      if (firstCoverItem != null) {
        coverPath =
            firstCoverItem.thumbnailPath ??
            (firstCoverItem.isImage ? firstCoverItem.path : null);
      }
    }

    final newCollection = MediaCollection()
      ..title = p.basename(path)
      ..path = path
      ..type = _inferCollectionType(path)
      ..coverImagePath = coverPath
      ..isHidden = existingItem?.isHidden ?? false
      ..isArchived = existingItem?.isArchived ?? false
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final result = await repository.saveCollection(newCollection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to create collection for path=$path: ${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(newCollection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Created new collection: path=$path',
    );
    return newCollection;
  }

  CollectionType _inferCollectionType(String rawPath) {
    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'file') {
        return CollectionType.externalFolder;
      }
      if (p.isAbsolute(uri.toFilePath())) {
        return CollectionType.externalFolder;
      }
    } else if (p.isAbsolute(rawPath)) {
      return CollectionType.externalFolder;
    }
    final targetPath = uri != null && uri.hasScheme && uri.scheme == 'file'
        ? uri.toFilePath()
        : rawPath;
    final ext = p.extension(targetPath);
    return ext.isEmpty ? CollectionType.folder : CollectionType.file;
  }

  void _invalidateLibraryLists() {
    ref.invalidate(libraryViewModelProvider);
    ref.invalidate(externalFolderListProvider);
    ref.invalidate(externalFolderItemsProvider);
    ref.invalidate(externalRootItemsProvider);
  }

  Future<void> togglePin() async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    // 最新の状態を取得、なければ作成
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    collection.isPinned = !collection.isPinned;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to toggle pin: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Toggled pin: path=$path -> isPinned=${collection.isPinned}',
    );

    // リストのソート順に影響するため、主要なライブラリビューモデルを無効化して再取得を促す
    _invalidateLibraryLists();
  }

  Future<void> updateAlias(String? alias) async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    final sanitizedAlias = alias?.trim().isEmpty == true ? null : alias?.trim();
    collection.alias = sanitizedAlias;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to update alias: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Updated alias: path=$path, alias=$sanitizedAlias',
    );
    _invalidateLibraryLists();
  }

  Future<void> toggleFavorite() async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    collection.isFavorite = !collection.isFavorite;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to toggle favorite: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Toggled favorite: path=$path -> isFavorite=${collection.isFavorite}',
    );

    // お気に入りフィルターやソート順に影響するため、主要なライブラリビューモデルを無効化して再取得を促す
    _invalidateLibraryLists();
  }

  Future<void> updateNotes(String? notes) async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    final sanitizedNotes = notes?.trim().isEmpty == true ? null : notes?.trim();
    collection.notes = sanitizedNotes;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to update notes: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Updated notes: path=$path, length=${sanitizedNotes?.length ?? 0}',
    );
    _invalidateLibraryLists();
  }

  Future<void> updateSplitSpreadView(bool enabled) async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    collection.splitSpreadView = enabled;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to update splitSpreadView: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Updated splitSpreadView: path=$path, enabled=$enabled',
    );
  }

  Future<void> updateTier(MediaTier tier) async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final collection =
        (await repository.getCollectionByPath(path)).dataOrNull ??
        await _ensureCollection();

    collection.tier = tier.value;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to update tier: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Updated tier: path=$path, tier=${tier.name}',
    );
    _invalidateLibraryLists();
  }

  Future<void> catalogify() async {
    final collection = await _ensureCollection();
    final repository = await ref.read(mediaRepositoryProvider.future);
    collection.isCatalog = true;
    if (collection.coverImagePath == null &&
        (collection.type == CollectionType.folder ||
            collection.type == CollectionType.externalFolder)) {
      collection.coverImagePath = await _resolveFolderCoverPath(
        repository,
        collection.path,
      );
    }
    collection.tier = MediaTier.none.value;
    collection.updatedAt = DateTime.now();

    final result = await repository.saveCollection(collection);
    if (result.isFailure) {
      AppLogger.e(
        LogTag.provider,
        '[CollectionNotifier] Failed to catalogify: path=$path, error=${result.errorOrNull}',
      );
      throw result.errorOrNull!;
    }

    state = AsyncData(collection);
    AppLogger.i(
      LogTag.provider,
      '[CollectionNotifier] Catalogified: path=$path, isCatalog=${collection.isCatalog}',
    );
    _invalidateLibraryLists();
  }

  Future<void> decatalogify() async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final result = await repository.getCollectionByPath(path);
    if (result.isFailure) throw result.errorOrNull!;
    final collection = result.dataOrNull;
    if (collection == null) return;

    final saved = await repository.decatalogifyCollection(collection.id);
    if (saved.isFailure) throw saved.errorOrNull!;

    state = AsyncData(saved.dataOrNull);
    _invalidateLibraryLists();
  }

  Future<String?> _resolveFolderCoverPath(
    MediaRepository repository,
    String folderPath,
  ) async {
    final childrenResult = await repository.getByParentPath(folderPath);
    final children = (childrenResult.dataOrNull ?? const <MediaItem>[]).toList()
      ..sort((a, b) => compareNatural(a.path, b.path));
    for (final item in children) {
      if (item.type != MediaType.file || item.isMissing) continue;
      if (item.thumbnailPath?.isNotEmpty == true) {
        return item.thumbnailPath;
      }
      if (item.isImage) return item.path;
    }
    return null;
  }

  Future<void> delete() async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final current = state.value;
    if (current != null) {
      final result = await repository.deleteCollection(current.id);
      if (result.isFailure) {
        AppLogger.e(
          LogTag.provider,
          '[CollectionNotifier] Failed to delete collection: path=$path, error=${result.errorOrNull}',
        );
        throw result.errorOrNull!;
      }
      state = const AsyncData(null);
      AppLogger.i(
        LogTag.provider,
        '[CollectionNotifier] Deleted collection: path=$path, id=${current.id}',
      );
      _invalidateLibraryLists();
    }
  }
}

/// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー
@riverpod
Future<MediaCollection?> parentCatalog(
  Ref ref, {
  required String? parentPath,
}) async {
  if (parentPath == null || parentPath.trim().isEmpty) {
    return null;
  }
  final repository = await ref.watch(mediaRepositoryProvider.future);

  String? currentPath = parentPath;
  while (currentPath != null && currentPath.isNotEmpty) {
    final result = await repository.getCollectionByPath(currentPath);
    final collection = result.dataOrNull;
    if (collection != null && collection.isCatalog) {
      return collection;
    }
    final dirname = p.dirname(currentPath);
    if (dirname == currentPath || dirname == '.' || dirname.isEmpty) {
      break;
    }
    currentPath = dirname;
  }
  return null;
}
