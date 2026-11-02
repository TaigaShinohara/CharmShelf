import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/services/data_restore_service.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/application/use_cases/detect_restorable_data_use_case.dart';

part 'data_restore_provider.g.dart';

final dataRestoreIsAndroidProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
);

enum DataRestoreStatus {
  idle,
  detecting,
  permissionRequired,
  readyToRestore,
  restoring,
  success,
  error,
}

class DataRestoreState {
  const DataRestoreState({
    this.status = DataRestoreStatus.idle,
    this.summary = RestorableDataSummary.empty,
    this.syncProgress = const SyncProgress(status: SyncStatus.idle),
    this.error,
  });

  final DataRestoreStatus status;
  final RestorableDataSummary summary;
  final SyncProgress syncProgress;
  final AppError? error;

  DataRestoreState copyWith({
    DataRestoreStatus? status,
    RestorableDataSummary? summary,
    SyncProgress? syncProgress,
    AppError? error,
  }) {
    return DataRestoreState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
    );
  }
}

@Riverpod(keepAlive: true)
class DataRestoreNotifier extends _$DataRestoreNotifier {
  @override
  DataRestoreState build() {
    return const DataRestoreState();
  }

  /// 端末内の復元可能データを検出する。
  Future<Result<RestorableDataSummary, AppError>> detect() async {
    state = state.copyWith(status: DataRestoreStatus.detecting);

    // Androidは権限なしでは旧公開フォルダの有無を判定できないため、
    // 初回起動を一律に復元案内へ送らない。復元は設定から明示的に開始する。
    if (ref.read(dataRestoreIsAndroidProvider)) {
      state = state.copyWith(
        status: DataRestoreStatus.idle,
        summary: RestorableDataSummary.empty,
      );
      return Result.success(RestorableDataSummary.empty);
    }

    try {
      final useCase = await ref.read(
        detectRestorableDataUseCaseProvider.future,
      );
      final result = await useCase.call();

      if (result.isFailure) {
        final error = result.errorOrNull ?? AppError.file('復元可能データの検出に失敗しました');
        state = state.copyWith(status: DataRestoreStatus.error, error: error);
        return Result.failure(error);
      }

      final summary = result.dataOrNull!;
      state = summary.hasRestorableData
          ? state.copyWith(
              status: DataRestoreStatus.readyToRestore,
              summary: summary,
            )
          : state.copyWith(
              status: DataRestoreStatus.idle,
              summary: RestorableDataSummary.empty,
            );
      return Result.success(summary);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '復元データ検出中に例外発生: $e', e, st);
      final error = AppError.file(
        '復元可能データの検出に失敗しました: $e',
        original: e,
        stackTrace: st,
        context: 'DataRestoreNotifier.detect',
      );
      state = state.copyWith(status: DataRestoreStatus.error, error: error);
      return Result.failure(error);
    }
  }

  /// 設定画面からAndroidの旧公開フォルダ復元を明示的に開始する。
  void prepareManualFolderRestore() {
    state = state.copyWith(
      status: DataRestoreStatus.permissionRequired,
      summary: RestorableDataSummary.empty,
    );
  }

  /// 復元処理を実行する。
  Future<Result<void, AppError>> executeRestore() async {
    if (state.status == DataRestoreStatus.restoring) {
      return Result.failure(AppError.validation('復元処理が既に実行中です'));
    }

    state = state.copyWith(
      status: DataRestoreStatus.restoring,
      syncProgress: const SyncProgress(status: SyncStatus.scanning),
    );

    try {
      Uri? sourceUri;
      if (ref.read(dataRestoreIsAndroidProvider)) {
        final external = await ref.read(externalStorageServiceProvider.future);
        sourceUri = await external.pickFolder();
        if (sourceUri == null) {
          state = state.copyWith(status: DataRestoreStatus.permissionRequired);
          return Result.failure(AppError.permission('復元元フォルダが選択されませんでした'));
        }
      }
      final restoreService = await ref.read(dataRestoreServiceProvider.future);
      final result = await restoreService.restore(
        sourceUri: sourceUri,
        onProgress: (progress) {
          state = state.copyWith(syncProgress: progress);
        },
      );

      if (result.isSuccess) {
        state = state.copyWith(
          status: DataRestoreStatus.success,
          syncProgress: const SyncProgress(status: SyncStatus.completed),
        );
        return Result.success(null);
      } else {
        final error = result.errorOrNull ?? AppError.database('復元に失敗しました');
        state = state.copyWith(status: DataRestoreStatus.error, error: error);
        return Result.failure(error);
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '復元処理の実行に失敗: $e', e, st);
      final error = AppError.database(
        '復元処理に失敗しました: $e',
        original: e,
        stackTrace: st,
      );
      state = state.copyWith(status: DataRestoreStatus.error, error: error);
      return Result.failure(error);
    }
  }
}
