import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:uuid/uuid.dart';

class RemoveExternalFolderReferenceOutcome {
  const RemoveExternalFolderReferenceOutcome({
    required this.permissionCleanupPending,
  });

  final bool permissionCleanupPending;
}

/// 外部フォルダのDB参照を原子的に削除し、永続アクセス権を安全に解放する。
class RemoveExternalFolderReferenceUseCase {
  RemoveExternalFolderReferenceUseCase(
    this._repository,
    this._journal,
    this._releaseExternalAccess, {
    String Function()? operationIdFactory,
  }) : _operationIdFactory = operationIdFactory ?? const Uuid().v4;

  final MediaRepository _repository;
  final OperationJournalService _journal;
  final Future<void> Function(Uri uri) _releaseExternalAccess;
  final String Function() _operationIdFactory;

  Future<Result<RemoveExternalFolderReferenceOutcome, AppError>> invoke(
    MediaCollection folder,
  ) async {
    if (folder.id <= 0 || folder.path.isEmpty) {
      return Result.failure(
        AppError.validation(
          'Invalid external folder reference',
          context: 'RemoveExternalFolderReferenceUseCase.invoke',
        ),
      );
    }

    try {
      final descendantsResult = await _repository.getDescendants(folder.path);
      if (descendantsResult.isFailure) {
        return Result.failure(descendantsResult.errorOrNull!);
      }

      final directItemsResult = await _repository.getAll(
        filter: MediaFilter(
          parentPath: folder.path,
          sourceType: MediaSourceType.externalReference,
        ),
      );
      if (directItemsResult.isFailure) {
        return Result.failure(directItemsResult.errorOrNull!);
      }

      final collectionsResult = await _repository.getDescendantCollections(
        folder.path,
      );
      if (collectionsResult.isFailure) {
        return Result.failure(collectionsResult.errorOrNull!);
      }

      final itemIds = <int>{
        ...descendantsResult.dataOrNull!.map((item) => item.id),
        ...directItemsResult.dataOrNull!.map((item) => item.id),
      }.where((id) => id > 0).toList(growable: false);
      final collectionIds = <int>{
        folder.id,
        ...collectionsResult.dataOrNull!.map((collection) => collection.id),
      }.where((id) => id > 0).toList(growable: false);

      final operationId = _operationIdFactory();
      final entry = OperationJournalEntry(
        id: operationId,
        kind: OperationKind.removeExternalFolderReference,
        stage: OperationStage.planned,
        payload: {
          'rootCollectionId': folder.id,
          'originalPath': folder.path,
          'itemIds': itemIds,
          'collectionIds': collectionIds,
        },
      );
      await _journal.write(entry);

      final deleteResult = await _repository.deleteGraph(
        itemIds,
        collectionIds,
      );
      if (deleteResult.isFailure) {
        try {
          await _journal.remove(operationId);
        } catch (error, stackTrace) {
          AppLogger.e(
            LogTag.storage,
            '外部フォルダ参照解除の失敗ジャーナルを削除できませんでした',
            error,
            stackTrace,
          );
        }
        return Result.failure(deleteResult.errorOrNull!);
      }

      try {
        await _releaseExternalAccess(Uri.parse(folder.path));
        await _journal.remove(operationId);
        return Result.success(
          const RemoveExternalFolderReferenceOutcome(
            permissionCleanupPending: false,
          ),
        );
      } catch (error, stackTrace) {
        AppLogger.e(
          LogTag.storage,
          '外部フォルダ参照は削除しましたが、権限の後片付けを保留します',
          error,
          stackTrace,
        );
        return Result.success(
          const RemoveExternalFolderReferenceOutcome(
            permissionCleanupPending: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.e(LogTag.storage, '外部フォルダ参照の解除に失敗しました', error, stackTrace);
      return Result.failure(
        AppError.unknown(
          'Failed to remove external folder reference',
          original: error,
          stackTrace: stackTrace,
          context: 'RemoveExternalFolderReferenceUseCase.invoke',
        ),
      );
    }
  }
}
