import 'package:private_shelf/core/services/storage_operation_gate.dart';
// Application service: orchestrates imports without depending on presentation.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/core/services/local_notification_service_io.dart';

String _importFailureReason({
  required String fallback,
  Object? error,
  bool isCancelled = false,
}) {
  if (isCancelled) return ImportFailureReasonCode.cancelled;

  String? classifyMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    final lowered = message.toLowerCase();
    if (lowered.contains('no space left') ||
        lowered.contains('enospc') ||
        lowered.contains('storage full') ||
        lowered.contains('disk full') ||
        lowered.contains('空き容量')) {
      return ImportFailureReasonCode.noSpace;
    }
    if (lowered.contains('permission denied') ||
        lowered.contains('eacces') ||
        lowered.contains('eperm') ||
        lowered.contains('not permitted') ||
        lowered.contains('権限')) {
      return ImportFailureReasonCode.permission;
    }
    if (lowered.contains('already exists') ||
        lowered.contains('file exists') ||
        lowered.contains('eexist') ||
        lowered.contains('重複') ||
        lowered.contains('duplicate')) {
      return ImportFailureReasonCode.duplicate;
    }
    if (lowered.contains('unsupported') ||
        lowered.contains('not supported') ||
        lowered.contains('非対応')) {
      return ImportFailureReasonCode.unsupported;
    }
    if (lowered.contains('corrupt') ||
        lowered.contains('invalid') ||
        lowered.contains('malformed') ||
        lowered.contains('decode') ||
        lowered.contains('破損') ||
        lowered.contains('内容不正')) {
      return ImportFailureReasonCode.corrupt;
    }
    return null;
  }

  if (error is AppError) {
    final originalMessage = switch (error.originalError) {
      FileSystemException(:final message) => message,
      _ => null,
    };
    final matchedOriginal = classifyMessage(originalMessage);
    if (matchedOriginal != null) return matchedOriginal;

    final matchedMessage = classifyMessage(error.message);
    if (matchedMessage != null) return matchedMessage;

    return switch (error.category) {
      ErrorCategory.permission => ImportFailureReasonCode.permission,
      ErrorCategory.validation =>
        classifyMessage(error.message) ?? ImportFailureReasonCode.invalid,
      ErrorCategory.file =>
        classifyMessage(error.message) ?? ImportFailureReasonCode.file,
      ErrorCategory.database => ImportFailureReasonCode.database,
      ErrorCategory.network => ImportFailureReasonCode.network,
      ErrorCategory.auth => ImportFailureReasonCode.authentication,
      ErrorCategory.system => ImportFailureReasonCode.system,
      ErrorCategory.ui => ImportFailureReasonCode.ui,
      ErrorCategory.unknown => fallback,
    };
  }
  if (error is FileSystemException) {
    return classifyMessage(error.message) ?? fallback;
  }
  return fallback;
}

String _systemImportText({required String ja, required String en}) {
  return PlatformDispatcher.instance.locale.languageCode == 'en' ? en : ja;
}

class InternalImportService {
  static final RegExp _naturalTokenPattern = RegExp(r'\d+|\D+');
  static final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');

  final ImportMediaUseCase _importUseCase;
  final CreateFolderUseCase _createFolderUseCase;
  final ExternalStorageService _storageService;
  final FileService _fileService;
  final OperationJournalService _operationJournal;
  final MediaRepository _repository;
  final LocalNotificationService _notificationService;
  final bool Function() _isCancelled;
  final void Function(String path) _invalidateCollection;
  final void Function() _invalidateLibrary;
  final Uuid _uuid;
  final int _maxImportFileCount;
  final int _maxScannedEntryCount;
  final int _maxImportTotalBytes;
  final Future<int> Function(File file) _fileSize;

  InternalImportService(
    this._importUseCase,
    this._createFolderUseCase,
    this._storageService,
    this._fileService,
    this._operationJournal,
    this._repository,
    this._notificationService, {
    required this._isCancelled,
    required this._invalidateCollection,
    required this._invalidateLibrary,
    this._uuid = const Uuid(),
    this._maxImportFileCount = ImportSafetyPolicy.maxFileCount,
    this._maxScannedEntryCount = ImportSafetyPolicy.maxScannedEntryCount,
    this._maxImportTotalBytes = ImportSafetyPolicy.maxTotalBytes,
    Future<int> Function(File file)? fileSize,
  }) : _fileSize = fileSize ?? _readFileSize;

  static Future<int> _readFileSize(File file) => file.length();

  static const _importNotificationId = 1001;

  bool _isMediaFile(String path) {
    if (MediaFormatUtils.isIgnoredFile(path)) return false;
    final ext = p.extension(path).toLowerCase();
    return _storageService.isSupportedExtension(ext);
  }

