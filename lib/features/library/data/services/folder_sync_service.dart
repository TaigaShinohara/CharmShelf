import 'package:private_shelf/core/services/storage_operation_gate.dart';
import '../../../../core/services/library_storage_lock.dart';
import 'reference_migration_service.dart';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';

part 'folder_sync_service.g.dart';

@Riverpod(keepAlive: true)
Future<FolderSyncService> folderSyncService(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  final storageManager = ref.watch(localStorageManagerProvider);
  final sidecarService = await ref.watch(sidecarMetadataServiceProvider.future);
  final permissionRepo = ref.watch(permissionRepositoryProvider);
  return FolderSyncService(
    isar,
    storageManager,
    sidecarService,
    permissionRepo,
    reservedPaths: () => ReferenceMigrationService.reservedPaths(isar),
  );
}

/// 専用フォルダ内のメディア実体と DB 間の双方向走査・同期を行うサービス。
class FolderSyncService {
  final Isar _isar;
  final LocalStorageManager _storageManager;
  final SidecarMetadataService _sidecarService;
  final PermissionRepository _permissionRepo;
  final int _maxImportFileCount;
  final int _maxScannedEntryCount;
  final int _maxImportTotalBytes;
  final _uuid = const Uuid();
  final Future<Set<String>> Function()? reservedPaths;

  FolderSyncService(
    this._isar,
    this._storageManager,
    this._sidecarService,
    this._permissionRepo, {
    this.reservedPaths,
    this._maxImportFileCount = ImportSafetyPolicy.maxFileCount,
    this._maxScannedEntryCount = ImportSafetyPolicy.maxScannedEntryCount,
    this._maxImportTotalBytes = ImportSafetyPolicy.maxTotalBytes,
  });

  Future<Result<({int added, int updated, int missing}), AppError>> syncAll({
    void Function(SyncProgress progress)? onProgress,
    bool importMetadata = true,
    bool exportMetadata = true,
    bool importPublicRecoverySource = false,
    Directory? recoverySource,
  }) => StorageOperationGate.runResult(
    () => LibraryStorageLock.run(
      _isar,
      () => _syncAll(
        onProgress: onProgress,
        importMetadata: importMetadata,
        exportMetadata: exportMetadata,
        importPublicRecoverySource: importPublicRecoverySource,
        recoverySource: recoverySource,
      ),
    ),
  );

