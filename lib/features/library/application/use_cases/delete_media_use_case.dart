// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'delete_media_use_case.g.dart';

@Riverpod(keepAlive: true)
DeleteMediaUseCase deleteMediaUseCase(Ref ref) {
  return DeleteMediaUseCase(
    ref.read(fileServiceProvider),
    ref.read(mediaRepositoryProvider.future),
    ref.read(operationJournalServiceProvider),
  );
}

class DeleteMediaUseCase {
  final FileService _fileService;
  final Future<MediaRepository> _mediaRepositoryFuture;
  final OperationJournalService _journal;
  final Uuid _uuid = const Uuid();

  DeleteMediaUseCase(
    this._fileService,
    this._mediaRepositoryFuture,
    this._journal,
  );

  Future<Result<void, AppError>> invoke(
    MediaItem item, {
    void Function(int processed, int total, String itemName)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // バリデーション: IDが有効かチェック
    if (item.id <= 0) {
      return Result.failure(
        AppError.validation(
          'Invalid media item ID',
          context: 'DeleteMediaUseCase.invoke',
        ).withAdditionalData({'itemId': item.id, 'path': item.path}),
      );
    }

    try {
      final repo = await _mediaRepositoryFuture;

      // 1. 削除対象の階層を走査してリストアップ
      final itemsToDelete = <MediaItem>[];
      final visitedIds = <int>{};
      Future<Result<void, AppError>> fetchChildren(MediaItem root) async {
        if (!visitedIds.add(root.id)) {
          return Result.failure(
            AppError.validation(
              'Cyclic or duplicate media hierarchy detected',
              context: 'DeleteMediaUseCase.invoke',
            ).withAdditionalData({'itemId': root.id, 'path': root.path}),
          );
        }
        if (root.type == MediaType.folder) {
          final childrenResult = await repo.getByParentPath(root.path);
          if (childrenResult.isFailure) {
            return Result.failure(
              (childrenResult as Failure<dynamic, AppError>).error,
            );
          }
          final children = childrenResult.dataOrNull ?? [];
          for (final child in children) {
            final res = await fetchChildren(child);
            if (res.isFailure) return res;
          }
        }
        itemsToDelete.add(root);
        return Result.success(null);
      }

      AppLogger.d(LogTag.storage, '削除対象の収集開始: ${item.path}');
      final fetchResult = await fetchChildren(item);
      if (fetchResult.isFailure) return fetchResult;

      final total = itemsToDelete.length;
      var processed = 0;
      AppLogger.d(LogTag.storage, '削除対象アイテム数: $total');

      final collectionsToDelete = <MediaCollection>[];
      for (final currentItem in itemsToDelete) {
        if (isCancelled?.call() == true) {
          AppLogger.i(LogTag.storage, '削除アクションがキャンセルされました。以降の処理を中断します。');
          return Result.failure(
            AppError.validation(
              'Delete was cancelled',
              context: 'DeleteMediaUseCase.invoke',
            ).withAdditionalData({'processed': processed, 'total': total}),
          );
        }

        final collectionResult = await repo.getCollectionByPath(
          currentItem.path,
        );
        if (collectionResult.isFailure) {
          return Result.failure(collectionResult.errorOrNull!);
        }
        final collection = collectionResult.dataOrNull;
        if (collection != null) collectionsToDelete.add(collection);
      }

      final operationId = _uuid.v4();
      final isLocal = item.sourceType == MediaSourceType.localCopy;
      final trashPath = isLocal
          ? '.trash/$operationId/${p.basename(item.path)}'
          : '';
      var entry = OperationJournalEntry(
        id: operationId,
        kind: OperationKind.delete,
        stage: OperationStage.planned,
        payload: {
          'rootItemId': item.id,
          'originalPath': item.path,
          'trashPath': trashPath,
          'isLocal': isLocal,
        },
      );
      await _journal.write(entry);

      if (isLocal) {
        final staged = await _fileService.stageDeletion(item.path, trashPath);
        if (staged.isFailure) {
          await _journal.remove(operationId);
          return staged;
        }
      }
      entry = entry.copyWith(stage: OperationStage.staged);
      await _journal.write(entry);

      final trashedAt = DateTime.now();
      final deleteResult = await repo.moveGraphToTrash(
        itemsToDelete.map((current) => current.id).toList(growable: false),
        collectionsToDelete
            .map((current) => current.id)
            .toList(growable: false),
        rootItemId: item.id,
        trashPath: isLocal ? trashPath : null,
        trashedAt: trashedAt,
      );
      if (deleteResult.isFailure) {
        if (isLocal) {
          final restored = await _fileService.restoreStagedDeletion(
            trashPath,
            item.path,
          );
          if (restored.isFailure) {
            return Result.failure(
              AppError.file(
                'Delete failed and staged file restoration also failed',
                context: 'DeleteMediaUseCase.invoke',
              ).withAdditionalData({'operationId': operationId}),
            );
          }
        }
        await _journal.remove(operationId);
        return deleteResult;
      }
      processed = total;
      onProgress?.call(processed, total, item.path);

      entry = entry.copyWith(stage: OperationStage.committed);
      await _journal.write(entry);
      // committedジャーナルはごみ箱メタデータとして復元・完全削除まで保持する。

      AppLogger.d(LogTag.storage, 'ごみ箱への移動完了: ${item.path}');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'Delete failed: $e', e, st);
      return Result.failure(
        AppError.unknown('Delete failed: $e', original: e, stackTrace: st),
      );
    }
  }
}
