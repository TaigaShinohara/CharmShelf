// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/repositories/tag_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';

part 'bulk_update_tags_use_case.g.dart';

@Riverpod(keepAlive: true)
BulkUpdateTagsUseCase bulkUpdateTagsUseCase(Ref ref) {
  return BulkUpdateTagsUseCase(
    ref.read(mediaRepositoryProvider.future),
    ref.read(tagRepositoryProvider.future),
  );
}

class BulkUpdateTagsUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;
  final Future<TagRepository> _tagRepositoryFuture;

  BulkUpdateTagsUseCase(this._mediaRepositoryFuture, this._tagRepositoryFuture);

  /// 複数のアイテムに対して複数のタグを一括で追加または削除する
  Future<Result<void, AppError>> invoke({
    required List<MediaItem> items,
    required List<Tag> tags,
    required bool add,
    List<String> collectionPaths = const [],
  }) async {
    try {
      final repo = await _mediaRepositoryFuture;
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

      if (collectionPaths.isNotEmpty) {
        final fromPaths = await Future.wait(
          collectionPaths.map(
            (path) => _loadCollectionByPath(path, repo, lookupCache),
          ),
        );
        for (final collection in fromPaths) {
          if (collection != null) {
            collectionsByPath[collection.path] = collection;
          }
        }
      }

      final collections = collectionsByPath.values.toList(growable: false);

      final updatedTags = <Tag>{};
      await Future.wait(
        collections.map((collection) => collection.tags.load()),
      );

      for (final collection in collections) {
        var collectionUpdated = false;
        for (final tag in tags) {
          if (add) {
            if (!collection.tags.contains(tag)) {
              collection.tags.add(tag);
              tag.usageCount++;
              updatedTags.add(tag);
              collectionUpdated = true;
            }
          } else {
            if (collection.tags.contains(tag)) {
              collection.tags.remove(tag);
              if (tag.usageCount > 0) {
                tag.usageCount--;
              }
              updatedTags.add(tag);
              collectionUpdated = true;
            }
          }
        }
        if (collectionUpdated) {
          collection.updatedAt = DateTime.now();
          final result = await repo.saveCollection(collection);
          if (result is Failure) return result as Failure<void, AppError>;
        }
      }

      // Tagの使用頻度が更新された場合、一括保存
      if (updatedTags.isNotEmpty) {
        final tagRepo = await _tagRepositoryFuture;
        final saveAllRes = await tagRepo.saveAll(updatedTags.toList());
        if (saveAllRes is Failure<void, AppError>) {
          return Result.failure(saveAllRes.error);
        }
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'BulkUpdateTags failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
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
}
