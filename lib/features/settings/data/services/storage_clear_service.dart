import 'package:private_shelf/core/services/storage_operation_gate.dart';
import '../../../device_files/data/device_file_repository.dart';
// audit: allow-file-io
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../core/providers/isar_provider.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/services/local_storage_manager.dart';
import '../../../../core/services/operation_journal_service.dart';
import '../../../library/data/services/external_storage_service.dart';
import '../../../library/data/repositories/import_source_repository.dart';
import 'storage_clear_recovery_store.dart';

part 'storage_clear_service.g.dart';

@Riverpod(keepAlive: true)
Future<StorageClearService> storageClearService(
  Ref ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  final storageManager = ref.watch(localStorageManagerProvider);
  final externalStorage = await ref.watch(
    externalStorageServiceProvider.future,
  );
  final operationJournal = ref.watch(operationJournalServiceProvider);
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return StorageClearService(
    isar,
    storageManager,
    recoveryStore: StorageClearRecoveryStore(),
    releaseAllExternalAccess: externalStorage.releaseAllPersistedAccess,
    clearOperationJournal: operationJournal.clearAll,
    clearTransientPreferences: () async {
      final support = await getApplicationSupportDirectory();
      await DeviceFileRepository(
        File('${support.path}/device_files_v1.json'),
      ).clear();
      ref.invalidate(deviceFileRepositoryProvider);
      if (!await preferences.remove(ImportSourceRepository.storageKey) &&
          preferences.containsKey(ImportSourceRepository.storageKey)) {
        throw StateError('Could not clear import source registrations');
      }
      for (final key in [
        AppPreferences.importFlowDraftSessionKey,
        AppPreferences.importPickerGrantReleasesKey,
      ]) {
        if (!await preferences.remove(key) && preferences.containsKey(key)) {
          throw StateError('インポート下書き・権限解放記録を削除できませんでした');
        }
      }
      final saved = await preferences.setBool(
        AppPreferences.restorePromptHandledKey,
        true,
      );
      if (!saved) {
        throw StateError('復元確認の完了状態を保存できませんでした');
      }
    },
  );
}

/// ストレージ消去処理の中断を管理するトークン
class StorageClearCancellationToken {
  bool _isCancelled = false;

  /// 中断要求が出ているか
  bool get isCancelled => _isCancelled;

  /// 処理を中断する
  void cancel() {
    _isCancelled = true;
  }
}

/// 専用ストレージディレクトリ内のファイルおよびデータベースを完全に初期化・消去するサービス。
class StorageClearService {
  final Isar _isar;
  final LocalStorageManager _storageManager;
  final Future<void> Function(FileSystemEntity entity) _deleteEntity;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function() _releaseAllExternalAccess;
  final Future<void> Function() _clearOperationJournal;
  final Future<void> Function() _clearTransientPreferences;
  final StorageClearRecoveryStore _recoveryStore;

