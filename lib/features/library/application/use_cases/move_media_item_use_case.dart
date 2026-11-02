// Application layer: coordinates domain contracts with repository providers.
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'move_media_item_use_case.g.dart';

@Riverpod(keepAlive: true)
MoveMediaItemUseCase moveMediaItemUseCase(Ref ref) {
  return MoveMediaItemUseCase(
    ref.read(mediaRepositoryProvider.future),
    ref.read(fileServiceProvider),
    ref.read(operationJournalServiceProvider),
  );
}

class MoveMediaItemUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;
  final FileService _fileService;
  final OperationJournalService? _journal;
  final Uuid _uuid = const Uuid();

  MoveMediaItemUseCase(
    this._mediaRepositoryFuture,
    this._fileService, [
    this._journal,
  ]);

  /// メディア項目を移動する
  /// [item]: 移動対象の MediaItem
  /// [newParentPath]: 新しい親フォルダの相対パス（ルートの場合は null）
  /// [newName]: 新しいファイル/フォルダ名（null の場合は現状の名前を維持）
  Future<Result<void, AppError>> invoke(
    MediaItem item,
    String? newParentPath, {
    String? newName,
  }) async {
    String? operationId;
    try {
      if (item.sourceType != MediaSourceType.localCopy) {
        return Result.failure(
          AppError.validation(
            'External references cannot be moved or renamed by this operation.',
            context: 'MoveMediaItemUseCase.invoke',
          ),
        );
      }
      final repo = await _mediaRepositoryFuture;

      // 1. パスの正規化（library/ プレフィックスを強制）
      String normalize(String path) {
        if (path.isEmpty) return 'library';
        final normalized = p.normalize(path);
        if (p.split(normalized).first == 'library') return normalized;
        return p.normalize(p.join('library', normalized));
      }

      final oldPath = normalize(item.path);
      final normalizedParentPath = newParentPath == null
          ? null
          : normalize(newParentPath);
      if (item.type == MediaType.folder &&
          normalizedParentPath != null &&
          (normalizedParentPath == oldPath ||
              p.isWithin(oldPath, normalizedParentPath))) {
        return Result.failure(
          AppError.validation(
            'Cannot move a folder into itself or its subfolders.',
          ),
        );
      }
      final currentName = p.basename(oldPath);
      final requestedName = newName?.trim();
      final targetName = requestedName == null || requestedName.isEmpty
          ? currentName
          : requestedName;

      final nameValidationError = FileNameValidator.validate(targetName);
      if (nameValidationError != null || p.basename(targetName) != targetName) {
        return Result.failure(
          AppError.validation(
            'Invalid file name: $targetName',
            context: 'MoveMediaItemUseCase.invoke',
          ),
        );
      }

      // 移動先の決定
      final String newRelativePath;
      if (normalizedParentPath == null || newParentPath!.isEmpty) {
        newRelativePath = p.join('library', targetName);
      } else {
        newRelativePath = p.join(normalizedParentPath, targetName);
      }

      if (oldPath == newRelativePath && item.path == oldPath) {
        return Result.success(null);
      }

      operationId = _uuid.v4();
      var journalEntry = OperationJournalEntry(
        id: operationId,
        kind: OperationKind.move,
        stage: OperationStage.planned,
        payload: {
          'rootItemId': item.id,
          'oldPath': oldPath,
          'newPath': newRelativePath,
          'newParentPath': normalizedParentPath,
          'newTitle': newName?.trim(),
          'isLocal': item.sourceType == MediaSourceType.localCopy,
        },
      );
      await _journal?.write(journalEntry);

      // 2. 物理ファイルの移動 (アプリ内コピーの場合)
      if (item.sourceType == MediaSourceType.localCopy) {
        final moveResult = await _fileService.moveEntity(
          oldPath,
          newRelativePath,
        );
        if (moveResult.isFailure) {
          await _journal?.remove(operationId);
          return moveResult;
        }
      }
      journalEntry = journalEntry.copyWith(stage: OperationStage.staged);
      await _journal?.write(journalEntry);

      // 3. DBの更新
      final originalItemPath = normalize(item.path);
      final originalParentPath = item.parentPath;
      final originalUpdatedAt = item.updatedAt;

      item.path = newRelativePath;
      item.parentPath = normalizedParentPath;
      item.updatedAt = DateTime.now();

      final saveResult = await repo.save(item);
      if (saveResult.isFailure) {
        final rollback = await _rollback(
          oldPath: oldPath,
          newPath: newRelativePath,
          movePhysical: item.sourceType == MediaSourceType.localCopy,
          item: item,
          originalPath: originalItemPath,
          originalParent: originalParentPath,
          originalUpdate: originalUpdatedAt,
        );
        if (rollback.isFailure) return rollback;
        await _journal?.remove(operationId);
        return Result.failure(saveResult.errorOrNull!);
      }

      // 4. 対応するMediaCollectionのパスとタイトルの更新
      // 登録済みのカタログ（フォルダ/ファイル問わず）のメタデータを維持するため
      final collectionResult = await repo.getCollectionByPath(originalItemPath);
      if (collectionResult.isFailure) {
        final rollback = await _rollback(
          oldPath: oldPath,
          newPath: newRelativePath,
          movePhysical: item.sourceType == MediaSourceType.localCopy,
          item: item,
          originalPath: originalItemPath,
          originalParent: originalParentPath,
          originalUpdate: originalUpdatedAt,
        );
        if (rollback.isFailure) return rollback;
        await _journal?.remove(operationId);
        return Result.failure(collectionResult.errorOrNull!);
      }
      MediaCollection? collection;
      DateTime? originalCollectionUpdate;
      String? originalCollectionTitle;
      String? originalCoverImagePath;

      if (collectionResult.isSuccess && collectionResult.dataOrNull != null) {
        collection = collectionResult.dataOrNull!;
        originalCollectionUpdate = collection.updatedAt;
        originalCollectionTitle = collection.title;
        originalCoverImagePath = collection.coverImagePath;

        collection.path = newRelativePath;
        if (newName != null && newName.trim().isNotEmpty) {
          collection.title = newName.trim();
        }
        final currentCover = collection.coverImagePath;
        if (currentCover != null &&
            (currentCover == originalItemPath ||
                p.isWithin(originalItemPath, currentCover))) {
          collection.coverImagePath = p.join(
            newRelativePath,
            p.relative(currentCover, from: originalItemPath),
          );
        }
        collection.updatedAt = DateTime.now();
        final colSaveResult = await repo.saveCollection(collection);

        if (colSaveResult.isFailure) {
          // ロールバック: Itemを元に戻し、物理ファイルも戻す
          final rollback = await _rollback(
            oldPath: oldPath,
            newPath: newRelativePath,
            movePhysical: item.sourceType == MediaSourceType.localCopy,
            item: item,
            originalPath: originalItemPath,
            originalParent: originalParentPath,
            originalUpdate: originalUpdatedAt,
          );
          if (rollback.isFailure) return rollback;
          await _journal?.remove(operationId);
          return Result.failure(colSaveResult.errorOrNull!);
        }
      }

      // フォルダ移動の場合、配下にあるアイテムの parentPath も再帰的に更新する
      if (item.type == MediaType.folder) {
        final updateChildrenResult = await repo.updatePathsForMovedDirectory(
          originalItemPath,
          newRelativePath,
        );
        if (updateChildrenResult.isFailure) {
          // ロールバック: 物理ファイル、Item、Collectionを戻す
          if (collection != null) {
            collection.path = originalItemPath;
            collection.title = originalCollectionTitle!;
            collection.coverImagePath = originalCoverImagePath;
            collection.updatedAt = originalCollectionUpdate!;
            final collectionRollback = await repo.saveCollection(collection);
            if (collectionRollback.isFailure) {
              return Result.failure(
                AppError.database(
                  'Move failed and collection rollback also failed',
                  context: 'MoveMediaItemUseCase.invoke',
                ).withAdditionalData({
                  'collectionId': collection.id,
                  'oldPath': originalItemPath,
                  'newPath': newRelativePath,
                }),
              );
            }
          }

          final rollback = await _rollback(
            oldPath: oldPath,
            newPath: newRelativePath,
            movePhysical: item.sourceType == MediaSourceType.localCopy,
            item: item,
            originalPath: originalItemPath,
            originalParent: originalParentPath,
            originalUpdate: originalUpdatedAt,
          );
          if (rollback.isFailure) return rollback;
          await _journal?.remove(operationId);
          return Result.failure(updateChildrenResult.errorOrNull!);
        }
      } else {
        // 単一ファイルの場合、本ファイルを参照しているコレクションのカバー画像パスを更新
        final updateCoverResult = await repo.updateCoverImagePath(
          originalItemPath,
          newRelativePath,
        );
        if (updateCoverResult.isFailure) {
          if (collection != null) {
            collection.path = originalItemPath;
            collection.title = originalCollectionTitle!;
            collection.updatedAt = originalCollectionUpdate!;
            await repo.saveCollection(collection);
          }
          final rollback = await _rollback(
            oldPath: oldPath,
            newPath: newRelativePath,
            movePhysical: item.sourceType == MediaSourceType.localCopy,
            item: item,
            originalPath: originalItemPath,
            originalParent: originalParentPath,
            originalUpdate: originalUpdatedAt,
            rollbackCoverPath: true,
          );
          if (rollback.isFailure) return rollback;
          await _journal?.remove(operationId);
          return Result.failure(updateCoverResult.errorOrNull!);
        }
      }

      journalEntry = journalEntry.copyWith(stage: OperationStage.committed);
      await _journal?.write(journalEntry);
      await _journal?.remove(operationId);
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('Move failed: $e', original: e, stackTrace: st),
      );
    }
  }

  /// 物理ファイルとDBレコードのロールバック
  Future<Result<void, AppError>> _rollback({
    required String oldPath,
    required String newPath,
    required bool movePhysical,
    MediaItem? item,
    String? originalPath,
    String? originalParent,
    DateTime? originalUpdate,
    bool rollbackCoverPath = false,
  }) async {
    // 先にインメモリ状態を戻し、補償処理自体が失敗しても誤状態を残さない。
    if (item != null) {
      item.path = originalPath!;
      item.parentPath = originalParent;
      item.updatedAt = originalUpdate!;
    }

    if (movePhysical) {
      final fileRollback = await _fileService.moveEntity(newPath, oldPath);
      if (fileRollback.isFailure) {
        return Result.failure(
          AppError.file(
            'Move failed and physical rollback also failed',
            context: 'MoveMediaItemUseCase._rollback',
          ).withAdditionalData({'oldPath': oldPath, 'newPath': newPath}),
        );
      }
    }

    if (item != null) {
      final repo = await _mediaRepositoryFuture;
      final dbRollback = await repo.save(item);
      if (dbRollback.isFailure) {
        return Result.failure(
          AppError.database(
            'Move failed and database rollback also failed',
            context: 'MoveMediaItemUseCase._rollback',
          ).withAdditionalData({'itemId': item.id, 'path': originalPath}),
        );
      }
      if (rollbackCoverPath && originalPath != null) {
        await repo.updateCoverImagePath(newPath, originalPath);
      }
    }
    return Result.success(null);
  }
}