  Future<Result<ImportExecutionReport, AppError>> importFolder(
    Uri sourceDirUri, {
    int? maxBytes,
    String? targetParentPath,
    bool isCatalog = false,
    bool registerChildFolders = false,
    ImportCatalogMode catalogMode = ImportCatalogMode.folder,
    Map<String, bool>? catalogOverridesByRelativePath,
    Set<String>? selectedRelativePaths,
    List<ImportCommittedItem> resumeDestinations = const [],
    List<ExternalFileInfo>? sourceEntries,
    String? sourceName,
    void Function(SyncProgress progress)? onProgress,
    int failureThresholdCount =
        ImportExecutionReport.defaultFailureThresholdCount,
  }) => StorageOperationGate.runResult(() async {
    final createdItemIds = <int>[];
    final createdCollectionIds = <int>[];
    var unsafeChildFailure = false;
    var rollbackAttempted = false;
    var rollbackFailed = false;
    Future<void> rollback() async {
      if (unsafeChildFailure) {
        rollbackFailed = true;
        throw StateError('Child import storage state requires recovery');
      }
      if (rollbackAttempted) return;
      rollbackAttempted = true;
      try {
        await _rollback(createdItemIds, createdCollectionIds);
      } catch (_) {
        rollbackFailed = true;
        rethrow;
      }
    }

    final committed = <ImportCommittedItem>[];
    final destinations = <ImportCommittedItem>[];
    try {
      final byteLimit = maxBytes ?? _maxImportTotalBytes;
      if (byteLimit < 0 || byteLimit > _maxImportTotalBytes) {
        throw const FileSystemException('取り込み可能な容量制限が不正です');
      }
      for (final path in selectedRelativePaths ?? const <String>{}) {
        _validateImportRelativePath(path);
      }
      final resumed = <String, MediaItem>{};
      for (final destination in resumeDestinations) {
        final resolved = await _repository.getById(destination.id);
        if (resolved.isFailure) throw resolved.errorOrNull!;
        final item = resolved.dataOrNull;
        if (item == null ||
            item.path != destination.path ||
            (destination.uid != null && item.uid != destination.uid) ||
            item.type != MediaType.folder ||
            item.isTrashed ||
            item.isHidden ||
            item.isArchived ||
            item.isMissing ||
            item.sourceType != MediaSourceType.localCopy) {
          throw const FileSystemException('取り込み先が変更されています。ライブラリを確認してください');
        }
        MediaItem? ancestor = item;
        final visited = <String>{};
        while (ancestor != null) {
          if (!visited.add(ancestor.path) ||
              ancestor.isHidden ||
              ancestor.isArchived ||
              ancestor.isTrashed) {
            throw const FileSystemException('取り込み先は現在利用できません');
          }
          final catalogResult = await _repository.getCollectionByPath(
            ancestor.path,
          );
          if (catalogResult.isFailure) throw catalogResult.errorOrNull!;
          final catalog = catalogResult.dataOrNull;
          if (catalog != null &&
              (catalog.isHidden || catalog.isArchived || catalog.isTrashed)) {
            throw const FileSystemException('取り込み先は現在利用できません');
          }
          final parent = ancestor.parentPath;
          if (parent == null || parent.isEmpty || parent == 'library') break;
          final parentResult = await _repository.getByPath(
            parent,
            includeTrashed: true,
          );
          if (parentResult.isFailure) throw parentResult.errorOrNull!;
          ancestor = parentResult.dataOrNull;
          if (ancestor == null) {
            throw const FileSystemException('取り込み先の親が見つかりません');
          }
        }
        resumed[destination.sourcePath] = item;
      }
      AppLogger.d(LogTag.storage, '内部フォルダインポート開始 (ストリーム方式): $sourceDirUri');
      onProgress?.call(const SyncProgress(status: SyncStatus.scanning));

      final repo = _repository;

      await _preflightFolderImport(
        sourceDirUri,
        selectedRelativePaths,
        sourceEntries,
        maxBytes: byteLimit,
      );
      if (_isCancelled()) {
        onProgress?.call(const SyncProgress(status: SyncStatus.completed));
        return Result.success(
          ImportExecutionReport(
            totalItems: 0,
            processedItems: 0,
            failedItems: 0,
            failureThresholdCount: failureThresholdCount,
            isCancelled: true,
            isRolledBack: true,
          ),
        );
      }

      // インポート先のルートフォルダ名を推測
      var rootFolderName = 'インポートフォルダ';
      final decodedPath = _safeDecodeUriComponent(sourceDirUri.toString());
      final parts = decodedPath.split('/');
      if (parts.isNotEmpty) {
        rootFolderName = parts.lastWhere(
          (p) => p.isNotEmpty,
          orElse: () => 'インポートフォルダ',
        );
        if (rootFolderName.contains(':')) {
          rootFolderName = rootFolderName
              .split(':')
              .last
              .split('/')
              .lastWhere((p) => p.isNotEmpty, orElse: () => 'インポートフォルダ');
        }
      }

      if (sourceName != null) rootFolderName = sourceName;

      // ルートフォルダの作成
      final rootPrevious = resumed[''];
      if (rootPrevious != null &&
          (rootPrevious.parentPath ?? 'library') !=
              (targetParentPath == null || targetParentPath.isEmpty
                  ? 'library'
                  : targetParentPath.startsWith('library/') ||
                        targetParentPath == 'library'
                  ? targetParentPath
                  : 'library/$targetParentPath')) {
        throw const FileSystemException('取り込み先の親フォルダが変更されています');
      }
      final createRootResult = rootPrevious == null
          ? await _createFolderUseCase.invoke(
              rootFolderName,
              parentPath: targetParentPath,
            )
          : Result<MediaItem, AppError>.success(rootPrevious);

      String? rootPath;
      if (createRootResult is Success<MediaItem, AppError>) {
        rootPath = createRootResult.data.path;
      } else if (createRootResult is Failure<MediaItem, AppError>) {
        throw createRootResult.error;
      }

      if (createRootResult is Success<MediaItem, AppError>) {
        final rootItem = createRootResult.data;
        if (rootPrevious == null && !createdItemIds.contains(rootItem.id)) {
          createdItemIds.add(rootItem.id);
        }
        if (rootItem.originalPath.isEmpty) {
          rootItem.originalPath = sourceDirUri.toString();
          final saved = await _repository.save(rootItem);
          if (saved.isFailure) throw saved.errorOrNull!;
        }
      }

      // パスキャッシュ (相対パス -> 他のアイテムの parentPath として使える documents 相対パス)
      // rootPath は CreateFolderUseCase によって作成された documents/library/... 形式のパス
      final folderPathCache = <String, String>{'': rootPath!};

      // ロールバック用に作成されたアイテムを記録
      // 各フォルダに追加された最初のファイルを記録するマップ（表紙画像用）
      final importedFilesPerFolder = <String, MediaItem>{};

      // ルートフォルダの MediaItem (createRootResult.data) も記録
      if (createRootResult is Success<MediaItem, AppError>) {
        if (rootPrevious == null &&
            !createdItemIds.contains(createRootResult.data.id)) {
          createdItemIds.add(createRootResult.data.id);
        }
        destinations.add(
          _committedReference(createRootResult.data, '', isCatalog: isCatalog),
        );
      }

      var discoveredCount = 0;
      var processedCount = 0;
      var failedCount = 0;
      var scanCount = 0;
      var rescannedBytes = 0;
      final failedEntries = <ImportFailureDetail>[];

      // 1. まず全ファイルを並行してスキャン（StreamをListに変換）
      // スキャンと同時に、必要に応じて中間フォルダだけは先に作成しておく
      final discoveredFiles = <ExternalFileInfo>[];

      AppLogger.d(LogTag.storage, 'スキャンとフォルダ作成を開始...');

      final notificationService = _notificationService;
      await notificationService.showProgress(
        id: _importNotificationId,
        title: _systemImportText(ja: 'インポート準備中...', en: 'Preparing import...'),
        body: _systemImportText(ja: 'ファイルをスキャンしています', en: 'Scanning files'),
        maxProgress: 100,
        currentProgress: 0,
        indeterminate: true,
      );

      await for (final fileInfo
          in (sourceEntries == null
              ? _storageService.listFiles(
                  sourceDirUri,
                  isCancelled: _isCancelled,
                )
              : Stream<ExternalFileInfo>.fromIterable(sourceEntries))) {
        // キャンセルチェック
        if (_isCancelled()) {
          await rollback();
          onProgress?.call(const SyncProgress(status: SyncStatus.completed));
          return Result.success(
            ImportExecutionReport(
              totalItems: discoveredCount,
              processedItems: 0,
              failedItems: failedCount,
              failureThresholdCount: failureThresholdCount,
              isCancelled: true,
              isRolledBack: true,
              failedEntries: failedEntries,
            ),
          );
        }

        scanCount++;
        if (scanCount > _maxScannedEntryCount) {
          throw const FileSystemException('インポート元の項目数が安全上限を超えています');
        }
        final fileName = fileInfo.name ?? 'unknown';
        final relativePath = fileInfo.relativePath ?? fileName;
        _validateImportRelativePath(relativePath);

        // 進捗通知（スキャン中: フォルダ等でもUIが進むようにする）
        if (scanCount % 10 == 0) {
          onProgress?.call(
            SyncProgress(
              status: SyncStatus.scanning,
              totalItems: discoveredCount,
              currentFileName: fileName,
            ),
          );
        }

        if (!fileInfo.isMedia) continue;
        if (selectedRelativePaths != null &&
            !selectedRelativePaths.contains(relativePath)) {
          continue;
        }
        if (discoveredCount >= _maxImportFileCount) {
          throw const FileSystemException('インポート可能なファイル数が安全上限を超えています');
        }
        final fileSize = fileInfo.size;
        final mayMeasureAfterSelection =
            sourceEntries == null && sourceDirUri.scheme == 'content';
        if ((fileSize == null && !mayMeasureAfterSelection) ||
            (fileSize != null && fileSize < 0)) {
          throw const FileSystemException('インポート元ファイルの容量を確認できません');
        }
        rescannedBytes += fileSize ?? 0;
        if (rescannedBytes > byteLimit) {
          throw const FileSystemException('インポートデータの合計容量が安全上限を超えています');
        }
        discoveredFiles.add(fileInfo);
        discoveredCount++;

        // このタイミングでフォルダだけ作っておく（重複作成を避けるため逐次）
        final relativeDir = p.dirname(relativePath);

        if (relativeDir != '.') {
          final normalizedDir = relativeDir.replaceAll('\\', '/');
          final dirParts = normalizedDir.split('/');
          var currentPathStr = '';
          var tempParent = rootPath;

          for (final part in dirParts) {
            if (part.isEmpty) continue;
            currentPathStr = currentPathStr.isEmpty
                ? part
                : '$currentPathStr/$part';
            if (!folderPathCache.containsKey(currentPathStr)) {
              final previous = resumed[currentPathStr];
              if (previous != null && previous.parentPath != tempParent) {
                throw const FileSystemException('取り込み先の階層が変更されています');
              }
              final createSubResult = previous == null
                  ? await _createFolderUseCase.invoke(
                      part,
                      parentPath: tempParent,
                    )
                  : Result<MediaItem, AppError>.success(previous);
              if (createSubResult is Success<MediaItem, AppError>) {
                final subFolderItem = createSubResult.data;
                folderPathCache[currentPathStr] = subFolderItem.path;
                destinations.add(
                  _committedReference(subFolderItem, currentPathStr),
                );
                if (previous == null &&
                    !createdItemIds.contains(subFolderItem.id)) {
                  createdItemIds.add(subFolderItem.id);
                }
                if (subFolderItem.originalPath.isEmpty &&
                    sourceDirUri.scheme == 'file') {
                  subFolderItem.originalPath = Uri.file(
                    p.join(sourceDirUri.toFilePath(), currentPathStr),
                  ).toString();
                  final saved = await _repository.save(subFolderItem);
                  if (saved.isFailure) throw saved.errorOrNull!;
                }
              } else {
                throw createSubResult.errorOrNull!;
              }
            }
            tempParent = folderPathCache[currentPathStr] ?? tempParent;
          }
        }
      }

      if (_isCancelled()) {
        await rollback();
        onProgress?.call(const SyncProgress(status: SyncStatus.completed));
        return Result.success(
          ImportExecutionReport(
            totalItems: discoveredCount,
            processedItems: 0,
            failedItems: failedCount,
            failureThresholdCount: failureThresholdCount,
            isCancelled: true,
            isRolledBack: true,
            failedEntries: failedEntries,
          ),
        );
      }

      discoveredFiles.sort(_compareImportOrder);

      AppLogger.d(LogTag.storage, 'スキャン完了: $discoveredCount 件のファイルを処理します');

      // 2. インポート処理を並列実行
      // 同時実行数を制御するためのバッチ処理
      final measureCopySizes = discoveredFiles.any((file) => file.size == null);
      // Unknown sizes share a measured budget, so those copies run sequentially.
      final concurrentLimit = measureCopySizes ? 1 : 3;
      var measuredSourceBytes = 0;
      final importStartAt = DateTime.now();
      final indexedFiles = discoveredFiles.asMap().entries.toList();
      final chunks = <List<MapEntry<int, ExternalFileInfo>>>[];
      for (var i = 0; i < indexedFiles.length; i += concurrentLimit) {
        chunks.add(
          indexedFiles.sublist(
            i,
            i + concurrentLimit > indexedFiles.length
                ? indexedFiles.length
                : i + concurrentLimit,
          ),
        );
      }

      for (final chunk in chunks) {
        // キャンセルチェック
        if (_isCancelled()) {
          await rollback();
          onProgress?.call(const SyncProgress(status: SyncStatus.completed));
          return Result.success(
            ImportExecutionReport(
              totalItems: discoveredCount,
              processedItems: 0,
              failedItems: failedCount,
              failureThresholdCount: failureThresholdCount,
              isCancelled: true,
              isRolledBack: true,
              failedEntries: failedEntries,
            ),
          );
        }

        await Future.wait(
          chunk.map((indexedFile) async {
            final fileInfo = indexedFile.value;
            final fileName = fileInfo.name ?? 'unknown';
            String? ownedStaging;
            try {
              if (_isCancelled()) return;

              final fileIndex = indexedFile.key;
              final relativePath = fileInfo.relativePath ?? fileName;
              final relativeDir = p.dirname(relativePath);
              final targetParent =
                  folderPathCache[relativeDir == '.' ? '' : relativeDir] ??
                  rootPath;
              final importedAt = importStartAt.subtract(
                Duration(milliseconds: fileIndex),
              );

              onProgress?.call(
                SyncProgress(
                  status: SyncStatus.processing,
                  totalItems: discoveredCount,
                  processedItems: processedCount,
                  currentFileName: fileName,
                ),
              );

              await notificationService.showProgress(
                id: _importNotificationId,
                title: _systemImportText(ja: 'インポート中...', en: 'Importing...'),
                body:
                    '$fileName (${processedCount + failedCount}/$discoveredCount)',
                maxProgress: discoveredCount,
                currentProgress: processedCount + failedCount,
              );

              final docUri = Uri.parse(fileInfo.uri);
              final expectedBytes = fileInfo.size;
              final copying = measureCopySizes
                  ? _storageService.copyToTemp(
                      docUri,
                      fileName,
                      expectedBytes: expectedBytes,
                      maxBytes: byteLimit - measuredSourceBytes,
                    )
                  : maxBytes != null
                  ? _storageService.copyToTemp(
                      docUri,
                      fileName,
                      expectedBytes: expectedBytes,
                      maxBytes: byteLimit,
                    )
                  : _storageService.copyToTemp(
                      docUri,
                      fileName,
                      expectedBytes: expectedBytes,
                    );
              var discardLateCopy = false;
              final trackedCopy = copying.then<String?>((latePath) async {
                if (!discardLateCopy ||
                    latePath == null ||
                    docUri.scheme != 'content') {
                  return latePath;
                }
                try {
                  final file = File(latePath);
                  if (await file.exists()) {
                    await file.delete(); // audit: allow-file-io
                  }
                } catch (error) {
                  AppLogger.w(
                    LogTag.storage,
                    'Could not remove a timed-out import staging file',
                    error,
                  );
                }
                return null;
              });
              final tempPath = sourceEntries != null
                  ? await trackedCopy
                  : await trackedCopy.timeout(
                      const Duration(seconds: 60),
                      onTimeout: () {
                        discardLateCopy = true;
                        throw TimeoutException('Import staging copy timed out');
                      },
                    );
              if (docUri.scheme == 'content') {
                ownedStaging = tempPath;
              }

              if (tempPath != null) {
                if (_isCancelled()) {
                  // キャンセルされた場合はインポートUseCaseを呼ばずに一時ファイルをクリーンアップ
                  try {
                    final tempFile = File(tempPath);
                    if (docUri.scheme == 'content' && await tempFile.exists()) {
                      await tempFile.delete(); // audit: allow-file-io
                    }
                  } catch (_) {}
                  return;
                }

                final tempFile = File(tempPath);
                final actualBytes = expectedBytes ?? await tempFile.length();
                if (measureCopySizes) {
                  measuredSourceBytes += actualBytes;
                  if (measuredSourceBytes > byteLimit) {
                    throw const FileSystemException(
                      'インポートデータの合計容量が安全上限を超えています',
                    );
                  }
                }
                final importResult = await _importUseCase.invoke(
                  tempFile,
                  parentPath: targetParent,
                  sourceFileName: fileName,
                  importedAt: importedAt,
                  expectedFileBytes: actualBytes,
                  isCatalog: catalogMode == ImportCatalogMode.file,
                );
                if (importResult is Success<MediaItem, AppError>) {
                  processedCount++;
                  createdItemIds.add(importResult.data.id);
                  committed.add(
                    _committedReference(
                      importResult.data,
                      relativePath,
                      isCatalog: catalogMode == ImportCatalogMode.file,
                      sizeBytes: actualBytes,
                    ),
                  );

                  // フォルダのカタログ化のために最初の画像(または動画)を記録する
                  if (targetParent != null) {
                    importedFilesPerFolder.putIfAbsent(
                      targetParent,
                      () => importResult.data,
                    );
                  }
                } else if (importResult is Failure<MediaItem, AppError>) {
                  unsafeChildFailure =
                      unsafeChildFailure ||
                      importResult
                              .error
                              .additionalData?['importRetryBlocked'] ==
                          true;
                  failedCount++;
                  failedEntries.add(
                    ImportFailureDetail(
                      path: relativePath,
                      displayName: fileName,
                      reason: _importFailureReason(
                        fallback: ImportFailureReasonCode.file,
                        error: importResult.error,
                      ),
                    ),
                  );
                  AppLogger.w(
                    LogTag.storage,
                    'インポート失敗 (スキップ): $fileName, ${importResult.error}',
                  );
                }
              } else {
                failedCount++;
                failedEntries.add(
                  ImportFailureDetail(
                    path: relativePath,
                    displayName: fileName,
                    reason: ImportFailureReasonCode.temporaryCopy,
                  ),
                );
              }
            } catch (e, st) {
              failedCount++;
              failedEntries.add(
                ImportFailureDetail(
                  path: fileInfo.relativePath ?? fileInfo.name ?? fileInfo.uri,
                  displayName: fileName,
                  reason: _importFailureReason(
                    fallback: ImportFailureReasonCode.processing,
                    error: e,
                  ),
                ),
              );
              AppLogger.e(
                LogTag.storage,
                'ファイル処理中に例外発生 (スキップ): ${fileInfo.name}',
                e,
                st,
              );
            } finally {
              if (ownedStaging != null) {
                try {
                  final temporary = File(ownedStaging);
                  if (await temporary.exists()) {
                    await temporary.delete(); // audit: allow-file-io
                  }
                } catch (error) {
                  AppLogger.w(
                    LogTag.storage,
                    'Could not remove owned import staging file',
                    error,
                  );
                }
              }
            }
          }),
        );

        if (unsafeChildFailure) {
          throw StateError('Child import storage state requires recovery');
        }

        // チャンク完了直後にもキャンセルを再チェック（チャンク実行中にキャンセルされた場合のドレイン後ロールバック）
        if (_isCancelled()) {
          await rollback();
          onProgress?.call(const SyncProgress(status: SyncStatus.completed));
          return Result.success(
            ImportExecutionReport(
              totalItems: discoveredCount,
              processedItems: 0,
              failedItems: failedCount,
              failureThresholdCount: failureThresholdCount,
              isCancelled: true,
              isRolledBack: true,
              failedEntries: failedEntries,
            ),
          );
        }
      }

      // 3. インポートされたフォルダ（ルートおよび各サブフォルダ）を「カタログ(MediaCollection)」として登録する
      for (final entry in folderPathCache.entries) {
        final relPath = entry.key.replaceAll('\\', '/');
        final folderPath = entry.value;
        final folderName = p.basename(folderPath);

        final isRoot = relPath.isEmpty;
        final registerAsCatalog =
            catalogOverridesByRelativePath?[relPath] ??
            (isRoot ? isCatalog : registerChildFolders);

        // モードは初期方針。詳細設定で明示的にカタログ化したフォルダは、
        // ファイル単位モードでも個別指定として尊重する。
        if (registerAsCatalog && !resumed.containsKey(relPath)) {
          // 表紙に使うのはこのカタログ直下のファイルのみ。
          // 子孫のファイルを採用すると、その直接の親だけでなく
          // さらに上のカタログまで同じ表紙に更新されてしまう。
          final directFirstItem = importedFilesPerFolder[folderPath];
          final coverPath = directFirstItem != null
              ? (directFirstItem.thumbnailPath ??
                    (directFirstItem.isImage ? directFirstItem.path : null))
              : null;

          final existingCatalog = await repo.getCollectionByPath(folderPath);
          if (existingCatalog.isFailure) throw existingCatalog.errorOrNull!;
          final collection = (existingCatalog.dataOrNull ?? MediaCollection())
            ..title = folderName
            ..path = folderPath
            ..type = CollectionType.folder
            ..isCatalog = registerAsCatalog
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now()
            ..coverImagePath = coverPath;

          final saved = await repo.saveCollection(collection);
          if (saved.isFailure) throw saved.errorOrNull!;
          createdCollectionIds.add(collection.id);

          // カタログ化されたパスのプロバイダーを無効化
          _invalidateCollection(folderPath);
        }
      }

      // Catalog persistence is asynchronous too; honor cancellation until all
      // file and metadata work has reached the commit boundary.
      if (_isCancelled()) {
        await rollback();
        return Result.success(
          ImportExecutionReport(
            totalItems: discoveredCount,
            processedItems: 0,
            failedItems: failedCount,
            failureThresholdCount: failureThresholdCount,
            isCancelled: true,
            isRolledBack: true,
            failedEntries: failedEntries,
          ),
        );
      }

      onProgress?.call(
        SyncProgress(
          status: SyncStatus.completed,
          totalItems: discoveredCount,
          processedItems: processedCount,
        ),
      );

      final foundPaths = discoveredFiles
          .map((info) => info.relativePath ?? info.name ?? 'unknown')
          .toSet();
      for (final missing
          in (selectedRelativePaths ?? const <String>{}).difference(
            foundPaths,
          )) {
        discoveredCount++;
        failedCount++;
        failedEntries.add(
          ImportFailureDetail(
            path: missing,
            displayName: p.basename(missing),
            reason: ImportFailureReasonCode.file,
          ),
        );
      }
      _invalidateLibrary();
      if (committed.isEmpty) await rollback();
      final report = ImportExecutionReport(
        committedItems: committed.isEmpty
            ? const []
            : [...destinations, ...committed],
        isRolledBack: committed.isEmpty,
        destinations: committed.isEmpty ? const [] : destinations,
        pendingSourcePaths: failedEntries.map((entry) => entry.path).toList(),
        totalItems: discoveredCount,
        processedItems: processedCount,
        failedItems: failedCount,
        failureThresholdCount: failureThresholdCount,
        failedEntries: failedEntries,
      );

      if (report.exceedsFailureThreshold) {
        final message =
            '内部フォルダインポートの失敗件数が閾値に達しました: ${report.failedItems}/${report.totalItems} (閾値: ${report.failureThresholdCount})';
        onProgress?.call(
          SyncProgress(status: SyncStatus.error, errorMessage: message),
        );
        await rollback();
        return Result.failure(
          AppError.file(
            message,
            context: 'InternalImportService.importFolder',
          ).withAdditionalData(
            report
                .copyWith(
                  committedItems: const [],
                  destinations: const [],
                  isRolledBack: true,
                  processedItems: 0,
                  pendingSourcePaths: const [],
                )
                .toMap(),
          ),
        );
      }

      await notificationService.showNow(
        id: _importNotificationId,
        title: _systemImportText(ja: 'インポート完了', en: 'Import complete'),
        body: _systemImportText(
          ja: '$processedCount 件のファイルをインポートしました',
          en: 'Imported $processedCount files',
        ),
      );

      return Result.success(report);
    } catch (e, st) {
      if (createdItemIds.isNotEmpty || createdCollectionIds.isNotEmpty) {
        try {
          await rollback();
        } catch (rollbackError, rollbackStack) {
          rollbackFailed = true;
          AppLogger.e(
            LogTag.storage,
            '内部フォルダインポートのロールバックに失敗',
            rollbackError,
            rollbackStack,
          );
        }
      }
      AppLogger.e(LogTag.storage, '内部フォルダインポートに失敗', e, st);
      onProgress?.call(
        SyncProgress(status: SyncStatus.error, errorMessage: e.toString()),
      );
      return Result.failure(
        AppError.file(
          '内部フォルダインポートに失敗: $e',
          original: e,
          stackTrace: st,
        ).withAdditionalData(
          ImportExecutionReport(
            committedItems: unsafeChildFailure
                ? [...destinations, ...committed]
                : const [],
            destinations: unsafeChildFailure ? destinations : const [],
            totalItems: selectedRelativePaths?.length ?? 0,
            processedItems: unsafeChildFailure ? committed.length : 0,
            failedItems: selectedRelativePaths?.length ?? 0,
            failureThresholdCount: failureThresholdCount,
            isRolledBack: !rollbackFailed,
            retryBlocked: rollbackFailed || resumeDestinations.isNotEmpty,
            pendingSourcePaths: selectedRelativePaths?.toList() ?? const [],
          ).toMap(),
        ),
      );
    }
  });

