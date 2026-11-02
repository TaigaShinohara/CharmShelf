import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/data/services/folder_sync_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/services/library_database_integrity_service.dart';
import 'package:private_shelf/features/library/data/services/library_database_integrity_service_provider.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';

part 'data_restore_service.g.dart';

@Riverpod(keepAlive: true)
Future<DataRestoreService> dataRestoreService(Ref ref) async {
  final sidecarService = await ref.watch(sidecarMetadataServiceProvider.future);
  final folderSyncService = await ref.watch(folderSyncServiceProvider.future);
  return DataRestoreService(
    sidecarService,
    folderSyncService,
    integrityService: await ref.watch(
      libraryDatabaseIntegrityServiceProvider.future,
    ),
    externalStorage: await ref.watch(externalStorageServiceProvider.future),
  );
}

/// 端末内に残っているデータ（メタデータおよび実体ファイル）を一括復元するサービス。
class DataRestoreService {
  final SidecarMetadataService _sidecarService;
  final FolderSyncService _folderSyncService;
  final LibraryDatabaseIntegrityService? _integrityService;

  final ExternalStorageService? _externalStorage;

  DataRestoreService(
    this._sidecarService,
    this._folderSyncService, {
    this._integrityService,
    this._externalStorage,
  });

  /// 復元処理を実行する。
  Future<
    Result<
      ({int restoredTagsAndCols, int addedFiles, int updatedFiles}),
      AppError
    >
  >
  restore({
    Uri? sourceUri,
    Directory? preparedSource,
    bool preserveExistingTags = false,
    void Function(SyncProgress progress)? onProgress,
  }) => StorageOperationGate.runResult(() async {
    var staging = preparedSource;
    Directory? metadataStaging;
    try {
      if (sourceUri != null) {
        staging = await _externalStorage!.stageRecoveryFolder(sourceUri);
      }
      AppLogger.i(LogTag.storage, 'データ復元処理を開始');
      onProgress?.call(const SyncProgress(status: SyncStatus.scanning));

      final requestedMetadata = staging == null
          ? null
          : File(p.join(staging.path, '.tagshelf/metadata.json'));
      final validationResult = await _sidecarService
          .stageValidatedImportMetadata(
            includeLegacy: sourceUri == null && preparedSource == null,
            recoveryMetadata: requestedMetadata,
          );
      if (validationResult.isFailure) {
        return Result.failure(validationResult.errorOrNull!);
      }
      final recoveryMetadata = validationResult.dataOrNull;
      metadataStaging = recoveryMetadata?.parent;

      // 1. 公開領域に残る旧ファイルを私有領域へ安全にコピーし、
      // 先にDBレコードを作成する。旧メタデータはまだ移動しない。
      final syncResult = await _folderSyncService.syncAll(
        onProgress: onProgress,
        importMetadata: false,
        exportMetadata: false,
        importPublicRecoverySource: sourceUri == null && preparedSource == null,
        recoverySource: staging,
      );
      if (syncResult.isFailure) {
        return Result.failure(syncResult.errorOrNull!);
      }

      // 2. ファイルDBレコード作成後に旧公開メタデータを一度だけ取り込み、
      // アイテム単位の非表示・アーカイブ状態も同じ処理で復元する。
      final metaResult = await _sidecarService.importMetadata(
        includeLegacy: sourceUri == null && preparedSource == null,
        recoveryMetadata: recoveryMetadata,
        preserveExistingTags: preserveExistingTags,
      );
      if (metaResult.isFailure) {
        return Result.failure(metaResult.errorOrNull!);
      }
      final restoredMetaCount = metaResult.dataOrNull!;

      final integrityService = _integrityService;
      if (integrityService != null) {
        final integrityResult = await integrityService.repairSafeIssues();
        if (integrityResult.isFailure) {
          if (preparedSource != null) {
            return Result.failure(integrityResult.errorOrNull!);
          }
          AppLogger.w(
            LogTag.db,
            '復元済みデータの追加整合性修復を完了できませんでした',
            integrityResult.errorOrNull,
          );
        }
      }

      // 3. 整合性修復後の最新状態を私有領域へ保存する。
      final exportResult = await _sidecarService.exportMetadata();
      if (exportResult.isFailure) {
        return Result.failure(exportResult.errorOrNull!);
      }

      final syncData = syncResult.dataOrNull!;
      AppLogger.i(
        LogTag.storage,
        'データ復元完了 (メタデータ: $restoredMetaCount 件, 追加ファイル: ${syncData.added}, 更新: ${syncData.updated})',
      );

      return Result.success((
        restoredTagsAndCols: restoredMetaCount,
        addedFiles: syncData.added,
        updatedFiles: syncData.updated,
      ));
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'データ復元処理中にエラーが発生しました', e, st);
      return Result.failure(
        AppError.database('データ復元に失敗しました: $e', original: e, stackTrace: st),
      );
    } finally {
      if (staging != null && preparedSource == null) {
        try {
          await staging.delete(recursive: true); // audit: allow-file-io
        } catch (e, st) {
          AppLogger.w(LogTag.storage, '復元用一時ファイルの削除に失敗', e, st);
        }
      }
      if (metadataStaging != null) {
        try {
          await metadataStaging.delete(recursive: true); // audit: allow-file-io
        } catch (e, st) {
          AppLogger.w(LogTag.storage, '復元メタデータ一時ファイルの削除に失敗', e, st);
        }
      }
    }
  });
}
