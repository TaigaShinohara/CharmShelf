// Application layer: coordinates domain contracts with persistence services.
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/retry_helper.dart';
import 'package:private_shelf/core/error/retry_policy.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/import_copy_artifacts.dart';
import 'package:uuid/uuid.dart';

part 'import_media_use_case.g.dart';

@Riverpod(keepAlive: true)
ImportMediaUseCase importMediaUseCase(Ref ref) {
  return ImportMediaUseCase(
    ref.read(fileServiceProvider),
    ref.read(mediaRepositoryProvider.future),
    ref.read(operationJournalServiceProvider),
  );
}

class ImportMediaUseCase {
  final FileService _fileService;
  final Future<MediaRepository> _mediaRepositoryFuture;
  final OperationJournalService? _journal;
  final Uuid _uuid = const Uuid();

  // フォルダ取り込みでは複数ファイルを並列コピーするが、動画サムネイルの
  // デコードまで並列にすると再生中のデコーダとCPU/I/Oを奪い合う。コピーや
  // DB保存の並列性は保ち、サムネイル生成だけを1本ずつ実行する。
  Future<void> _thumbnailQueue = Future<void>.value();

  ImportMediaUseCase(
    this._fileService,
    this._mediaRepositoryFuture, [
    this._journal,
  ]);