  Future<Result<ImportExecutionReport, AppError>> importContentFile(
    Uri uri,
    String name,
    String sourcePath, {
    int? expectedBytes,
    int? maxBytes,
    void Function(int bytes)? onMeasuredBytes,
    String? targetParentPath,
    bool isCatalog = false,
    void Function(SyncProgress)? onProgress,
  }) => _importSelectedFile(
    uri,
    name,
    sourcePath,
    expectedBytes: expectedBytes,
    maxBytes: maxBytes,
    onMeasuredBytes: onMeasuredBytes,
    targetParentPath: targetParentPath,
    isCatalog: isCatalog,
    onProgress: onProgress,
  );

  Future<Result<ImportExecutionReport, AppError>> importDeviceFile(
    Uri uri,
    String name,
    String sourcePath, {
    int? expectedBytes,
    int? maxBytes,
    void Function(int bytes)? onMeasuredBytes,
    String? targetParentPath,
    bool isCatalog = false,
    void Function(SyncProgress)? onProgress,
  }) => _importSelectedFile(
    uri,
    name,
    sourcePath,
    expectedBytes: expectedBytes,
    maxBytes: maxBytes,
    onMeasuredBytes: onMeasuredBytes,
    targetParentPath: targetParentPath,
    isCatalog: isCatalog,
    onProgress: onProgress,
    local: true,
  );

