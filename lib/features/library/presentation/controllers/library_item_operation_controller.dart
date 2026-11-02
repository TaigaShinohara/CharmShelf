import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/delete_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/duplicate_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/move_media_item_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/update_media_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

part 'library_item_operation_controller.g.dart';

@riverpod
class LibraryItemOperationController extends _$LibraryItemOperationController {
  @override
  void build() {}

  /// 新規フォルダを作成する
  Future<void> createFolder(String name) async {
    final parentPath = ref
        .read(mediaFilterNotifierProvider(AppMode.internal))
        .parentPath;

    final mode = ref.read(appModeProvider);
    if (mode != AppMode.internal) {
      final error = AppError.validation('フォルダ作成は内部モードでのみ可能です。');
      AppLogger.e(LogTag.storage, 'createFolder failed: Validation error');
      throw error;
    }

    AppLogger.d(LogTag.storage, 'フォルダ作成開始: $name (parent: $parentPath)');
    final result = await ref
        .read(createFolderUseCaseProvider)
        .invoke(name, parentPath: parentPath);

    result.when(
      success: (_) {
        AppLogger.d(LogTag.storage, 'フォルダ作成成功: $name');
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, 'フォルダ作成失敗: $error');
        throw error;
      },
    );
  }

  /// アイテムを別のフォルダに移動する
  Future<void> moveItem(
    MediaItem item,
    String? newParentPath, {
    bool showProgress = true,
  }) async {
    final mode = ref.read(appModeProvider);
    if (mode != AppMode.internal ||
        item.sourceType != MediaSourceType.localCopy) {
      final error = AppError.validation('移動は内部モードのアイテムのみ可能です。');
      AppLogger.e(LogTag.storage, 'moveItem failed: Validation error');
      throw error;
    }

    final progressNotifier = ref.read(syncProgressNotifierProvider.notifier);
    if (showProgress) {
      progressNotifier.reset();
      progressNotifier.setTotalItems(1);
      progressNotifier.setStatus(SyncStatus.processing);
    }
    AppLogger.d(LogTag.storage, '移動開始: ${item.path} -> $newParentPath');
    final result = await ref
        .read(moveMediaItemUseCaseProvider)
        .invoke(item, newParentPath);

    result.when(
      success: (_) {
        AppLogger.d(LogTag.storage, '移動成功: ${item.path}');
        if (showProgress) {
          progressNotifier.updateProgress(
            SyncProgress(
              status: SyncStatus.processing,
              totalItems: 1,
              processedItems: 1,
              currentFileName: p.basename(item.path),
            ),
          );
          progressNotifier.setStatus(SyncStatus.idle);
        }
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, '移動失敗: $error');
        if (showProgress) {
          progressNotifier.setStatus(
            SyncStatus.error,
            errorMessage: error.message,
          );
        }
        throw error;
      },
    );
  }

  /// アイテムを複製する
  Future<void> duplicateItem(MediaItem item, {String? targetParentPath}) async {
    final mode = ref.read(appModeProvider);
    if (mode != AppMode.internal ||
        item.sourceType != MediaSourceType.localCopy) {
      final error = AppError.validation('複製は内部モードのアイテムのみ可能です。');
      AppLogger.e(LogTag.storage, 'duplicateItem failed: Validation error');
      throw error;
    }

    AppLogger.d(
      LogTag.storage,
      '複製開始: ${item.path}${targetParentPath != null ? ' -> $targetParentPath' : ''}',
    );
    final result = await ref
        .read(duplicateMediaUseCaseProvider)
        .invoke(item, targetParentPath: targetParentPath);

    result.when(
      success: (newItem) {
        AppLogger.d(LogTag.storage, '複製成功: ${newItem.path}');
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, '複製失敗: $error');
        throw error;
      },
    );
  }

  /// アイテム名を変更する
  Future<void> renameItem(MediaItem item, String newName) async {
    final mode = ref.read(appModeProvider);
    if (mode != AppMode.internal ||
        item.sourceType != MediaSourceType.localCopy) {
      final error = AppError.validation('名前変更は内部モードのアイテムのみ可能です。');
      AppLogger.e(LogTag.storage, 'renameItem failed: Validation error');
      throw error;
    }

    final normalizedName = newName.trim();
    final nameError = FileNameValidator.validate(normalizedName);
    if (nameError != null) {
      final error = AppError.validation('無効なファイル名です: $normalizedName');
      AppLogger.e(LogTag.storage, 'renameItem failed: Invalid name');
      throw error;
    }

    AppLogger.d(LogTag.storage, 'リネーム開始: ${item.path} -> $normalizedName');
    final result = await ref
        .read(moveMediaItemUseCaseProvider)
        .invoke(item, item.parentPath, newName: normalizedName);

    result.when(
      success: (_) {
        AppLogger.d(LogTag.storage, 'リネーム成功: ${item.path}');
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, 'リネーム失敗: $error');
        throw error;
      },
    );
  }

  /// 複数アイテムを一括で移動する
  Future<void> bulkMoveItems(
    List<MediaItem> allItems,
    List<int> ids,
    String? newParentPath,
  ) async {
    if (ids.isEmpty) return;

    final itemsToMove = allItems
        .where((item) => ids.contains(item.id))
        .toList();

    var successCount = 0;
    final failedItems = <MediaItem>[];
    final progressNotifier = ref.read(syncProgressNotifierProvider.notifier);
    progressNotifier.reset();
    progressNotifier.setTotalItems(itemsToMove.length);
    progressNotifier.setStatus(SyncStatus.processing);

    try {
      for (final item in itemsToMove) {
        try {
          await moveItem(item, newParentPath, showProgress: false);
          successCount++;
          progressNotifier.updateProgress(
            SyncProgress(
              status: SyncStatus.processing,
              totalItems: itemsToMove.length,
              processedItems: successCount + failedItems.length,
              currentFileName: p.basename(item.path),
            ),
          );
        } catch (e) {
          failedItems.add(item);
        }
      }
    } finally {
      ref.read(librarySelectionNotifierProvider.notifier).clearSelection();
      if (failedItems.isEmpty) {
        progressNotifier.setStatus(SyncStatus.idle);
      }
    }

    if (failedItems.isNotEmpty) {
      progressNotifier.setStatus(SyncStatus.error);
      throw AppError.file('一部の項目の移動に失敗しました').withAdditionalData({
        'totalCount': itemsToMove.length,
        'successCount': successCount,
        'failedItems': failedItems
            .map(
              (item) => {
                'path': item.path,
                'displayName': p.basename(item.path),
              },
            )
            .toList(),
      });
    }
  }

  /// 複数アイテムを一括で複製する
  Future<void> bulkDuplicateItems(
    List<MediaItem> allItems,
    List<int> ids, {
    String? targetParentPath,
  }) async {
    if (ids.isEmpty) return;

    final itemsToDuplicate = allItems
        .where((item) => ids.contains(item.id))
        .toList();

    var successCount = 0;
    final failedItems = <MediaItem>[];

    for (final item in itemsToDuplicate) {
      try {
        await duplicateItem(item, targetParentPath: targetParentPath);
        successCount++;
      } catch (e) {
        failedItems.add(item);
      }
    }

    ref.read(librarySelectionNotifierProvider.notifier).clearSelection();

    if (failedItems.isNotEmpty) {
      throw AppError.file('一部の項目の複製に失敗しました').withAdditionalData({
        'totalCount': itemsToDuplicate.length,
        'successCount': successCount,
        'failedItems': failedItems
            .map(
              (item) => {
                'path': item.path,
                'displayName': p.basename(item.path),
              },
            )
            .toList(),
      });
    }
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
  }

  /// アイテムをゴミ箱へ移動（削除）する
  Future<void> deleteItem(MediaItem item) async {
    final useCase = ref.read(deleteMediaUseCaseProvider);
    final progressNotifier = ref.read(syncProgressNotifierProvider.notifier);

    progressNotifier.reset();
    progressNotifier.setStatus(SyncStatus.processing);

    final result = await useCase.invoke(
      item,
      isCancelled: () => ref.read(syncProgressNotifierProvider).isCancelled,
      onProgress: (processed, total, itemName) {
        progressNotifier.updateProgress(
          SyncProgress(
            status: SyncStatus.processing,
            totalItems: total,
            processedItems: processed,
            currentFileName: itemName,
          ),
        );
      },
    );

    if (result is Success) {
      if (item.sourceType == MediaSourceType.externalReference) {
        ref.invalidate(externalFolderListProvider);
        ref.invalidate(externalFolderItemsProvider(item.parentPath));
        ref.invalidate(externalRootItemsProvider);
        ref.invalidate(collectionNotifierProvider(item.path));
      }

      progressNotifier.setStatus(SyncStatus.idle);
      ref.invalidate(libraryViewModelProvider);
    } else if (result is Failure<void, AppError>) {
      progressNotifier.setStatus(
        SyncStatus.error,
        errorMessage: result.error.message,
      );
      throw result.error;
    }
  }

  /// 削除されたアイテムを復元する
  Future<void> restoreDeletedItem(int itemId) async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final itemResult = await repository.getById(itemId);
    if (itemResult.isFailure) throw itemResult.errorOrNull!;
    final item = itemResult.dataOrNull;
    if (item == null || !item.isTrashed || !item.isTrashRoot) {
      throw AppError.validation('Deleted item is no longer in Trash');
    }
    final result = await ref
        .read(restoreTrashedMediaUseCaseProvider)
        .invoke(item);
    if (result.isFailure) throw result.errorOrNull!;
    if (item.sourceType == MediaSourceType.externalReference) {
      ref.invalidate(externalFolderListProvider);
      ref.invalidate(externalFolderItemsProvider(item.parentPath));
      ref.invalidate(externalRootItemsProvider);
      ref.invalidate(collectionNotifierProvider(item.path));
    }
    ref.invalidate(libraryViewModelProvider);
  }

  /// アイテム情報を更新する
  Future<void> updateItem(MediaItem item) async {
    final useCase = ref.read(updateMediaUseCaseProvider);
    final result = await useCase.invoke(item);
    if (result is Success) {
      ref.invalidate(libraryViewModelProvider);
    } else if (result is Failure<void, AppError>) {
      throw result.error;
    }
  }

  /// 必要に応じてサムネイルを生成し、パスを返す
  Future<String?> ensureThumbnail(MediaItem item) async {
    if (item.thumbnailPath != null) return item.thumbnailPath;

    final fileService = ref.read(fileServiceProvider);
    File file;
    String? tempPath;

    try {
      if (item.sourceType == MediaSourceType.externalReference) {
        final storageService = await ref.read(
          externalStorageServiceProvider.future,
        );
        tempPath = await storageService.copyToTemp(
          Uri.parse(item.path),
          p.basename(item.path),
        );
        if (tempPath == null) return null;
        file = File(tempPath);
      } else {
        final docsDir = await getPrivateStorageDirectory();
        file = File(p.join(docsDir.path, item.path));
      }

      final result = await fileService.generateThumbnail(
        file,
        timeMs: _isVideo(item.path) ? 5000 : null,
      );

      if (tempPath != null) {
        final f = File(tempPath);
        if (f.existsSync()) await f.delete();
      }

      if (result is Success<String, AppError>) {
        item.thumbnailPath = result.data;
        await updateItem(item);
        return item.thumbnailPath;
      }
    } catch (e) {
      AppLogger.e(LogTag.storage, 'Failed to ensure thumbnail: $e');
    }
    return null;
  }

  /// フォルダのカバー画像を設定する
  Future<void> setAsFolderCover(MediaItem item) async {
    if (item.parentPath == null || item.parentPath!.isEmpty) {
      throw AppError.validation('Item must be in a folder');
    }

    final repository = await ref.read(mediaRepositoryProvider.future);
    final result = await repository.getCollectionByPath(item.parentPath!);

    if (result is Success<MediaCollection?, AppError>) {
      var collection = result.data;
      // StorageRef 経由のフォールバックで別パスのカタログが
      // 返る場合があっても、表紙を変えるのは直接の親だけにする。
      if (collection?.path != item.parentPath) {
        collection = null;
      }
      if (collection == null) {
        final ext = p.extension(item.parentPath!);
        final isExternal = item.sourceType == MediaSourceType.externalReference;
        final type = isExternal
            ? CollectionType.externalFolder
            : (ext.isEmpty ? CollectionType.folder : CollectionType.file);

        collection = MediaCollection()
          ..title = p.basename(item.parentPath!)
          ..path = item.parentPath!
          ..type = type
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
      }

      var thumbPath = await ensureThumbnail(item);
      if (thumbPath == null) {
        if (item.sourceType == MediaSourceType.localCopy && item.isImage) {
          thumbPath = item.path;
        } else {
          throw AppError.file('Failed to create thumbnail for cover');
        }
      }

      collection.coverImagePath = thumbPath;
      collection.updatedAt = DateTime.now();

      final saveResult = await repository.saveCollection(collection);
      saveResult.when(
        success: (_) {
          ref.invalidate(collectionNotifierProvider(item.parentPath!));
        },
        failure: (error) {
          throw error;
        },
      );
    } else if (result is Failure<MediaCollection?, AppError>) {
      throw result.error;
    }
  }
}
