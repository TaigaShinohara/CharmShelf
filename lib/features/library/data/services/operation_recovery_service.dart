import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/import_copy_artifacts.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:path/path.dart' as p;

class OperationRecoveryService {
  OperationRecoveryService(
    this._journal,
    this._files,
    this._repository, {
    DateTime Function()? now,
    Future<void> Function(Uri uri)? releaseExternalAccess,
    this.allowMissingCommittedTrash = false,
    this.additionalProtectedTrashIds,
  }) : _now = now ?? DateTime.now,
       _releaseExternalAccess = releaseExternalAccess ?? _noopRelease;

  final OperationJournalService _journal;
  final FileService _files;
  final MediaRepository _repository;
  final DateTime Function() _now;
  final Future<void> Function(Uri uri) _releaseExternalAccess;
  final bool allowMissingCommittedTrash;
  final Future<Set<String>> Function()? additionalProtectedTrashIds;
  final Set<int> _missingCommittedTrashIds = {};
  int get missingCommittedTrashCount => _missingCommittedTrashIds.length;

  static const _orphanGracePeriod = Duration(hours: 24);

  static Future<void> _noopRelease(Uri uri) async {}

  Future<Result<void, AppError>> recover() async {
    _missingCommittedTrashIds.clear();
    try {
      final report = await _journal.readReport();
      final entries = report.entries;
      var firstError = report.hasCorruption
          ? AppError.file('操作の復旧記録を確認できません。データを保持して復旧を停止しました')
          : null;
      for (final entry in entries) {
        try {
          final result = await switch (entry.kind) {
            OperationKind.delete => _recoverDelete(entry),
            OperationKind.import => _recoverImport(entry),
            OperationKind.move => _recoverMove(entry),
            OperationKind.createFolder => _recoverCreateFolder(entry),
            OperationKind.duplicate => _recoverDuplicate(entry),
            OperationKind.removeExternalFolderReference =>
              _recoverExternalFolderReferenceRemoval(entry),
          };
          if (result.isFailure) firstError ??= result.errorOrNull;
        } catch (error, stackTrace) {
          firstError ??= AppError.file(
            '操作の復旧に失敗しました',
            original: error,
            stackTrace: stackTrace,
          );
        }
      }
      // 一件の失敗で無関係な復旧を止めない。異常の可能性がある操作IDだけは清掃から保護する。
      if (firstError != null) return Result.failure(firstError);
      final orphanCleanup = await _cleanupOrphanedTrash(
        entries,
        protectedOperationIds: report.quarantinedOperationIds,
      );
      if (orphanCleanup.isFailure) return orphanCleanup;
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Operation recovery failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<Result<void, AppError>> _cleanupOrphanedTrash(
    List<OperationJournalEntry> journalEntries, {
    Set<String> protectedOperationIds = const {},
  }) async {
    final rootsResult = await _repository.getTrashedRoots();
    if (rootsResult.isFailure) return Result.failure(rootsResult.errorOrNull!);
    final protectedIds = {
      ...journalEntries.map((entry) => entry.id),
      ...protectedOperationIds,
      ...?await additionalProtectedTrashIds?.call(),
    };
    for (final root in rootsResult.dataOrNull ?? const <MediaItem>[]) {
      final trashPath = root.trashPath;
      if (trashPath == null) continue;
      final segments = p.split(trashPath);
      if (segments.length >= 2 && segments.first == '.trash') {
        protectedIds.add(segments[1]);
      }
    }

    final stagingResult = await _files.listTrashStagingEntries();
    if (stagingResult.isFailure) {
      return Result.failure(stagingResult.errorOrNull!);
    }
    final cutoff = _now().subtract(_orphanGracePeriod);
    for (final entry
        in stagingResult.dataOrNull ?? const <TrashStagingEntry>[]) {
      if (protectedIds.contains(entry.operationId) ||
          entry.modifiedAt.isAfter(cutoff)) {
        continue;
      }
      final delete = await _files.deleteFile('.trash/${entry.operationId}');
      if (delete.isFailure) return delete;
    }
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverExternalFolderReferenceRemoval(
    OperationJournalEntry entry,
  ) async {
    final itemIds = (entry.payload['itemIds'] as List).cast<int>();
    final collectionIds = (entry.payload['collectionIds'] as List).cast<int>();
    final originalPath = entry.payload['originalPath'] as String;

    final deleteResult = await _repository.deleteGraph(itemIds, collectionIds);
    if (deleteResult.isFailure) return deleteResult;

    await _releaseExternalAccess(Uri.parse(originalPath));
    await _journal.remove(entry.id);
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverDelete(
    OperationJournalEntry entry,
  ) async {
    final rootItemId = entry.payload['rootItemId'] as int;
    final originalPath = entry.payload['originalPath'] as String;
    final trashPath = entry.payload['trashPath'] as String;
    final isLocal = entry.payload['isLocal'] as bool;
    final itemResult = await _repository.getById(rootItemId);
    if (itemResult.isFailure) return Result.failure(itemResult.errorOrNull!);

    if (entry.stage == OperationStage.committed) {
      if (entry.payload['restoreTargetPath'] is String) {
        return recoverPendingRestore(entry);
      }
      final item = itemResult.dataOrNull;
      if (item == null) {
        if (isLocal) {
          final trashExists = await _files.managedEntityExists(trashPath);
          if (trashExists.isFailure) {
            return Result.failure(trashExists.errorOrNull!);
          }
          if (trashExists.dataOrNull == true) {
            final purge = await _files.deleteFile(trashPath);
            if (purge.isFailure) return purge;
          }
        }
        final cleanupPaths = entry.payload['cleanupPaths'];
        if (cleanupPaths is List) {
          for (final path in cleanupPaths.whereType<String>()) {
            final exists = await _files.managedEntityExists(path);
            if (exists.isFailure) return Result.failure(exists.errorOrNull!);
            if (exists.dataOrNull == true) {
              final purge = await _files.deleteFile(path);
              if (purge.isFailure) return purge;
            }
          }
        }
        if (!isLocal) {
          final remaining = await _repository.getByPath(originalPath);
          if (remaining.isFailure) {
            return Result.failure(remaining.errorOrNull!);
          }
          if (remaining.dataOrNull == null) {
            await _releaseExternalAccess(Uri.parse(originalPath));
          }
        }
        await _journal.remove(entry.id);
        return Result.success(null);
      }
      if (!item.isTrashed) {
        if (!isLocal) {
          // External references have no staged entity. A live DB item proves
          // that restore committed and only journal cleanup was interrupted.
          await _journal.remove(entry.id);
          return Result.success(null);
        }
        final originalExists = await _files.managedEntityExists(item.path);
        if (originalExists.isFailure) {
          return Result.failure(originalExists.errorOrNull!);
        }
        final trashExists = await _files.managedEntityExists(trashPath);
        if (trashExists.isFailure) {
          return Result.failure(trashExists.errorOrNull!);
        }
        if (originalExists.dataOrNull == true &&
            trashExists.dataOrNull == false) {
          // Physical and DB restore both committed; only journal removal was
          // interrupted.
          await _journal.remove(entry.id);
          return Result.success(null);
        }
        return Result.failure(
          AppError.file(
            'Committed trash entry has an ambiguous restored state',
            context: 'OperationRecoveryService._recoverDelete',
          ).withAdditionalData({
            'operationId': entry.id,
            'originalExists': originalExists.dataOrNull,
            'trashExists': trashExists.dataOrNull,
          }),
        );
      }
      if (isLocal) {
        final trashExists = await _files.managedEntityExists(trashPath);
        if (trashExists.isFailure) {
          return Result.failure(trashExists.errorOrNull!);
        }
        if (trashExists.dataOrNull != true) {
          // 完了済みの削除だけを保留できる。復元途中・記録不一致は対象外。
          if (trashExists.dataOrNull == false &&
              allowMissingCommittedTrash &&
              item.isTrashRoot &&
              item.path == originalPath &&
              item.trashRootPath == originalPath &&
              item.trashPath == trashPath &&
              item.sourceType == MediaSourceType.localCopy) {
            final original = await _files.managedEntityExists(originalPath);
            if (original.isFailure) {
              return Result.failure(original.errorOrNull!);
            }
            if (original.dataOrNull == false) {
              _missingCommittedTrashIds.add(item.id);
              return Result.success(null);
            }
          }
          return Result.failure(
            AppError.file(
              'Committed trash entry is missing its staged file',
              context: 'OperationRecoveryService._recoverDelete',
            ).withAdditionalData({'operationId': entry.id}),
          );
        }
      }
      return Result.success(null);
    }

    if (isLocal) {
      final trashExists = await _files.managedEntityExists(trashPath);
      if (trashExists.isFailure) {
        return Result.failure(trashExists.errorOrNull!);
      }
      if (trashExists.dataOrNull == true) {
        final fileResult = itemResult.dataOrNull != null
            ? await _files.restoreStagedDeletion(trashPath, originalPath)
            : await _files.deleteFile(trashPath);
        if (fileResult.isFailure) return fileResult;
      }
    }
    await _journal.remove(entry.id);
    return Result.success(null);
  }

  /// 復元意図は物理移動前に記録される。DBの原子的更新結果と実体を照合する。
  Future<Result<void, AppError>> recoverPendingRestore(
    OperationJournalEntry entry,
  ) async {
    final targetPath = entry.payload['restoreTargetPath'] as String;
    final rootPath = entry.payload['originalPath'] as String;
    final trashPath = entry.payload['trashPath'] as String;
    final isLocal = entry.payload['isLocal'] as bool;
    final itemResult = await _repository.getById(
      entry.payload['rootItemId'] as int,
    );
    if (itemResult.isFailure) return Result.failure(itemResult.errorOrNull!);
    final item = itemResult.dataOrNull;
    if (item == null) {
      return Result.failure(AppError.database('復元対象の管理情報がありません'));
    }
    if (isLocal) {
      final trash = await _files.managedEntityExists(trashPath);
      if (trash.isFailure) return Result.failure(trash.errorOrNull!);
      final target = await _files.managedEntityExists(targetPath);
      if (target.isFailure) return Result.failure(target.errorOrNull!);
      if (trash.dataOrNull == true &&
          target.dataOrNull == false &&
          item.isTrashed) {
        // 移動前に終了、またはロールバック済み。元のごみ箱記録へ戻す。
        final payload = Map<String, dynamic>.from(entry.payload)
          ..remove('restoreTargetPath')
          ..remove('restoreTargetParentPath');
        await _journal.write(entry.copyWith(payload: payload));
        return Result.success(null);
      }
      if (trash.dataOrNull != false || target.dataOrNull != true) {
        return Result.failure(AppError.file('復元元と復元先の状態を安全に確定できません'));
      }
    }
    if (item.isTrashed) {
      if (item.path != rootPath ||
          (item.trashRootPath != null && item.trashRootPath != rootPath)) {
        return Result.failure(AppError.database('復元対象のパスが記録と一致しません'));
      }
      final restored = targetPath == rootPath
          ? await _repository.restoreGraphFromTrash(rootPath)
          : await _repository.restoreGraphFromTrash(
              rootPath,
              targetRootPath: targetPath,
              targetParentPath:
                  entry.payload['restoreTargetParentPath'] as String?,
            );
      if (restored.isFailure) return restored;
    } else if (item.path != targetPath) {
      return Result.failure(AppError.database('復元済みアイテムのパスが記録と一致しません'));
    }
    await _journal.remove(entry.id);
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverImport(
    OperationJournalEntry entry,
  ) async {
    final path = entry.payload['path'] as String;
    final thumbnailPath = entry.payload['thumbnailPath'] as String?;
    if (FileService.isImportActive(entry.id)) {
      return Result.failure(AppError.file('Import operation is still active'));
    }
    final artifacts = entry.payload.containsKey('copyArtifacts')
        ? ImportCopyArtifacts.fromMap(
            entry.payload['copyArtifacts'],
            operationId: entry.id,
            destinationPath: path,
          )
        : null;
    if (artifacts != null) {
      final validation = await _files.validateImportCopyArtifacts(
        artifacts,
        destinationWasStaged: entry.stage != OperationStage.planned,
      );
      if (validation.isFailure) return validation;
    }
    final item = await _repository.getByPath(path);
    if (item.isFailure) return Result.failure(item.errorOrNull!);
    if (item.dataOrNull == null) {
      final deleteResult = await _files.deleteFile(path);
      if (deleteResult.isFailure) return deleteResult;
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final thumbnailResult = await _files.deleteFile(thumbnailPath);
        if (thumbnailResult.isFailure) return thumbnailResult;
      }
    }
    if (artifacts != null) {
      final cleanup = await _files.cleanupImportCopyArtifacts(artifacts);
      if (cleanup.isFailure) return cleanup;
    }
    await _journal.remove(entry.id);
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverMove(
    OperationJournalEntry entry,
  ) async {
    final rootItemId = entry.payload['rootItemId'] as int;
    final oldPath = entry.payload['oldPath'] as String;
    final newPath = entry.payload['newPath'] as String;
    final newParentPath = entry.payload['newParentPath'] as String?;
    final newTitle = entry.payload['newTitle'] as String?;
    final isLocal = entry.payload['isLocal'] as bool;

    final itemResult = await _repository.getById(rootItemId);
    if (itemResult.isFailure) return Result.failure(itemResult.errorOrNull!);
    final item = itemResult.dataOrNull;
    if (item == null) {
      return Result.failure(
        AppError.database(
          'Cannot recover move because the root item is missing',
          context: 'OperationRecoveryService._recoverMove',
        ).withAdditionalData({'operationId': entry.id}),
      );
    }

    var oldExists = true;
    var newExists = false;
    if (isLocal) {
      final oldResult = await _files.managedEntityExists(oldPath);
      if (oldResult.isFailure) return Result.failure(oldResult.errorOrNull!);
      final newResult = await _files.managedEntityExists(newPath);
      if (newResult.isFailure) return Result.failure(newResult.errorOrNull!);
      oldExists = oldResult.dataOrNull ?? false;
      newExists = newResult.dataOrNull ?? false;
      if (oldExists == newExists) {
        return Result.failure(
          AppError.file(
            oldExists
                ? 'Cannot recover move because both source and destination exist'
                : 'Cannot recover move because source and destination are missing',
            context: 'OperationRecoveryService._recoverMove',
          ).withAdditionalData({'operationId': entry.id}),
        );
      }
    }

    if (item.path == newPath) {
      // DBコミット後の停止は前進復旧する。未更新の関連レコードだけが対象になる。
      final oldCollection = await _repository.getCollectionByPath(oldPath);
      if (oldCollection.isFailure) {
        return Result.failure(oldCollection.errorOrNull!);
      }
      final collection = oldCollection.dataOrNull;
      if (collection != null) {
        collection
          ..path = newPath
          ..updatedAt = DateTime.now();
        if (newTitle != null && newTitle.isNotEmpty) {
          collection.title = newTitle;
        }
        final saveCollection = await _repository.saveCollection(collection);
        if (saveCollection.isFailure) {
          return Result.failure(saveCollection.errorOrNull!);
        }
      }
      final descendants = await _repository.updatePathsForMovedDirectory(
        oldPath,
        newPath,
      );
      if (descendants.isFailure) {
        return Result.failure(descendants.errorOrNull!);
      }
    } else if (item.path == oldPath) {
      // DBコミット前の停止は物理実体を旧位置へ戻す。
      if (isLocal && newExists) {
        final restore = await _files.moveEntity(newPath, oldPath);
        if (restore.isFailure) return restore;
      }
      item.parentPath = p.dirname(oldPath) == 'library'
          ? null
          : p.dirname(oldPath);
    } else {
      return Result.failure(
        AppError.database(
          'Cannot recover move because the root item path is unexpected',
          context: 'OperationRecoveryService._recoverMove',
        ).withAdditionalData({
          'operationId': entry.id,
          'itemPath': item.path,
          'oldPath': oldPath,
          'newPath': newPath,
          'newParentPath': newParentPath,
        }),
      );
    }

    await _journal.remove(entry.id);
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverCreateFolder(
    OperationJournalEntry entry,
  ) async {
    final path = entry.payload['path'] as String;
    final itemResult = await _repository.getByPath(path);
    if (itemResult.isFailure) return Result.failure(itemResult.errorOrNull!);
    if (itemResult.dataOrNull == null) {
      final existsResult = await _files.managedEntityExists(path);
      if (existsResult.isFailure) {
        return Result.failure(existsResult.errorOrNull!);
      }
      if (existsResult.dataOrNull == true) {
        final deleteResult = await _files.deleteFile(path);
        if (deleteResult.isFailure) return deleteResult;
      }
    }
    await _journal.remove(entry.id);
    return Result.success(null);
  }

  Future<Result<void, AppError>> _recoverDuplicate(
    OperationJournalEntry entry,
  ) async {
    // committed は複製グラフと実体の作成が完了した印。プロセスが
    // ジャーナル削除直前に終了しても、完成済みデータをロールバックしない。
    if (entry.stage == OperationStage.committed) {
      await _journal.remove(entry.id);
      return Result.success(null);
    }

    final rootPath = entry.payload['rootPath'] as String;

    final rootItemResult = await _repository.getByPath(rootPath);
    if (rootItemResult.isFailure) {
      return Result.failure(rootItemResult.errorOrNull!);
    }
    final descendantsResult = await _repository.getDescendants(rootPath);
    if (descendantsResult.isFailure) {
      return Result.failure(descendantsResult.errorOrNull!);
    }
    final rootCollectionResult = await _repository.getCollectionByPath(
      rootPath,
    );
    if (rootCollectionResult.isFailure) {
      return Result.failure(rootCollectionResult.errorOrNull!);
    }
    final descendantCollectionsResult = await _repository
        .getDescendantCollections(rootPath);
    if (descendantCollectionsResult.isFailure) {
      return Result.failure(descendantCollectionsResult.errorOrNull!);
    }

    final items = <MediaItem>{
      if (rootItemResult.dataOrNull != null) rootItemResult.dataOrNull!,
      ...?descendantsResult.dataOrNull,
    };
    final collections = <MediaCollection>{
      if (rootCollectionResult.dataOrNull != null)
        rootCollectionResult.dataOrNull!,
      ...?descendantCollectionsResult.dataOrNull,
    };
    final thumbnailPaths = items
        .map((item) => item.thumbnailPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();

    if (items.isNotEmpty || collections.isNotEmpty) {
      final deleteResult = await _repository.deleteGraph(
        items.map((item) => item.id).toList(growable: false),
        collections.map((collection) => collection.id).toList(growable: false),
      );
      if (deleteResult.isFailure) {
        return Result.failure(deleteResult.errorOrNull!);
      }
    }

    final rootExists = await _files.managedEntityExists(rootPath);
    if (rootExists.isFailure) return Result.failure(rootExists.errorOrNull!);
    if (rootExists.dataOrNull == true) {
      final deleteRoot = await _files.deleteFile(rootPath);
      if (deleteRoot.isFailure) return deleteRoot;
    }
    for (final thumbnailPath in thumbnailPaths) {
      final thumbnailExists = await _files.managedEntityExists(thumbnailPath);
      if (thumbnailExists.isFailure) {
        return Result.failure(thumbnailExists.errorOrNull!);
      }
      if (thumbnailExists.dataOrNull == true) {
        final deleteThumbnail = await _files.deleteFile(thumbnailPath);
        if (deleteThumbnail.isFailure) return deleteThumbnail;
      }
    }

    await _journal.remove(entry.id);
    return Result.success(null);
  }
}