  Future<Result<ImportExecutionReport, AppError>> _importSelectedFile(
    Uri uri,
    String name,
    String sourcePath, {
    bool local = false,
    int? expectedBytes,
    int? maxBytes,
    void Function(int bytes)? onMeasuredBytes,
    String? targetParentPath,
    bool isCatalog = false,
    void Function(SyncProgress)? onProgress,
  }) => StorageOperationGate.runResult(() async {
    if (uri.scheme != (local ? 'file' : 'content')) {
      return Result.failure(AppError.validation('Unexpected document URI'));
    }
    String? staged;
    ImportExecutionReport report({
      List<ImportCommittedItem> committed = const [],
      bool cancelled = false,
      bool blocked = false,
      String? reason,
    }) => ImportExecutionReport(
      totalItems: 1,
      processedItems: committed.length,
      failedItems: reason == null ? 0 : 1,
      failureThresholdCount: ImportExecutionReport.defaultFailureThresholdCount,
      committedItems: committed,
      pendingSourcePaths: committed.isEmpty ? [sourcePath] : [],
      isCancelled: cancelled,
      retryBlocked: blocked,
      failedEntries: reason == null
          ? []
          : [
              ImportFailureDetail(
                path: sourcePath,
                displayName: name,
                reason: reason,
              ),
            ],
    );
    try {
      if (_isCancelled()) return Result.success(report(cancelled: true));
      onProgress?.call(
        SyncProgress(
          status: SyncStatus.processing,
          totalItems: 1,
          currentFileName: name,
        ),
      );
      staged = maxBytes == null
          ? await _storageService.copyToTemp(
              uri,
              name,
              expectedBytes: expectedBytes,
            )
          : await _storageService.copyToTemp(
              uri,
              name,
              expectedBytes: expectedBytes,
              maxBytes: maxBytes,
            );
      if (staged == null) {
        return Result.success(
          report(reason: ImportFailureReasonCode.temporaryCopy),
        );
      }
      final actualBytes = await File(staged).length();
      if (maxBytes != null && actualBytes > maxBytes) {
        return Result.success(report(reason: ImportFailureReasonCode.noSpace));
      }
      onMeasuredBytes?.call(actualBytes);
      if (_isCancelled()) return Result.success(report(cancelled: true));
      final result = await _importUseCase.invoke(
        File(staged),
        parentPath: targetParentPath,
        sourceFileName: name,
        isCatalog: isCatalog,
        expectedFileBytes: actualBytes,
      );
      if (result is Failure<MediaItem, AppError>) {
        final blocked =
            result.error.additionalData?['importRetryBlocked'] == true;
        final failed = report(
          blocked: blocked,
          reason: ImportFailureReasonCode.file,
        );
        return blocked
            ? Result.failure(result.error.withAdditionalData(failed.toMap()))
            : Result.success(failed);
      }
      final item = (result as Success<MediaItem, AppError>).data;
      if (_isCancelled()) {
        try {
          await _rollback([item.id], []);
        } catch (error) {
          return Result.failure(
            AppError.file(
              'Could not verify cancelled import',
            ).withAdditionalData(
              report(
                committed: [
                  _committedReference(
                    item,
                    sourcePath,
                    isCatalog: isCatalog,
                    sizeBytes: actualBytes,
                  ),
                ],
                blocked: true,
              ).toMap(),
            ),
          );
        }
        return Result.success(report(cancelled: true));
      }
      _invalidateCollection(targetParentPath ?? '');
      _invalidateLibrary();
      return Result.success(
        report(
          committed: [
            _committedReference(
              item,
              sourcePath,
              isCatalog: isCatalog,
              sizeBytes: actualBytes,
            ),
          ],
        ),
      );
    } catch (error, stack) {
      return Result.failure(
        AppError.file(
          'Could not import selected document',
          original: error,
          stackTrace: stack,
        ).withAdditionalData(
          report(
            blocked: true,
            reason: ImportFailureReasonCode.processing,
          ).toMap(),
        ),
      );
    } finally {
      // Every started operation must release the shared progress dialog,
      // including failures and cancellation before a destination is created.
      onProgress?.call(const SyncProgress(status: SyncStatus.completed));
      if (!local && staged != null) {
        try {
          final file = File(staged);
          if (await file.exists()) await file.delete();
        } // audit: allow-file-io
        catch (error) {
          AppLogger.w(
            LogTag.storage,
            'Could not remove owned import staging file',
            error,
          );
        }
      }
    }
  });

