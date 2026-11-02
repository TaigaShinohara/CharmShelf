// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'bulk_update_tier_use_case.g.dart';

@Riverpod(keepAlive: true)
BulkUpdateTierUseCase bulkUpdateTierUseCase(Ref ref) {
  return BulkUpdateTierUseCase(ref.read(mediaRepositoryProvider.future));
}

class BulkUpdateTierUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;

  BulkUpdateTierUseCase(this._mediaRepositoryFuture);

  Future<Result<void, AppError>> invoke({
    required List<MediaItem> items,
    required MediaTier tier,
  }) async {
    try {
      final repo = await _mediaRepositoryFuture;
      final lookupCache = <String, MediaCollection?>{};

      final resolvedCollections = await Future.wait(
        items.map((item) => _resolveWorkCollection(item, repo, lookupCache)),
      );
      final collectionsByPath = <String, MediaCollection>{};
      for (final collection in resolvedCollections) {
        if (collection != null) {
          collectionsByPath[collection.path] = collection;
        }
      }
      final collections = collectionsByPath.values;

      for (final collection in collections) {
        if (collection.tier == tier.value) continue;
        collection.tier = tier.value;
        collection.updatedAt = DateTime.now();
        final result = await repo.saveCollection(collection);
        if (result is Failure) return result as Failure<void, AppError>;
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'BulkUpdateTier failed: $e',
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
    if (linkedCollection != null &&
        linkedCollection.path == item.path &&
        linkedCollection.isCatalog) {
      return linkedCollection;
    }

    final cached = lookupCache[item.path];
    if (lookupCache.containsKey(item.path)) {
      return cached;
    }

    final byPath = await repo.getCollectionByPath(item.path);
    final collection = byPath.dataOrNull;
    if (collection != null &&
        collection.path == item.path &&
        collection.isCatalog) {
      lookupCache[item.path] = collection;
      return collection;
    }
    lookupCache[item.path] = null;
    return null;
  }
}
