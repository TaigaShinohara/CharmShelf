// Application layer: coordinates domain contracts with repository providers.
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:private_shelf/core/services/storage_sandbox.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_trashed_media_use_case.g.dart';

@Riverpod(keepAlive: true)
RestoreTrashedMediaUseCase restoreTrashedMediaUseCase(
  Ref ref,
) {
  return RestoreTrashedMediaUseCase(
    ref.read(fileServiceProvider),
    ref.read(mediaRepositoryProvider.future),
    ref.read(operationJournalServiceProvider),
  );
}

class RestoreTrashedMediaUseCase {
  RestoreTrashedMediaUseCase(
    this._files,
    this._repositoryFuture,
    this._journal,
  );

  final FileService _files;
  final Future<MediaRepository> _repositoryFuture;
  final OperationJournalService _journal;

  Future<Result<void, AppError>> invoke(
    MediaItem root, {
    String? newName,
    String? newParentPath,
  }) async {
    try {
      return await _invoke(
        root,
        newName: newName,
        newParentPath: newParentPath,
      );
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to restore item from Trash',
          original: e,
          stackTrace: st,
          context: 'RestoreTrashedMediaUseCase.invoke',
        ),
      );
    }
  }

  Future<Result<void, AppError>> _invoke(
    MediaItem root, {
    String? newName,
    String? newParentPath,
  }) async {
    if (!root.isTrashed || !root.isTrashRoot) {
      return Result.failure(AppError.validation('Item is not a trash root'));
    }
    final repository = await _repositoryFuture;
    // 同じ起動中の再試行でも、以前の復元意図を上書きする前に回復する。
    for (final entry in await _journal.readAll()) {
      if (entry.kind == OperationKind.delete &&
          entry.payload['rootItemId'] == root.id &&
          entry.payload['restoreTargetPath'] is String) {
        final recovery = await OperationRecoveryService(
          _journal,
          _files,
          repository,
        ).recoverPendingRestore(entry);
        if (recovery.isFailure) return recovery;
        final current = await repository.getById(root.id);
        if (current.isFailure) return Result.failure(current.errorOrNull!);
        if (current.dataOrNull?.isTrashed == false) return Result.success(null);
      }
    }
    final originalPath = root.path;
    final originalParentPath = root.parentPath;
    final originalTrashRootPath = root.trashRootPath ?? root.path;
    final trashPath = root.trashPath;

    if (newName != null && FileNameValidator.validate(newName) != null) {
      return Result.failure(AppError.validation('復元するファイル名が不正です'));
    }
    if (root.sourceType == MediaSourceType.externalReference &&
        (newName != null || newParentPath != null)) {
      return Result.failure(AppError.validation('外部参照の復元先は変更できません'));
    }
    var targetPath = root.path;
    var targetParentPath = root.parentPath;

    if (newName != null && newName.isNotEmpty) {
      targetPath = p.join(p.dirname(targetPath), newName);
    }
    if (newParentPath != null) {
      final name = p.basename(targetPath);
      targetParentPath = newParentPath.isEmpty ? null : newParentPath;
      targetPath = p.join(
        newParentPath.isEmpty ? 'library' : newParentPath,
        name,
      );
    }

    if (root.sourceType == MediaSourceType.localCopy) {
      StorageSandbox.resolveRelative(
        '/',
        targetPath,
        allowedTopLevelDirectories: {'library'},
      );
    }
    final conflicts = await _getRestoreConflicts(
      repository,
      originalTrashRootPath,
      originalPath,
      targetPath,
    );
    if (conflicts.isFailure) return Result.failure(conflicts.errorOrNull!);
    if (conflicts.dataOrNull case final paths? when paths.isNotEmpty) {
      return Result.failure(
        AppError.validation(
          'Restore destination conflicts with an active library item',
          context: 'RestoreTrashedMediaUseCase.invoke',
        ).withAdditionalData({'conflictingPaths': paths}),
      );
    }

    final targetChanged =
        targetPath != originalPath || targetParentPath != originalParentPath;
    final isLocal = root.sourceType == MediaSourceType.localCopy;
    if (isLocal && (trashPath == null || trashPath.isEmpty)) {
      return Result.failure(AppError.file('Trash path is missing'));
    }
    if (isLocal) {
      final exists = await _files.managedEntityExists(trashPath!);
      if (exists.isFailure) return Result.failure(exists.errorOrNull!);
      if (exists.dataOrNull != true) {
        // 欠損したごみ箱項目へ復元意図を書き込み、次回起動を妨げない。
        return Result.failure(AppError.file('Trash file is unavailable'));
      }
    }
    final operationId =
        await _findDeleteOperationId(root.id, trashPath) ?? const Uuid().v4();
    final deletion = OperationJournalEntry(
      id: operationId,
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': root.id,
        'originalPath': originalTrashRootPath,
        'trashPath': trashPath ?? '',
        'isLocal': isLocal,
      },
    );
    // 物理移動より前に復元先を永続化する。DB更新前後の終了を区別して再開できる。
    await _journal.write(
      deletion.copyWith(
        payload: {
          ...deletion.payload,
          'restoreTargetPath': targetPath,
          'restoreTargetParentPath': targetParentPath,
        },
      ),
    );
    if (isLocal) {
      final restore = await _files.restoreStagedDeletion(
        trashPath!,
        targetPath,
      );
      if (restore.isFailure) {
        if (restore.errorOrNull?.additionalData?['moveStarted'] == false) {
          // 移動前の衝突と確定した場合だけ意図を戻し、別名での再試行を許す。
          await _journal.write(deletion);
        }
        // 部分移動の可能性がある失敗では、回復に必要な意図を残す。
        return restore;
      }
    }
    final databaseRestore = targetChanged
        ? await repository.restoreGraphFromTrash(
            originalTrashRootPath,
            targetRootPath: targetPath,
            targetParentPath: targetParentPath,
          )
        : await repository.restoreGraphFromTrash(originalTrashRootPath);
    if (databaseRestore.isFailure) {
      if (isLocal) {
        final rollback = await _files.stageDeletion(targetPath, trashPath!);
        if (rollback.isFailure) return rollback;
      }
      await _journal.write(deletion);
      return databaseRestore;
    }
    try {
      await _journal.remove(operationId);
    } catch (error, stackTrace) {
      // 復元は完了済み。残った記録は起動時に安全に除去し、重複操作を促さない。
      AppLogger.w(LogTag.storage, '復元済みジャーナルの清掃を次回起動へ延期', error, stackTrace);
    }
    return Result.success(null);
  }

  Future<String?> _findDeleteOperationId(
    int rootItemId,
    String? trashPath,
  ) async {
    if (trashPath != null) {
      final segments = p.split(trashPath);
      if (segments.length >= 2 && segments.first == '.trash') {
        return segments[1];
      }
    }
    for (final entry in await _journal.readAll()) {
      if (entry.kind == OperationKind.delete &&
          entry.payload['rootItemId'] == rootItemId) {
        return entry.id;
      }
    }
    return null;
  }

  Future<Result<List<String>, AppError>> _getRestoreConflicts(
    MediaRepository repository,
    String trashRootPath,
    String originalRootPath,
    String targetRootPath,
  ) async {
    final trashedItems = await repository.getTrashedItems(trashRootPath);
    if (trashedItems.isFailure) {
      return Result.failure(trashedItems.errorOrNull!);
    }

    final trashedCollections = await repository.getTrashedCollections(
      trashRootPath,
    );
    if (trashedCollections.isFailure) {
      return Result.failure(trashedCollections.errorOrNull!);
    }

    final candidatePaths = <String>{};
    for (final item in trashedItems.dataOrNull ?? const <MediaItem>[]) {
      final path = _mapRestorePath(
        originalRootPath: originalRootPath,
        targetRootPath: targetRootPath,
        path: item.path,
      );
      if (path != null) candidatePaths.add(path);
    }
    for (final collection
        in trashedCollections.dataOrNull ?? const <MediaCollection>[]) {
      final path = _mapRestorePath(
        originalRootPath: originalRootPath,
        targetRootPath: targetRootPath,
        path: collection.path,
      );
      if (path != null) candidatePaths.add(path);
    }

    final conflicts = <String>{};
    for (final path in candidatePaths) {
      final item = await repository.getByPath(path, includeTrashed: false);
      if (item.isFailure) return Result.failure(item.errorOrNull!);
      if (item.dataOrNull != null) {
        conflicts.add(path);
      }

      final collection = await repository.getCollectionByPath(
        path,
        includeTrashed: false,
      );
      if (collection.isFailure) return Result.failure(collection.errorOrNull!);
      if (collection.dataOrNull != null) {
        conflicts.add(path);
      }
    }

    final sorted = conflicts.toList()..sort();
    return Result.success(sorted);
  }

  String? _mapRestorePath({
    required String originalRootPath,
    required String targetRootPath,
    required String path,
  }) {
    if (path == originalRootPath) return targetRootPath;
    if (!p.isWithin(originalRootPath, path)) return null;
    final relative = p.relative(path, from: originalRootPath);
    return p.join(targetRootPath, relative);
  }
}
