// Application layer: coordinates domain contracts with repository providers.
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'duplicate_media_use_case.g.dart';

@Riverpod(keepAlive: true)
DuplicateMediaUseCase duplicateMediaUseCase(Ref ref) {
  return DuplicateMediaUseCase(
    ref.read(mediaRepositoryProvider.future),
    ref.read(fileServiceProvider),
    ref.read(operationJournalServiceProvider),
  );
}

class DuplicateMediaUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;
  final FileService _fileService;
  final OperationJournalService? _journal;
  final _uuid = const Uuid();

  DuplicateMediaUseCase(
    this._mediaRepositoryFuture,
    this._fileService, [
    this._journal,
  ]);

  /// メディア項目を複製する
  /// ※内部モード（localCopy）のみを想定
  /// [targetParentPath]: 複製先の親フォルダパス（null の場合は現在のフォルダと同じ場所）
  Future<Result<MediaItem, AppError>> invoke(
    MediaItem item, {
    String? targetParentPath,
  }) async {
    // 安全のため内部モードかチェック
    if (item.sourceType != MediaSourceType.localCopy) {
      return Result.failure(
        AppError.validation(
          '外部参照アイテムの複製はサポートされていません。',
          context: 'DuplicateMediaUseCase.invoke',
        ),
      );
    }

    MediaRepository? repo;
    String? copiedRootPath;
    final createdItemIds = <int>[];
    final createdCollectionIds = <int>[];
    final createdThumbnailPaths = <String>[];
    final operationId = _uuid.v4();

    try {
      repo = await _mediaRepositoryFuture;

      // 1. パスの正規化（library/ プレフィックスを強制）
      String normalize(String path) {
        if (path.isEmpty) return 'library';
        if (p.split(path).first == 'library') return path;
        return p.join('library', path);
      }

      final oldPath = normalize(item.path);
      final ext = p.extension(oldPath);
      final nameWithoutExt = p.basenameWithoutExtension(oldPath);

      // コピー先パスの決定
      // targetParentPath が指定されていればそれを使用、そうでなければ元の親を使用
      final effectiveParentPath = targetParentPath ?? item.parentPath;

      final newName =
          '${nameWithoutExt}_copy_${_uuid.v4().substring(0, 4)}$ext';

      final String newRelativePath;
      if (effectiveParentPath == null || effectiveParentPath.isEmpty) {
        newRelativePath = p.join('library', newName);
      } else {
        newRelativePath = p.join(normalize(effectiveParentPath), newName);
      }

      var journalEntry = OperationJournalEntry(
        id: operationId,
        kind: OperationKind.duplicate,
        stage: OperationStage.planned,
        payload: {'rootPath': newRelativePath},
      );
      await _journal?.write(journalEntry);

      // 2. 物理的なコピーを実行 (ファイル/フォルダ共通)
      final copyResult = await _fileService.copyEntity(
        oldPath,
        newRelativePath,
      );
      if (copyResult.isFailure) {
        await _journal?.remove(operationId);
        return Result.failure(copyResult.errorOrNull!);
      }
      copiedRootPath = newRelativePath;
      journalEntry = journalEntry.copyWith(stage: OperationStage.staged);
      await _journal?.write(journalEntry);

      // 3. ルート項目の複製
      final rootResult = await _duplicateSingleItem(
        item,
        newRelativePath,
        effectiveParentPath,
        repo,
        createdItemIds,
        createdCollectionIds,
        createdThumbnailPaths,
      );
      if (rootResult.isFailure) {
        return await _rollbackDuplicate(
          repo,
          newRelativePath,
          createdItemIds,
          createdCollectionIds,
          createdThumbnailPaths,
          rootResult.errorOrNull!,
          operationId,
        );
      }
      final newItem = rootResult.dataOrNull!;

      // 4. フォルダの場合は配下のアイテムを再帰的に複製
      if (item.type == MediaType.folder) {
        final descendantsResult = await repo.getDescendants(oldPath);
        if (descendantsResult.isFailure) {
          return await _rollbackDuplicate(
            repo,
            newRelativePath,
            createdItemIds,
            createdCollectionIds,
            createdThumbnailPaths,
            descendantsResult.errorOrNull!,
            operationId,
          );
        }
        final descendants = descendantsResult.dataOrNull ?? [];
        for (final child in descendants) {
          // 新しい相対パスと親パスを計算
          final relativeToRoot = p.relative(child.path, from: oldPath);
          final newChildPath = p.join(newRelativePath, relativeToRoot);

          String? newChildParentPath;
          if (child.parentPath != null) {
            if (child.parentPath == oldPath) {
              newChildParentPath = newRelativePath;
            } else {
              final parentRelativeToRoot = p.relative(
                child.parentPath!,
                from: oldPath,
              );
              newChildParentPath = p.join(
                newRelativePath,
                parentRelativeToRoot,
              );
            }
          }

          final childResult = await _duplicateSingleItem(
            child,
            newChildPath,
            newChildParentPath,
            repo,
            createdItemIds,
            createdCollectionIds,
            createdThumbnailPaths,
          );
          if (childResult.isFailure) {
            return await _rollbackDuplicate(
              repo,
              newRelativePath,
              createdItemIds,
              createdCollectionIds,
              createdThumbnailPaths,
              childResult.errorOrNull!,
              operationId,
            );
          }
        }
      }

      journalEntry = journalEntry.copyWith(stage: OperationStage.committed);
      await _journal?.write(journalEntry);
      await _journal?.remove(operationId);
      return Result.success(newItem);
    } catch (e, st) {
      final error = AppError.unknown(
        '複製に失敗しました: $e',
        original: e,
        stackTrace: st,
        context: 'DuplicateMediaUseCase.invoke',
      );
      if (repo != null && copiedRootPath != null) {
        return _rollbackDuplicate(
          repo,
          copiedRootPath,
          createdItemIds,
          createdCollectionIds,
          createdThumbnailPaths,
          error,
          operationId,
        );
      }
      return Result.failure(error);
    }
  }

  /// 単一のアイテム (とそれに関連するコレクション) を複製する
  Future<Result<MediaItem, AppError>> _duplicateSingleItem(
    MediaItem item,
    String newRelativePath,
    String? newParentPath,
    MediaRepository repo,
    List<int> createdItemIds,
    List<int> createdCollectionIds,
    List<String> createdThumbnailPaths,
  ) async {
    // サムネイルの複製
    String? newThumbnailPath;
    if (item.thumbnailPath != null) {
      final thumbExt = p.extension(item.thumbnailPath!);
      newThumbnailPath = p.join('.thumbnails', '${_uuid.v4()}$thumbExt');
      final thumbnailCopy = await _fileService.copyEntity(
        item.thumbnailPath!,
        newThumbnailPath,
      );
      if (thumbnailCopy.isFailure) {
        return Result.failure(thumbnailCopy.errorOrNull!);
      }
      createdThumbnailPaths.add(newThumbnailPath);
    }

    // MediaItem の複製
    final newItem = MediaItem()
      ..uid = _uuid.v4()
      ..path = newRelativePath
      ..originalPath = item.originalPath
      ..type = item.type
      ..sourceType = item.sourceType
      ..size = item.size
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..parentPath = newParentPath
      ..thumbnailPath = newThumbnailPath;

    final saveResult = await repo.save(newItem);
    if (saveResult.isFailure) return Result.failure(saveResult.errorOrNull!);
    if (newItem.id > 0) createdItemIds.add(newItem.id);

    // 対応する MediaCollection (カタログ情報) があれば複製
    final oldCollectionResult = await repo.getCollectionByPath(item.path);
    if (oldCollectionResult.isFailure) {
      return Result.failure(oldCollectionResult.errorOrNull!);
    }
    if (oldCollectionResult.dataOrNull != null) {
      final oldColl = oldCollectionResult.dataOrNull!;
      final newColl = MediaCollection()
        ..uid = _uuid.v4()
        ..path = newRelativePath
        ..title = oldColl.title
        ..alias = oldColl.alias
        ..type = oldColl.type
        ..isCatalog = oldColl.isCatalog
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..coverImagePath =
            null // カバー画像は再設定が必要かもしれないが、一旦 null
        ..isFavorite = oldColl.isFavorite
        ..notes = oldColl.notes
        ..isPinned = oldColl.isPinned
        ..isArchived = oldColl.isArchived
        ..isHidden = oldColl.isHidden
        ..defaultSortOrder = oldColl.defaultSortOrder
        ..defaultViewMode = oldColl.defaultViewMode
        ..splitSpreadView = oldColl.splitSpreadView
        ..isHeaderExpanded = oldColl.isHeaderExpanded
        ..tier = oldColl.tier;

      // タグの引き継ぎ
      await oldColl.tags.load();
      newColl.tags.addAll(oldColl.tags);

      final collectionSave = await repo.saveCollection(newColl);
      if (collectionSave.isFailure) {
        return Result.failure(collectionSave.errorOrNull!);
      }
      if (newColl.id > 0) createdCollectionIds.add(newColl.id);
    }

    return Result.success(newItem);
  }

  Future<Result<MediaItem, AppError>> _rollbackDuplicate(
    MediaRepository repo,
    String copiedRootPath,
    List<int> itemIds,
    List<int> collectionIds,
    List<String> thumbnailPaths,
    AppError originalError,
    String operationId,
  ) async {
    try {
      final databaseRollback = await repo.deleteGraph(itemIds, collectionIds);
      if (databaseRollback.isFailure) {
        return Result.failure(
          AppError.database(
            'Duplicate failed and database rollback also failed',
            context: 'DuplicateMediaUseCase._rollbackDuplicate',
          ),
        );
      }
      final rootCleanup = await _fileService.deleteFile(copiedRootPath);
      if (rootCleanup.isFailure) {
        return Result.failure(
          AppError.file(
            'Duplicate failed and copied file cleanup also failed',
            context: 'DuplicateMediaUseCase._rollbackDuplicate',
          ),
        );
      }
      for (final thumbnailPath in thumbnailPaths) {
        final cleanup = await _fileService.deleteFile(thumbnailPath);
        if (cleanup.isFailure) {
          return Result.failure(
            AppError.file(
              'Duplicate failed and thumbnail cleanup also failed',
              context: 'DuplicateMediaUseCase._rollbackDuplicate',
            ),
          );
        }
      }
      await _journal?.remove(operationId);
      return Result.failure(originalError);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'Duplicate failed and rollback threw an exception: $e',
          original: e,
          stackTrace: st,
          context: 'DuplicateMediaUseCase._rollbackDuplicate',
        ),
      );
    }
  }
}
