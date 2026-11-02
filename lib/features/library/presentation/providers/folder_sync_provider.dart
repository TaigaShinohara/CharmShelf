import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/application/use_cases/sync_library_folder_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';

part 'folder_sync_provider.g.dart';

@riverpod
class FolderSyncNotifier extends _$FolderSyncNotifier {
  @override
  SyncProgress build() {
    return const SyncProgress(status: SyncStatus.idle);
  }

  /// 専用フォルダの同期を実行
  Future<Result<({int added, int updated, int missing}), AppError>>
  sync() async {
    // 既に同期処理中なら多重実行をガード
    if (state.status == SyncStatus.scanning ||
        state.status == SyncStatus.processing) {
      return Result.failure(AppError.validation('同期処理が既に実行中です'));
    }

    state = const SyncProgress(status: SyncStatus.scanning);

    try {
      final useCase = await ref.read(syncLibraryFolderUseCaseProvider.future);
      final result = await useCase.call(
        onProgress: (progress) {
          state = progress;
        },
      );

      if (result.isFailure) {
        state = SyncProgress(
          status: SyncStatus.error,
          errorMessage: result.errorOrNull?.message,
        );
      } else {
        state = const SyncProgress(status: SyncStatus.completed);
        ref.invalidate(libraryViewModelProvider);
      }

      return result;
    } catch (e) {
      final error = AppError.file('同期処理に失敗しました: $e');
      state = SyncProgress(
        status: SyncStatus.error,
        errorMessage: error.message,
      );
      return Result.failure(error);
    }
  }
}