  Future<Result<ImportExecutionReport, AppError>> importFiles(
    List<File> files, {
    String? targetParentPath,
    bool isCatalog = false,
    void Function(SyncProgress progress)? onProgress,
    int failureThresholdCount =
        ImportExecutionReport.defaultFailureThresholdCount,
  }) => StorageOperationGate.runResult(() async {
    final createdItemIds = <int>[];
    var unsafeChildFailure = false;
    var rollbackAttempted = false;
    var rollbackFailed = false;
    Future<void> rollback() async {
      if (unsafeChildFailure) {
        rollbackFailed = true;
        throw StateError('Child import storage state requires recovery');
      }
      if (rollbackAttempted) return;
      rollbackAttempted = true;
      try {
        await _rollback(createdItemIds, []);
      } catch (_) {
        rollbackFailed = true;
        rethrow;
      }
    }

    final committed = <ImportCommittedItem>[];
    try {
      final mediaFiles = files.where((f) => _isMediaFile(f.path)).toList();
      if (mediaFiles.isEmpty) {
        onProgress?.call(
          const SyncProgress(
            status: SyncStatus.completed,
            totalItems: 0,
            processedItems: 0,
          ),
        );
        return Result.success(
          ImportExecutionReport(
            totalItems: 0,
            processedItems: 0,
            failedItems: 0,
            failureThresholdCount: failureThresholdCount,
          ),
        );
      }

      if (mediaFiles.length > _maxImportFileCount) {
        throw const FileSystemException('インポート可能なファイル数が安全上限を超えています');
      }
      var totalBytes = 0;
      final expectedSizes = <File, int>{};
      for (final file in mediaFiles) {
        final fileBytes = await _fileSize(file);
        if (fileBytes < 0) {
          throw const FileSystemException('インポート元ファイルの容量を確認できません');
        }
        expectedSizes[file] = fileBytes;
        totalBytes += fileBytes;
        if (totalBytes > _maxImportTotalBytes) {
          throw const FileSystemException('インポートデータの合計容量が安全上限を超えています');
        }
      }
      if (Platform.isAndroid || Platform.isIOS) {
        final destination = await getPrivateStorageDirectory();
        await ImportSafetyPolicy.ensureAvailableCapacity(
          destination.path,
          totalBytes,
        );
      }

      onProgress?.call(
        SyncProgress(
          status: SyncStatus.processing,
          totalItems: mediaFiles.length,
          processedItems: 0,
        ),
      );

      final importStartAt = DateTime.now();
      var processed = 0;
      var failed = 0;
      final failedEntries = <ImportFailureDetail>[];

      for (var index = 0; index < mediaFiles.length; index++) {
        // キャンセルチェック
        if (_isCancelled()) {
          await rollback();
          onProgress?.call(const SyncProgress(status: SyncStatus.completed));
          return Result.success(
            ImportExecutionReport(
              totalItems: mediaFiles.length,
              processedItems: 0,
              failedItems: failed,
              failureThresholdCount: failureThresholdCount,
              isCancelled: true,
              isRolledBack: true,
              failedEntries: failedEntries,
            ),
          );
        }

        final file = mediaFiles[index];
        final importedAt = importStartAt.subtract(
          Duration(milliseconds: index),
        );
        try {
          onProgress?.call(
            SyncProgress(
              status: SyncStatus.processing,
              totalItems: mediaFiles.length,
              processedItems: processed,
              currentFileName: p.basename(file.path),
            ),
          );

          final importResult = await _importUseCase.invoke(
            file,
            parentPath: targetParentPath,
            isCatalog: isCatalog,
            importedAt: importedAt,
            expectedFileBytes: expectedSizes[file],
          );
          if (importResult is Success<MediaItem, AppError>) {
            _invalidateCollection(targetParentPath ?? '');
            processed++;
            createdItemIds.add(importResult.data.id);
            committed.add(
              _committedReference(
                importResult.data,
                file.path,
                isCatalog: isCatalog,
              ),
            );
          } else if (importResult is Failure<MediaItem, AppError>) {
            unsafeChildFailure =
                unsafeChildFailure ||
                importResult.error.additionalData?['importRetryBlocked'] ==
                    true;
            failed++;
            failedEntries.add(
              ImportFailureDetail(
                path: file.path,
                displayName: p.basename(file.path),
                reason: _importFailureReason(
                  fallback: ImportFailureReasonCode.file,
                  error: importResult.error,
                ),
              ),
            );
            AppLogger.w(
              LogTag.storage,
              '個別ファイルインポート失敗 (継続): ${file.path}, ${importResult.error}',
            );
          }
        } catch (e, st) {
          failed++;
          failedEntries.add(
            ImportFailureDetail(
              path: file.path,
              displayName: p.basename(file.path),
              reason: _importFailureReason(
                fallback: ImportFailureReasonCode.processing,
                error: e,
              ),
            ),
          );
          AppLogger.e(
            LogTag.storage,
            '個別ファイルインポート失敗 (スキップ): ${file.path}',
            e,
            st,
          );
        }
        if (unsafeChildFailure) {
          throw StateError('Child import storage state requires recovery');
        }
      }

      // ループ終了後の最終キャンセルチェック
      if (_isCancelled()) {
        await rollback();
        onProgress?.call(const SyncProgress(status: SyncStatus.completed));
        return Result.success(
          ImportExecutionReport(
            totalItems: mediaFiles.length,
            processedItems: 0,
            failedItems: failed,
            failureThresholdCount: failureThresholdCount,
            isCancelled: true,
            isRolledBack: true,
            failedEntries: failedEntries,
          ),
        );
      }

      onProgress?.call(
        SyncProgress(
          status: SyncStatus.completed,
          totalItems: mediaFiles.length,
          processedItems: processed,
        ),
      );

      _invalidateLibrary();

      final report = ImportExecutionReport(
        committedItems: committed,
        pendingSourcePaths: failedEntries.map((entry) => entry.path).toList(),
        totalItems: mediaFiles.length,
        processedItems: processed,
        failedItems: failed,
        failureThresholdCount: failureThresholdCount,
        failedEntries: failedEntries,
      );

      if (report.exceedsFailureThreshold) {
        final message =
            '内部ファイルインポートの失敗件数が閾値に達しました: ${report.failedItems}/${report.totalItems} (閾値: ${report.failureThresholdCount})';
        onProgress?.call(
          SyncProgress(status: SyncStatus.error, errorMessage: message),
        );
        await rollback();
        return Result.failure(
          AppError.file(
            message,
            context: 'InternalImportService.importFiles',
          ).withAdditionalData(
            report
                .copyWith(
                  committedItems: const [],
                  destinations: const [],
                  isRolledBack: true,
                  processedItems: 0,
                  pendingSourcePaths: const [],
                )
                .toMap(),
          ),
        );
      }

      return Result.success(report);
    } catch (e, st) {
      try {
        await rollback();
      } catch (rollbackError, rollbackStack) {
        rollbackFailed = true;
        AppLogger.e(LogTag.storage, 'ロールバックに失敗', rollbackError, rollbackStack);
      }
      AppLogger.e(LogTag.storage, '内部ファイルインポートに失敗', e, st);
      onProgress?.call(
        SyncProgress(status: SyncStatus.error, errorMessage: e.toString()),
      );
      return Result.failure(
        AppError.file(
          '内部ファイルインポートに失敗: $e',
          original: e,
          stackTrace: st,
        ).withAdditionalData(
          ImportExecutionReport(
            committedItems: unsafeChildFailure ? committed : const [],
            totalItems: files.length,
            processedItems: unsafeChildFailure ? committed.length : 0,
            failedItems: files.length,
            failureThresholdCount: failureThresholdCount,
            isRolledBack: !rollbackFailed,
            retryBlocked: rollbackFailed,
            pendingSourcePaths: files.map((file) => file.path).toList(),
          ).toMap(),
        ),
      );
    }
  });

