// Application layer: coordinates domain contracts with persistence services.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/services/folder_sync_service.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';

part 'sync_library_folder_use_case.g.dart';

@Riverpod(keepAlive: true)
Future<SyncLibraryFolderUseCase> syncLibraryFolderUseCase(
  Ref ref,
) async {
  final folderSyncService = await ref.watch(folderSyncServiceProvider.future);
  return SyncLibraryFolderUseCase(folderSyncService);
}

/// 専用ローカルフォルダとDBの同期を実行するユースケース。
class SyncLibraryFolderUseCase {
  final FolderSyncService _folderSyncService;

  SyncLibraryFolderUseCase(this._folderSyncService);

  Future<Result<({int added, int updated, int missing}), AppError>> call({
    void Function(SyncProgress progress)? onProgress,
  }) {
    return _folderSyncService.syncAll(onProgress: onProgress);
  }
}
