// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'archive_media_item_use_case.g.dart';

@riverpod
Future<ArchiveMediaItemUseCase> archiveMediaItemUseCase(
  Ref ref,
) async {
  final repo = await ref.watch(mediaRepositoryProvider.future);
  return ArchiveMediaItemUseCase(repo);
}

class ArchiveMediaItemUseCase {
  final MediaRepository _repository;

  ArchiveMediaItemUseCase(this._repository);

  Future<Result<void, AppError>> call({
    MediaItem? item,
    MediaCollection? collection,
    required bool isArchived,
  }) async {
    if (collection != null) {
      collection.isArchived = isArchived;

      await _repository.saveCollection(collection);

      // コレクション内のすべてのアイテム（再帰的）を同期する
      final descendantsResult = await _repository.getDescendants(
        collection.path,
      );
      if (descendantsResult is Success<List<MediaItem>, AppError>) {
        final items = descendantsResult.data;
        if (items.isNotEmpty) {
          for (final item in items) {
            item.isArchived = isArchived;
          }
          await _repository.saveAll(items);
        }
      }

      // サブコレクション（再帰的）も同期する
      final descendantCollectionsResult = await _repository
          .getDescendantCollections(collection.path);
      if (descendantCollectionsResult
          is Success<List<MediaCollection>, AppError>) {
        final childCollections = descendantCollectionsResult.data;
        for (final child in childCollections) {
          if (child.isArchived != isArchived) {
            child.isArchived = isArchived;
            await _repository.saveCollection(child);
          }
        }
      }

      // 同じパスを持つMediaItem（フォルダ自身を指すアイテム）も同期する
      final itemResult = await _repository.getByPath(collection.path);
      final mediaItem = itemResult.dataOrNull;
      if (mediaItem != null && mediaItem.isArchived != isArchived) {
        mediaItem.isArchived = isArchived;
        await _repository.save(mediaItem);
      }

      return Result.success(null);
    } else if (item != null) {
      item.isArchived = isArchived;

      // アイテムが属するコレクションも同期させる
      await item.collection.load();
      final parentCollection = item.collection.value;
      if (parentCollection != null &&
          parentCollection.type == CollectionType.file) {
        parentCollection.isArchived = isArchived;
        await _repository.saveCollection(parentCollection);
      }

      return _repository.save(item);
    }

    return Result.failure(
      AppError.database(
        'Item and Collection cannot both be null',
        context: 'ArchiveMediaItemUseCase',
      ),
    );
  }
}