  ImportCommittedItem _committedReference(
    MediaItem item,
    String sourcePath, {
    bool isCatalog = false,
    int? sizeBytes,
  }) => ImportCommittedItem(
    id: item.id,
    uid: item.uid,
    path: item.path,
    sourcePath: sourcePath,
    isFolder: item.type == MediaType.folder,
    isCatalog: isCatalog,
    sizeBytes: item.type == MediaType.folder ? null : sizeBytes ?? item.size,
  );

  Future<void> _preflightFolderImport(
    Uri sourceDirUri,
    Set<String>? selectedPaths,
    List<ExternalFileInfo>? sourceEntries, {
    required int maxBytes,
  }) async {
    var scannedCount = 0;
    var fileCount = 0;
    var totalBytes = 0;
    await for (final fileInfo
        in (sourceEntries == null
            ? _storageService.listFiles(sourceDirUri, isCancelled: _isCancelled)
            : Stream<ExternalFileInfo>.fromIterable(sourceEntries))) {
      if (_isCancelled()) return;
      scannedCount++;
      if (scannedCount > _maxScannedEntryCount) {
        throw const FileSystemException('インポート元の項目数が安全上限を超えています');
      }
      final relativePath = fileInfo.relativePath;
      if (relativePath != null) _validateImportRelativePath(relativePath);
      if (!fileInfo.isMedia) continue;
      if (selectedPaths != null &&
          !selectedPaths.contains(relativePath ?? fileInfo.name)) {
        continue;
      }
      fileCount++;
      if (fileCount > _maxImportFileCount) {
        throw const FileSystemException('インポート可能なファイル数が安全上限を超えています');
      }
      final size = fileInfo.size;
      if (size == null &&
          sourceEntries == null &&
          sourceDirUri.scheme == 'content') {
        continue;
      }
      if (size == null || size < 0) {
        throw const FileSystemException('インポート元ファイルの容量を確認できません');
      }
      totalBytes += size;
      if (totalBytes > maxBytes) {
        throw const FileSystemException('インポートデータの合計容量が安全上限を超えています');
      }
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final destination = await getPrivateStorageDirectory();
      await ImportSafetyPolicy.ensureAvailableCapacity(
        destination.path,
        totalBytes,
      );
    }
  }

