// Application layer: coordinates domain contracts with repository providers.
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permanently_delete_trashed_media_use_case.g.dart';

@Riverpod(keepAlive: true)
PermanentlyDeleteTrashedMediaUseCase permanentlyDeleteTrashedMediaUseCase(
  Ref ref,
) {
  return PermanentlyDeleteTrashedMediaUseCase(
    ref.read(fileServiceProvider),
    ref.read(mediaRepositoryProvider.future),
    ref.read(operationJournalServiceProvider),
    releaseExternalAccess: (uri) async {
      final storage = await ref.read(externalStorageServiceProvider.future);
      await storage.releasePersistedAccess(uri);
    },
  );
}

class PermanentlyDeleteTrashedMediaUseCase {
  PermanentlyDeleteTrashedMediaUseCase(
    this._files,
    this._repositoryFuture,
    this._journal, {
    required this._releaseExternalAccess,
  });

  final FileService _files;
  final Future<MediaRepository> _repositoryFuture;
  final OperationJournalService _journal;
  final Future<void> Function(Uri uri) _releaseExternalAccess;

  Future<Result<void, AppError>> invoke(MediaItem root) async {
    try {
      return await _invoke(root);
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to permanently delete item from Trash',
          original: e,
          stackTrace: st,
          context: 'PermanentlyDeleteTrashedMediaUseCase.invoke',
        ),
      );
    }
  }

  Future<Result<void, AppError>> _invoke(MediaItem root) async {
    if (!root.isTrashed || !root.isTrashRoot) {
      return Result.failure(AppError.validation('Item is not a trash root'));
    }
    final repository = await _repositoryFuture;
    final trashedItems = await repository.getTrashedItems(root.path);
    if (trashedItems.isFailure) {
      return Result.failure(trashedItems.errorOrNull!);
    }
    final trashedCollections = await repository.getTrashedCollections(
      root.path,
    );
    if (trashedCollections.isFailure) {
      return Result.failure(trashedCollections.errorOrNull!);
    }
    final items = {root, ...?trashedItems.dataOrNull};
    final collections = {...?trashedCollections.dataOrNull};
    final externalPaths = items
        .where((item) => item.sourceType == MediaSourceType.externalReference)
        .map((item) => item.path)
        .where((path) => path.isNotEmpty)
        .toSet();
    final thumbnails = items
        .map((item) => item.thumbnailPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();

    final journalEntry = await _findDeleteEntry(root.id, root.trashPath);
    if (journalEntry != null) {
      await _journal.write(
        journalEntry.copyWith(
          payload: {
            ...journalEntry.payload,
            'cleanupPaths': thumbnails.toList(growable: false),
          },
        ),
      );
    } else {
      AppLogger.w(
        LogTag.storage,
        'ごみ箱ジャーナルが見つかりませんが、DB・ファイル削除を継続します (itemId: ${root.id}, trashPath: ${root.trashPath})',
      );
    }

    final deleteGraph = await repository.deleteGraph(
      items.map((item) => item.id).toList(growable: false),
      collections.map((collection) => collection.id).toList(growable: false),
    );
    if (deleteGraph.isFailure) return deleteGraph;

    for (final path in externalPaths) {
      final remaining = await repository.getByPath(path);
      if (remaining.isFailure) {
        return Result.failure(remaining.errorOrNull!);
      }
      if (remaining.dataOrNull == null) {
        await _releaseExternalAccess(Uri.parse(path));
      }
    }

    final trashPath = root.trashPath;
    if (trashPath != null && trashPath.isNotEmpty) {
      final purge = await _files.deleteFile(trashPath);
      if (purge.isFailure) return purge;
    }
    for (final thumbnail in thumbnails) {
      final deleteThumbnail = await _files.deleteFile(thumbnail);
      if (deleteThumbnail.isFailure) return deleteThumbnail;
    }
    if (journalEntry != null) {
      await _journal.remove(journalEntry.id);
    }
    return Result.success(null);
  }

  Future<OperationJournalEntry?> _findDeleteEntry(
    int itemId,
    String? trashPath,
  ) async {
    final pathOperationId = _operationIdFromTrashPath(trashPath);
    for (final entry in await _journal.readAll()) {
      if (entry.kind != OperationKind.delete) continue;
      if ((pathOperationId != null && entry.id == pathOperationId) ||
          entry.payload['rootItemId'] == itemId) {
        return entry;
      }
    }
    return null;
  }

  String? _operationIdFromTrashPath(String? trashPath) {
    if (trashPath == null) return null;
    final segments = p.split(trashPath);
    return segments.length >= 2 && segments.first == '.trash'
        ? segments[1]
        : null;
  }
}