  /// ルートフォルダ全体をスキャンして DB と同期する。
  Future<Result<({int added, int updated, int missing}), AppError>> _syncAll({
    void Function(SyncProgress progress)? onProgress,
    bool importMetadata = true,
    bool exportMetadata = true,
    bool importPublicRecoverySource = false,
    Directory? recoverySource,
  }) async {
    try {
      final isExternalPublic =
          importPublicRecoverySource &&
          await _storageManager.isExternalPublicDirectory();
      if (isExternalPublic) {
        final permStatus = await _permissionRepo
            .getManageStoragePermissionStatus();
        if (permStatus != PermissionResult.granted) {
          AppLogger.w(LogTag.storage, '外部ストレージ権限が許可されていないため同期を中断します');
          return Result.failure(
            AppError.permission(
              'ストレージのアクセス権限が必要です。設定からすべてのファイルへのアクセスを許可してください。',
            ),
          );
        }
      }

      final sourceRootDir = importPublicRecoverySource
          ? await _storageManager.getRootDirectory()
          : await _storageManager.getPrivateRootDirectory();
      AppLogger.i(LogTag.storage, '専用フォルダのスキャンと同期を開始: ${sourceRootDir.path}');

      onProgress?.call(const SyncProgress(status: SyncStatus.scanning));

      // 1. メタデータファイルが存在すればインポート
      if (importMetadata) {
        final importResult = await _sidecarService.importMetadata();
        if (importResult.isFailure) {
          return Result.failure(importResult.errorOrNull!);
        }
      }

      // Androidの公開フォルダは復元元としてのみ扱う。UIが参照する
      // localCopyは必ず私有領域へ原子的にコピーしてからDBに登録する。
      final rootDir = recoverySource != null
          ? await _copyPublicMediaToPrivate(recoverySource)
          : isExternalPublic
          ? await _copyPublicMediaToPrivate(sourceRootDir)
          : sourceRootDir;
      AppLogger.i(LogTag.storage, '同期対象の管理ルート: ${rootDir.path}');

      final reserved = await reservedPaths?.call() ?? <String>{};

      // 2. ディレクトリを再帰的に走査
      final foundFiles = <File>[];
      final foundDirs = <Directory>[];

      if (await rootDir.exists()) {
        await for (final entity in rootDir.list(
          recursive: true,
          followLinks: false,
        )) {
          final relPath = p.relative(entity.path, from: rootDir.path);
          if (reserved.any(
            (path) => relPath == path || relPath.startsWith('$path/'),
          )) {
            continue;
          }
          final parts = p.split(relPath);

          // 通常の管理対象は library/ と旧形式の folders/ 配下のみ。
          // ルート直下の診断ファイルや移行確認用フォルダを取り込むと、
          // サイドカーが許可するパス範囲と矛盾して次回同期が失敗する。
          if (parts.isEmpty ||
              (parts.first != 'library' && parts.first != 'folders')) {
            continue;
          }

          // 隠しフォルダ配下の除外
          if (parts.any(MediaFormatUtils.isIgnoredDirectory)) {
            continue;
          }

          if (entity is File) {
            final fileName = p.basename(entity.path);
            if (MediaFormatUtils.isIgnoredFile(fileName)) {
              continue;
            }
            final ext = p.extension(entity.path).toLowerCase();
            if (MediaFormatUtils.allSupportedExtensions.contains(ext)) {
              foundFiles.add(entity);
            }
          } else if (entity is Directory) {
            final dirName = p.basename(entity.path);
            if (!MediaFormatUtils.isIgnoredDirectory(dirName)) {
              foundDirs.add(entity);
            }
          }
        }
      }

      onProgress?.call(
        SyncProgress(
          status: SyncStatus.processing,
          totalItems: foundFiles.length,
        ),
      );

      var addedCount = 0;
      var updatedCount = 0;
      var missingCount = 0;

      // 3. 事前DBデータの一括フェッチ（マップ化によるN+1クエリ解消）
      final existingCollections = await _isar.mediaCollections
          .filter()
          .isTrashedEqualTo(false)
          .findAll();
      final collectionByPath = <String, MediaCollection>{
        for (final c in existingCollections) c.path: c,
      };

      final existingLocalItems = await _isar.mediaItems
          .filter()
          .sourceTypeEqualTo(MediaSourceType.localCopy)
          .findAll();

      // 過去に誤登録されたシステムファイルや旧クラッシュログのDBレコードをパージ
      final invalidItemIds = <Id>[];
      for (final item in existingLocalItems) {
        final fileName = p.basename(item.path);
        if (MediaFormatUtils.isIgnoredFile(fileName)) {
          invalidItemIds.add(item.id);
        }
      }
      if (invalidItemIds.isNotEmpty) {
        final invalidIdSet = invalidItemIds.toSet();
        await _isar.writeTxn(() async {
          await _isar.mediaItems.deleteAll(invalidItemIds);
        });
        existingLocalItems.removeWhere(
          (item) => invalidIdSet.contains(item.id),
        );
        AppLogger.i(
          LogTag.storage,
          '${invalidItemIds.length} 件のシステム/除外ファイルをDBから削除しました',
        );
      }

      final itemByPath = <String, MediaItem>{
        for (final item in existingLocalItems) item.path: item,
      };

      // 4. フォルダ（MediaCollection / 表示用 MediaItem）の同期準備
      final collectionsToPut = <MediaCollection>[];
      final itemsToPut = <MediaItem>[];
      final scannedPaths = <String>{};
      for (final dir in foundDirs) {
        final relPath = p.relative(dir.path, from: rootDir.path);
        // 管理用ルートフォルダやカレントパスは項目として登録しない
        if (relPath == 'library' ||
            relPath == 'folders' ||
            relPath == '.' ||
            relPath.isEmpty) {
          continue;
        }
        scannedPaths.add(relPath);
        final dirStat = await dir.stat();
        var col = collectionByPath[relPath];
        if (col == null) {
          col = MediaCollection()
            ..uid = _uuid.v4()
            ..title = p.basename(dir.path)
            ..path = relPath
            ..type = CollectionType.folder
            ..isCatalog = false
            ..createdAt = dirStat.changed
            ..updatedAt = dirStat.modified;
          collectionsToPut.add(col);
          collectionByPath[relPath] = col;
        }

        final parentRelPath = p.dirname(relPath);
        var folderItem = itemByPath[relPath];
        if (folderItem == null) {
          folderItem = MediaItem()
            ..uid = _uuid.v4()
            ..path = relPath
            ..originalPath = dir.path
            ..sourceType = MediaSourceType.localCopy
            ..type = MediaType.folder
            ..parentPath = _isManagedRoot(parentRelPath) ? null : parentRelPath
            ..isMissing = false
            ..addedAt = dirStat.changed
            ..updatedAt = dirStat.modified;
          itemsToPut.add(folderItem);
          itemByPath[relPath] = folderItem;
          addedCount++;
        } else {
          var modified = false;
          final expectedParent = _isManagedRoot(parentRelPath)
              ? null
              : parentRelPath;
          if (folderItem.type != MediaType.folder) {
            folderItem.type = MediaType.folder;
            modified = true;
          }
          if (folderItem.isMissing) {
            folderItem.isMissing = false;
            modified = true;
          }
          if (folderItem.parentPath != expectedParent) {
            folderItem.parentPath = expectedParent;
            modified = true;
          }
          if (modified) {
            itemsToPut.add(folderItem);
            updatedCount++;
          }
        }
      }

      // 全コレクションのカバー画像の整合性チェック（実在しないカバー画像をクリア）
      final docsDir = await getPrivateStorageDirectory();
      for (final col in existingCollections) {
        if (col.coverImagePath != null) {
          final coverFileInRoot = File(
            p.join(rootDir.path, col.coverImagePath!),
          );
          final coverFileInDocs = File(
            p.join(docsDir.path, col.coverImagePath!),
          );
          final exists =
              coverFileInRoot.existsSync() || coverFileInDocs.existsSync();
          if (!exists) {
            col.coverImagePath = null;
            if (!collectionsToPut.contains(col)) {
              collectionsToPut.add(col);
            }
          }
        }
      }

      // 5. メディアファイル（MediaItem）の同期準備
      final newItemsWithParent = <({MediaItem item, String parentRelPath})>[];

      for (var i = 0; i < foundFiles.length; i++) {
        final file = foundFiles[i];
        final relPath = p.relative(file.path, from: rootDir.path);
        scannedPaths.add(relPath);

        final stat = await file.stat();
        final rawParentRelPath = p.dirname(relPath) == '.'
            ? null
            : p.dirname(relPath);
        final parentRelPath =
            rawParentRelPath != null && _isManagedRoot(rawParentRelPath)
            ? null
            : rawParentRelPath;

        var item = itemByPath[relPath];
        if (item == null) {
          // 新規ファイル
          item = MediaItem()
            ..uid = _uuid.v4()
            ..path = relPath
            ..originalPath = file.path
            ..sourceType = MediaSourceType.localCopy
            ..size = stat.size
            ..type = MediaType.file
            ..parentPath = parentRelPath
            ..isMissing = false
            ..addedAt = stat.changed
            ..updatedAt = stat.modified;

          itemsToPut.add(item);
          itemByPath[relPath] = item;
          if (parentRelPath != null) {
            newItemsWithParent.add((item: item, parentRelPath: parentRelPath));
          }
          addedCount++;
        } else {
          // 既存ファイル：更新チェック
          var modified = false;
          if (item.isMissing) {
            item.isMissing = false;
            modified = true;
          }
          if (item.size != stat.size) {
            item.size = stat.size;
            item.updatedAt = stat.modified;
            modified = true;
          }
          if (item.parentPath != parentRelPath) {
            item.parentPath = parentRelPath;
            modified = true;
          }
          if (modified) {
            itemsToPut.add(item);
            updatedCount++;
          }
        }

        if (i % 50 == 0) {
          onProgress?.call(
            SyncProgress(
              status: SyncStatus.processing,
              totalItems: foundFiles.length,
              processedItems: i,
              currentFileName: p.basename(file.path),
            ),
          );
        }
      }

      // 6. Missing判定（トランザクション外でファイル存在確認）
      for (final dbItem in existingLocalItems) {
        if (!scannedPaths.contains(dbItem.path)) {
          final fullPath = p.join(rootDir.path, dbItem.path);
          final exists = dbItem.type == MediaType.folder
              ? await Directory(fullPath).exists()
              : await File(fullPath).exists();
          if (!exists) {
            if (!dbItem.isMissing) {
              dbItem.isMissing = true;
              dbItem.missingCheckedAt = DateTime.now();
              itemsToPut.add(dbItem);
              missingCount++;
            }
          }
        }
      }

      // 7. コレクションのカバー画像を解決・補完（coverImagePath が未設定の場合、配下の先頭画像またはサムネイルを設定）
      final firstCoverByParent = <String, MediaItem>{};
      for (final item in itemByPath.values) {
        final parentPath = item.parentPath;
        if (parentPath == null ||
            (item.thumbnailPath == null && !item.isImage)) {
          continue;
        }
        final current = firstCoverByParent[parentPath];
        if (current == null || compareNatural(item.path, current.path) < 0) {
          firstCoverByParent[parentPath] = item;
        }
      }
      for (final col in collectionByPath.values) {
        if (col.coverImagePath == null || col.coverImagePath!.isEmpty) {
          final candidateItem = firstCoverByParent[col.path];
          if (candidateItem != null) {
            final candidateCover =
                candidateItem.thumbnailPath ??
                (candidateItem.isImage ? candidateItem.path : null);
            if (candidateCover != null) {
              col.coverImagePath = candidateCover;
              if (!collectionsToPut.contains(col)) {
                collectionsToPut.add(col);
              }
            }
          }
        }
      }

      // 8. 一括DBトランザクション書き込み（短時間コミット）
      await _isar.writeTxn(() async {
        if (collectionsToPut.isNotEmpty) {
          await _isar.mediaCollections.putAll(collectionsToPut);
        }
        if (itemsToPut.isNotEmpty) {
          await _isar.mediaItems.putAll(itemsToPut);
        }
        final linkService = CollectionItemLinkService(_isar);
        for (final item in itemsToPut.where(
          (item) => item.type == MediaType.folder,
        )) {
          await linkService.linkItemInTransaction(item);
        }
        for (final entry in newItemsWithParent) {
          await linkService.linkItemInTransaction(entry.item);
        }
      });

      // 9. ファイルレコード作成後にアイテム単位の非表示・アーカイブを再適用。
      // 初回インポート時にDBレコードが未作成でも復元を取りこぼさない。
      if (importMetadata) {
        final itemMetadataResult = await _sidecarService.importMetadata();
        if (itemMetadataResult.isFailure) {
          return Result.failure(itemMetadataResult.errorOrNull!);
        }
      }

      // 10. 最新状態を私有サイドカーメタデータに保存
      if (exportMetadata) {
        final exportResult = await _sidecarService.exportMetadata();
        if (exportResult.isFailure) {
          return Result.failure(exportResult.errorOrNull!);
        }
      }

      onProgress?.call(
        SyncProgress(
          status: SyncStatus.completed,
          totalItems: foundFiles.length,
          processedItems: foundFiles.length,
        ),
      );

      AppLogger.i(
        LogTag.storage,
        '同期完了: 追加 $addedCount, 更新 $updatedCount, 不明 $missingCount',
      );

      return Result.success((
        added: addedCount,
        updated: updatedCount,
        missing: missingCount,
      ));
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '専用フォルダの同期処理に失敗しました', e, st);
      return Result.failure(
        AppError.file('フォルダ同期エラー: $e', original: e, stackTrace: st),
      );
    }
  }

  Future<Directory> _copyPublicMediaToPrivate(Directory publicRoot) async {
    final privateRoot = await _storageManager.getPrivateRootDirectory();

    final canonicalPublic = p.canonicalize(publicRoot.absolute.path);
    final copies = <({File source, File destination})>[];
    var scannedCount = 0;
    var totalBytes = 0;
    await for (final entity in publicRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      scannedCount++;
      if (scannedCount > _maxScannedEntryCount) {
        throw const FileSystemException('復元元の項目数が安全上限を超えています');
      }
      if (entity is! File) continue;

      final canonicalSource = p.canonicalize(entity.absolute.path);
      if (!p.isWithin(canonicalPublic, canonicalSource)) {
        throw FileSystemException('公開フォルダ外のパスは取り込めません', entity.path);
      }

      final relPath = p.relative(canonicalSource, from: canonicalPublic);
      final parts = p.split(relPath);
      if (parts.length > ImportSafetyPolicy.maxRelativePathDepth) {
        throw FileSystemException('復元元のフォルダ階層が深すぎます', entity.path);
      }
      if (parts.any(MediaFormatUtils.isIgnoredDirectory) ||
          MediaFormatUtils.isIgnoredFile(p.basename(relPath)) ||
          !MediaFormatUtils.allSupportedExtensions.contains(
            p.extension(relPath).toLowerCase(),
          )) {
        continue;
      }

      final destination = File(p.join(privateRoot.path, relPath));
      if (copies.length >= _maxImportFileCount) {
        throw const FileSystemException('復元可能なファイル数が安全上限を超えています');
      }
      totalBytes += await entity.length();
      if (totalBytes > _maxImportTotalBytes) {
        throw const FileSystemException('復元データの合計容量が安全上限を超えています');
      }
      copies.add((source: entity, destination: destination));
    }

    // 1件でも同一相対パスに異なる内容があれば、何もコピーせず停止する。
    // ユーザーが既に私有領域へ取り込んだファイルを公開側の旧コピーで
    // 上書きしないため、更新日時やサイズだけでは同一性を判断しない。
    final missingCopies = <({File source, File destination})>[];
    for (final copy in copies) {
      if (!await copy.destination.exists()) {
        missingCopies.add(copy);
        continue;
      }
      if (!await _filesHaveSameContent(copy.source, copy.destination)) {
        throw FileSystemException(
          '同じ保存先に内容の異なるファイルがあるため復元を中断しました',
          copy.destination.path,
        );
      }
    }

    var requiredBytes = 0;
    for (final copy in missingCopies) {
      requiredBytes += await copy.source.length();
    }
    await ImportSafetyPolicy.ensureAvailableCapacity(
      privateRoot.path,
      requiredBytes,
    );

    for (final copy in missingCopies) {
      await _copyFileAtomically(copy.source, copy.destination);
    }
    return privateRoot;
  }

  Future<void> _copyFileAtomically(File source, File destination) async {
    final sourceStat = await source.stat();
    if (await destination.exists()) {
      if (await _filesHaveSameContent(source, destination)) {
        return;
      }
      throw FileSystemException(
        '同じ保存先に内容の異なるファイルがあるため復元を中断しました',
        destination.path,
      );
    }

    await destination.parent.create(recursive: true);
    final partial = File('${destination.path}.tagshelf-part');
    if (await partial.exists()) await partial.delete();

    try {
      await source.openRead().pipe(partial.openWrite());
      final partialStat = await partial.stat();
      if (partialStat.size != sourceStat.size ||
          !await _filesHaveSameContent(source, partial)) {
        throw FileSystemException('コピー後のサイズ検証に失敗しました', source.path);
      }
      await partial.setLastModified(sourceStat.modified);

      if (await destination.exists()) {
        if (await _filesHaveSameContent(source, destination)) {
          await partial.delete();
          return;
        }
        throw FileSystemException(
          'コピー中に同じ保存先へ別のファイルが作成されたため復元を中断しました',
          destination.path,
        );
      }
      await partial.rename(destination.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<bool> _filesHaveSameContent(File first, File second) async {
    final firstStat = await first.stat();
    final secondStat = await second.stat();
    if (firstStat.size != secondStat.size) return false;
    final digests = await Future.wait([
      sha256.bind(first.openRead()).first,
      sha256.bind(second.openRead()).first,
    ]);
    return digests[0] == digests[1];
  }

  static bool _isManagedRoot(String path) =>
      path == 'library' || path == 'folders';
}