  static void _validateImportRelativePath(String relativePath) {
    final normalized = p.normalize(relativePath);
    final segments = p.split(normalized);
    if (relativePath.isEmpty ||
        relativePath.contains('\u0000') ||
        relativePath.contains('\\') ||
        p.isAbsolute(relativePath) ||
        Uri.tryParse(relativePath)?.hasScheme == true ||
        segments.isEmpty ||
        segments.any((segment) => segment == '.' || segment == '..')) {
      throw const FileSystemException('インポート元の相対パスが不正です');
    }
    if (segments.length > ImportSafetyPolicy.maxRelativePathDepth) {
      throw const FileSystemException('インポート元のフォルダ階層が深すぎます');
    }
  }

  int _compareImportOrder(ExternalFileInfo a, ExternalFileInfo b) {
    final left = _importSortKey(a);
    final right = _importSortKey(b);
    final compared = _compareNatural(left, right);
    if (compared != 0) return compared;
    return a.uri.compareTo(b.uri);
  }

  String _importSortKey(ExternalFileInfo file) {
    return (file.relativePath ?? file.name ?? file.uri).toLowerCase();
  }

  int _compareNatural(String left, String right) {
    final leftTokens = _naturalTokenPattern
        .allMatches(left)
        .map((m) => m.group(0)!)
        .toList();
    final rightTokens = _naturalTokenPattern
        .allMatches(right)
        .map((m) => m.group(0)!)
        .toList();

    final minLength = leftTokens.length < rightTokens.length
        ? leftTokens.length
        : rightTokens.length;

    for (var i = 0; i < minLength; i++) {
      final leftToken = leftTokens[i];
      final rightToken = rightTokens[i];
      final bothDigits =
          _digitsOnlyPattern.hasMatch(leftToken) &&
          _digitsOnlyPattern.hasMatch(rightToken);

      if (bothDigits) {
        final leftNumber = BigInt.parse(leftToken);
        final rightNumber = BigInt.parse(rightToken);
        final numberCompare = leftNumber.compareTo(rightNumber);
        if (numberCompare != 0) return numberCompare;

        final lengthCompare = leftToken.length.compareTo(rightToken.length);
        if (lengthCompare != 0) return lengthCompare;
        continue;
      }

      final tokenCompare = leftToken.compareTo(rightToken);
      if (tokenCompare != 0) return tokenCompare;
    }

    return leftTokens.length.compareTo(rightTokens.length);
  }