  Future<T> _runThumbnailGeneration<T>(Future<T> Function() action) {
    final previous = _thumbnailQueue;
    final release = Completer<void>();
    _thumbnailQueue = release.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        release.complete();
      }
    });
  }

  /// 動画ファイル判定
  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const {
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm',
      '.m4v',
    }.contains(ext);
  }

  /// ファイルをインポートする
  /// [file]: インポート元のファイル
  /// [parentPath]: 保存先の親フォルダパス（任意）
  ///
  /// インポート後、以下を自動実行:
  /// - サムネイル生成（非クリティカル: 失敗してもインポート成功）
  /// - MediaCollection 自動作成（カタログ化）
  Future<Result<void, AppError>> _rollbackImportedItem(
    MediaRepository repository,
    MediaItem item,
  ) async {
    final collection = await repository.getCollectionByPath(item.path);
    if (collection.isFailure) return Result.failure(collection.errorOrNull!);
    return repository.deleteGraph(
      [item.id],
      [if (collection.dataOrNull != null) collection.dataOrNull!.id],
    );
  }

  Future<Result<MediaItem, AppError>> invoke(
    File file, {
    String? parentPath,
    bool isCatalog = false,
    String? sourceFileName,
    DateTime? importedAt,
    int? expectedFileBytes,
  }) async {
    final operationId = _uuid.v4();
    return FileService.runImportOperation(operationId, () async {
      OperationJournalEntry? journalEntry;
      ImportCopyArtifacts? copyArtifacts;
      var databaseCommitted = false;
      var recoveryUncertain = false;
      Result<MediaItem, AppError> failed(AppError error) => Result.failure(
        databaseCommitted || recoveryUncertain
            ? error.withAdditionalData({
                ...?error.additionalData,
                'importRetryBlocked': true,
              })
            : error,
      );
      Future<void> retireFailedOperation() async {
        // Even an empty planned record can conflict with a later successful
        // copy to the same path. It must be retired before retry is safe.
        recoveryUncertain = true;
        await _journal?.remove(operationId);
        recoveryUncertain = false;
      }

      try {
        Future<void> prepareJournal(String relativePath) async {
          copyArtifacts = ImportCopyArtifacts(
            operationId: operationId,
            destinationPath: relativePath,
          );
          journalEntry = OperationJournalEntry(
            id: operationId,
            kind: OperationKind.import,
            stage: OperationStage.planned,
            payload: {
              'path': relativePath,
              'thumbnailPath': null,
              'copyArtifacts': copyArtifacts!.toMap(),
            },
          );

          await _journal?.write(journalEntry!);
        }

        Future<void> stageJournal(String relativePath) async {
          recoveryUncertain = true;
          final staged = OperationJournalEntry(
            id: operationId,
            kind: OperationKind.import,
            stage: OperationStage.staged,
            payload: {
              'path': relativePath,
              'thumbnailPath': null,
              if (copyArtifacts != null)
                'copyArtifacts': copyArtifacts!.toMap(),
            },
          );
          await _journal?.write(staged);
          journalEntry = staged;
        }

        // 1. ファイルコピー
        final copyResult = expectedFileBytes == null
            ? sourceFileName == null
                  ? await _fileService.importFile(
                      file,
                      targetParentPath: parentPath,
                      onDestinationPrepared: _journal == null
                          ? null
                          : prepareJournal,
                      onDestinationPublished: _journal == null
                          ? null
                          : stageJournal,
                      importOperationId: _journal == null ? null : operationId,
                    )
                  : await _fileService.importFile(
                      file,
                      targetParentPath: parentPath,
                      sourceFileName: sourceFileName,
                      onDestinationPrepared: _journal == null
                          ? null
                          : prepareJournal,
                      onDestinationPublished: _journal == null
                          ? null
                          : stageJournal,
                      importOperationId: _journal == null ? null : operationId,
                    )
            : await _fileService.importFile(
                file,
                targetParentPath: parentPath,
                sourceFileName: sourceFileName,
                onDestinationPrepared: _journal == null ? null : prepareJournal,
                onDestinationPublished: _journal == null ? null : stageJournal,
                importOperationId: _journal == null ? null : operationId,
                maxBytes: expectedFileBytes,
                expectedBytes: expectedFileBytes,
              );
        if (copyResult is Failure<String, AppError>) {
          recoveryUncertain =
              copyResult.error.additionalData?['importRetryBlocked'] == true;
          if (!recoveryUncertain) await retireFailedOperation();
          return failed(copyResult.error);
        }
        if (copyResult is! Success<String, AppError>) {
          return failed(AppError.unknown('Unexpected result type'));
        }
        final relativePath = copyResult.data;
        recoveryUncertain = true;
        if (journalEntry?.stage != OperationStage.staged) {
          await stageJournal(relativePath);
        }

        // 2. サムネイル生成（非クリティカル: 失敗してもインポートは成功させる）
        String? thumbnailPath;
        try {
          final docsDir = await getPrivateStorageDirectory();
          final copiedFile = File(p.join(docsDir.path, relativePath));
          final thumbResult = await _runThumbnailGeneration(
            () => _fileService
                .generateThumbnail(
                  copiedFile,
                  timeMs: _isVideo(relativePath) ? 5000 : null,
                )
                .timeout(const Duration(seconds: 10)),
          );
          if (thumbResult is Success<String, AppError>) {
            thumbnailPath = thumbResult.data;
            journalEntry = OperationJournalEntry(
              id: operationId,
              kind: OperationKind.import,
              stage: OperationStage.staged,
              payload: {
                'path': relativePath,
                'thumbnailPath': thumbnailPath,
                if (copyArtifacts != null)
                  'copyArtifacts': copyArtifacts!.toMap(),
              },
            );
            await _journal?.write(journalEntry!);
          } else {
            AppLogger.d(
              LogTag.storage,
              'サムネイル生成スキップ（非対応フォーマット）: $relativePath',
            );
          }
        } catch (e) {
          // サムネイル生成失敗はインポート自体には影響しない
          AppLogger.e(LogTag.storage, 'サムネイル生成失敗（インポート続行）: $e');
        }

        // 3. MediaItem 生成
        final importedTime = importedAt ?? DateTime.now();
        final item = MediaItem()
          ..path = relativePath
          ..originalPath = file.absolute.path
          ..sourceType = MediaSourceType.localCopy
          ..addedAt = importedTime
          ..updatedAt = importedTime
          ..size = await file.length()
          ..type = MediaType.file
          ..thumbnailPath = thumbnailPath
          ..parentPath = parentPath;

        // 4. DB保存（リトライ付き）
        final repo = await _mediaRepositoryFuture;
        final saveResult = await withRetry(
          () => repo.save(item),
          policy: RetryPolicy.database,
          context: 'ImportMediaUseCase.invoke - DB save',
        );
        if (saveResult is Failure<void, AppError>) {
          final cleanup = await _cleanupImportedFiles(
            relativePath,
            thumbnailPath,
          );
          recoveryUncertain = cleanup.isFailure;
          if (cleanup.isSuccess) await retireFailedOperation();
          return failed(saveResult.error);
        }

        databaseCommitted = true;

        // 5. 自動カタログ化: MediaCollection を作成 (カタログ登録する場合のみ)
        if (isCatalog) {
          try {
            final now = DateTime.now();
            final effectiveTitle =
                (sourceFileName != null && sourceFileName.isNotEmpty)
                ? p.basenameWithoutExtension(sourceFileName)
                : p.basenameWithoutExtension(file.path);
            final previousCollection = await repo.getCollectionByPath(
              relativePath,
            );
            if (previousCollection.isFailure) {
              throw previousCollection.errorOrNull!;
            }
            final collection =
                (previousCollection.dataOrNull ?? MediaCollection())
                  ..title = effectiveTitle
                  ..path = relativePath
                  ..type = CollectionType.file
                  ..isCatalog = isCatalog
                  ..createdAt = now
                  ..updatedAt = now
                  ..coverImagePath =
                      thumbnailPath ?? (item.isImage ? relativePath : null);
            // Persist the owning side; assigning item.collection only changes
            // the in-memory backlink and makes normal metadata search miss it.
            collection.items.add(item);

            final collectionResult = await repo.saveCollection(collection);
            if (collectionResult.isFailure) {
              final rollback = await _rollbackImportedItem(repo, item);
              if (rollback.isFailure) {
                return failed(rollback.errorOrNull!);
              }
              databaseCommitted = false;
              final cleanup = await _cleanupImportedFiles(
                relativePath,
                thumbnailPath,
              );
              recoveryUncertain = cleanup.isFailure;
              if (cleanup.isSuccess) await retireFailedOperation();
              return failed(collectionResult.errorOrNull!);
            }
            AppLogger.d(
              LogTag.storage,
              '自動カタログ化完了: ${collection.title} (path: ${collection.path})',
            );
          } catch (e, st) {
            final rollback = await _rollbackImportedItem(repo, item);
            if (rollback.isFailure) return failed(rollback.errorOrNull!);
            databaseCommitted = false;
            final cleanup = await _cleanupImportedFiles(
              relativePath,
              thumbnailPath,
            );
            recoveryUncertain = cleanup.isFailure;
            if (cleanup.isSuccess) await retireFailedOperation();
            return failed(
              AppError.database(
                'Collection creation failed',
                original: e,
                stackTrace: st,
              ),
            );
          }
        }

        // The item (and requested catalog) are committed. Failure to retire the
        // recovery journal must not turn them into an apparently retryable import.
        try {
          await _journal?.remove(operationId);
        } catch (error, stack) {
          AppLogger.w(LogTag.storage, '保存済みインポートのジャーナル整理に失敗', error, stack);
        }
        return Result.success(item);
      } catch (e, st) {
        return failed(
          AppError.unknown(
            'Import failed: $e',
            original: e,
            stackTrace: st,
            context: 'ImportMediaUseCase.invoke',
          ),
        );
      }
    });
  }

  Future<Result<void, AppError>> _cleanupImportedFiles(
    String relativePath,
    String? thumbnailPath,
  ) async {
    try {
      final fileResult = await _fileService.deleteFile(relativePath);
      if (fileResult.isFailure) {
        AppLogger.e(
          LogTag.storage,
          'インポート補償処理でファイルを削除できませんでした: $relativePath',
          fileResult.errorOrNull,
        );
        return Result.failure(fileResult.errorOrNull!);
      }
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final thumbnailResult = await _fileService.deleteFile(thumbnailPath);
        if (thumbnailResult.isFailure) {
          AppLogger.e(
            LogTag.storage,
            'インポート補償処理でサムネイルを削除できませんでした: $thumbnailPath',
            thumbnailResult.errorOrNull,
          );
          return Result.failure(thumbnailResult.errorOrNull!);
        }
      }
      return Result.success(null);
    } catch (error, stackTrace) {
      AppLogger.e(LogTag.storage, 'インポート補償処理に失敗しました', error, stackTrace);
      return Result.failure(
        AppError.file(
          'Import cleanup failed',
          original: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