  StorageClearService(
    this._isar,
    this._storageManager, {
    StorageClearRecoveryStore? recoveryStore,
    Future<void> Function(FileSystemEntity entity)? deleteEntity,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function()? releaseAllExternalAccess,
    Future<void> Function()? clearOperationJournal,
    Future<void> Function()? clearTransientPreferences,
  }) : _deleteEntity = deleteEntity ?? _deleteRecursively,
       _recoveryStore = recoveryStore ?? StorageClearRecoveryStore(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _releaseAllExternalAccess =
           releaseAllExternalAccess ?? _completeImmediately,
       _clearOperationJournal = clearOperationJournal ?? _completeImmediately,
       _clearTransientPreferences =
           clearTransientPreferences ?? _completeImmediately;

  static Future<void> _completeImmediately() async {}

  static Future<void> _deleteRecursively(FileSystemEntity entity) async {
    await entity.delete(recursive: entity is Directory); // audit: allow
  }

  /// 専用フォルダ内の全ファイル、キャッシュ、およびIsarデータベースを完全に消去する。
  Future<Result<void, AppError>> clearStorage({
    StorageClearCancellationToken? cancellationToken,
  }) => StorageOperationGate.runResult(() async {
    if (cancellationToken?.isCancelled == true) {
      AppLogger.i(LogTag.storage, 'ストレージ消去処理が開始前に中断されました');
      return Result.failure(
        AppError.file('ストレージ消去が中断されました', severity: ErrorSeverity.info),
      );
    }

    try {
      await _recoveryStore.markPending();
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去の開始状態を保存できませんでした', e, st);
      return Result.failure(
        AppError.file('ストレージ消去を安全に開始できませんでした: $e', original: e, stackTrace: st),
      );
    }

    return _performPendingClear();
  });

  /// 前回中断されたストレージ消去を、通常画面の初期化より前に再開する。
  Future<Result<void, AppError>> recoverPendingClear() async {
    try {
      if (await _recoveryStore.readStage() == null) {
        return Result.success(null);
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去の復旧状態を確認できませんでした', e, st);
      return Result.failure(
        AppError.file(
          'ストレージ消去の復旧状態を確認できませんでした: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
    return _performPendingClear();
  }

  Future<bool> hasPendingClear() => _recoveryStore.isPending();

  Future<Result<void, AppError>> _performPendingClear() async {
    try {
      AppLogger.w(LogTag.storage, 'ストレージ消去処理を開始または再開します');

      final stage = await _recoveryStore.readStage();
      if (stage == null) {
        return Result.success(null);
      }

      if (stage == StorageClearRecoveryStage.clearingInternal) {
        // DB消去後にプロセスが終了しても、復旧マーカーによって次回起動時に
        // 残りのファイル消去を再開できる。
        await _isar.writeTxn(() async {
          await _isar.clear();
        });

        Object? firstCleanupError;
        StackTrace? firstCleanupStack;
        Future<void> runCleanup(Future<void> Function() cleanup) async {
          try {
            await cleanup();
          } catch (error, stackTrace) {
            firstCleanupError ??= error;
            firstCleanupStack ??= stackTrace;
          }
        }

        await runCleanup(_clearOperationJournal);

        final privateRoot = await _storageManager.getPrivateRootDirectory();
        await runCleanup(
          () => _clearDirectoryContents(
            privateRoot,
            preserveActiveDatabase: true,
          ),
        );

        final tempDir = await _temporaryDirectory();
        await runCleanup(
          () => _clearDirectoryContents(tempDir, preserveActiveDatabase: false),
        );
        await runCleanup(_clearTransientPreferences);

        // 専用ディレクトリおよび私有メタデータディレクトリ構造を再生成
        await runCleanup(_storageManager.getPrivateRootDirectory);
        await runCleanup(_storageManager.getMetadataDirectory);

        if (firstCleanupError != null) {
          Error.throwWithStackTrace(firstCleanupError!, firstCleanupStack!);
        }

        // ここから先の再試行では、新しく作成された内部データを再消去しない。
        await _recoveryStore.markExternalReleasePending();
      }

      // 外部の元ファイル自体は残す。内部データの消去が完了した後でのみ、
      // アプリが保持する永続アクセスを解放する。部分失敗時はマーカーを残し、
      // 未解放分を次回起動時に再試行する。
      await _releaseAllExternalAccess();
      _storageManager.clearRootDirectoryCache();

      // すべての破壊的処理と後処理が完了した最後にだけ復旧マーカーを外す。
      await _recoveryStore.markComplete();

      AppLogger.i(LogTag.storage, 'ストレージ消去処理が正常に完了しました');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去処理に失敗しました', e, st);
      return Result.failure(
        AppError.file('ストレージ消去処理に失敗しました: $e', original: e, stackTrace: st),
      );
    }
  }

  Future<void> _clearDirectoryContents(
    Directory directory, {
    required bool preserveActiveDatabase,
  }) async {
    if (!await directory.exists()) return;

    Object? firstDeleteError;
    StackTrace? firstDeleteStack;
    final entities = directory.listSync(followLinks: false);
    for (final entity in entities) {
      if (preserveActiveDatabase && _isActiveDatabaseEntity(entity)) {
        continue;
      }
      try {
        await _deleteEntity(entity);
      } catch (error, stackTrace) {
        firstDeleteError ??= error;
        firstDeleteStack ??= stackTrace;
      }
    }

    final residual = directory
        .listSync(followLinks: false)
        .where(
          (entity) =>
              !preserveActiveDatabase || !_isActiveDatabaseEntity(entity),
        )
        .toList();
    if (residual.isNotEmpty) {
      if (firstDeleteError != null) {
        Error.throwWithStackTrace(firstDeleteError, firstDeleteStack!);
      }
      throw FileSystemException('削除後も管理対象が残っています', residual.first.path);
    }
    if (firstDeleteError != null) {
      Error.throwWithStackTrace(firstDeleteError, firstDeleteStack!);
    }
  }

  bool _isActiveDatabaseEntity(FileSystemEntity entity) {
    final databasePath = _isar.path;
    if (databasePath == null) return false;
    final entityPath = entity.absolute.path;
    return entityPath == databasePath || entityPath == '$databasePath.lock';
  }
}