  /// インポートされたアイテムを削除してロールバックする
  Future<void> _rollback(List<int> itemIds, List<int> collectionIds) async {
    AppLogger.w(
      LogTag.storage,
      'インポートをロールバック中... アイテム:${itemIds.length}件, フォルダ:${collectionIds.length}件',
    );
    final validItemIds = itemIds.where((id) => id > 0).toList(growable: false);
    final validCollectionIds = collectionIds.where((id) => id > 0).toList();
    if (validItemIds.isEmpty && validCollectionIds.isEmpty) {
      return;
    }

    final resources =
        <({String journalId, String path, String? thumbnailPath})>[];
    for (final id in validItemIds) {
      final itemResult = await _repository.getById(id);
      if (itemResult.isFailure) throw itemResult.errorOrNull!;
      final item = itemResult.dataOrNull;
      if (item == null) continue;
      if (item.path.isEmpty) continue;
      final catalog = await _repository.getCollectionByPath(item.path);
      if (catalog.isFailure) throw catalog.errorOrNull!;
      final catalogId = catalog.dataOrNull?.id;
      if (catalogId != null && !validCollectionIds.contains(catalogId)) {
        validCollectionIds.add(catalogId);
      }
      final resource = (
        journalId: _uuid.v4(),
        path: item.path,
        thumbnailPath: item.thumbnailPath,
      );
      await _operationJournal.write(
        OperationJournalEntry(
          id: resource.journalId,
          kind: OperationKind.import,
          stage: OperationStage.committed,
          payload: {
            'path': resource.path,
            'thumbnailPath': resource.thumbnailPath,
          },
        ),
      );
      resources.add(resource);
    }

    final graphResult = await _repository.deleteGraph(
      validItemIds,
      validCollectionIds,
    );
    if (graphResult.isFailure) {
      for (final resource in resources) {
        await _operationJournal.remove(resource.journalId);
      }
      throw graphResult.errorOrNull!;
    }

    // 親フォルダを先に消すと子パスが重複削除になるため、深いパスから処理する。
    resources.sort(
      (a, b) => p.split(b.path).length.compareTo(p.split(a.path).length),
    );
    for (final resource in resources) {
      final deleteResult = await _fileService.deleteFile(resource.path);
      if (deleteResult.isFailure) throw deleteResult.errorOrNull!;
      final thumbnailPath = resource.thumbnailPath;
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final thumbnailResult = await _fileService.deleteFile(thumbnailPath);
        if (thumbnailResult.isFailure) throw thumbnailResult.errorOrNull!;
      }
      await _operationJournal.remove(resource.journalId);
    }

    _invalidateLibrary();
    AppLogger.i(LogTag.storage, 'ロールバック完了');
  }

  String _safeDecodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
}
