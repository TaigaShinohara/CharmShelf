import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/application/use_cases/bulk_update_tags_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/bulk_update_tier_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/export_media_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';

part 'library_batch_action_controller.g.dart';

@riverpod
class LibraryBatchActionController extends _$LibraryBatchActionController {
  @override
  void build() {}

  /// 選択中アイテムのタグを一括更新する
  Future<void> bulkUpdateTags(
    List<MediaItem> allItems,
    List<Tag> tags, {
    required bool add,
  }) async {
    final selectedIds = ref.read(librarySelectionNotifierProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    final selectedItems = allItems
        .where((item) => selectedIds.contains(item.id))
        .toList();
    if (selectedItems.isEmpty) return;

    AppLogger.i(
      LogTag.storage,
      'Bulk update tags requested: mode=internal, selectedItems=${selectedItems.length}, selectedTags=${tags.length}, add=$add',
    );

    final result = await ref
        .read(bulkUpdateTagsUseCaseProvider)
        .invoke(items: selectedItems, tags: tags, add: add);

    result.when(
      success: (_) {
        final targetPaths = selectedItems
            .map((item) => item.path)
            .toSet()
            .toList(growable: false);
        for (final path in targetPaths) {
          ref.invalidate(collectionNotifierProvider(path));
        }
        ref.read(librarySelectionNotifierProvider.notifier).clearSelection();
        ref.invalidate(libraryViewModelProvider);
        AppLogger.i(
          LogTag.storage,
          'Bulk update tags completed: mode=internal, updatedCollections=${targetPaths.length}, selectedTags=${tags.length}',
        );
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, 'Bulk update tags failed: $error');
        throw error;
      },
    );
  }

  /// 選択中アイテムのティアを一括更新する
  Future<void> bulkUpdateTier(List<MediaItem> allItems, MediaTier tier) async {
    final selectedIds = ref.read(librarySelectionNotifierProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    final selectedItems = allItems
        .where((item) => selectedIds.contains(item.id))
        .toList();
    if (selectedItems.isEmpty) return;

    final result = await ref
        .read(bulkUpdateTierUseCaseProvider)
        .invoke(items: selectedItems, tier: tier);

    result.when(
      success: (_) {
        final targetPaths = selectedItems
            .map((item) => item.path)
            .toSet()
            .toList(growable: false);
        for (final path in targetPaths) {
          ref.invalidate(collectionNotifierProvider(path));
        }
        ref.read(librarySelectionNotifierProvider.notifier).clearSelection();
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        AppLogger.e(LogTag.storage, 'Bulk update tier failed: $error');
        throw error;
      },
    );
  }

  /// 指定されたアイテムを端末にダウンロードする
  Future<void> downloadItems(List<MediaItem> allItems, List<int> ids) async {
    if (ids.isEmpty) return;

    final itemsToDownload = allItems
        .where((item) => ids.contains(item.id))
        .toList();
    if (itemsToDownload.isEmpty) return;

    final progressNotifier = ref.read(syncProgressNotifierProvider.notifier);
    progressNotifier.reset();
    progressNotifier.setStatus(SyncStatus.processing);

    final useCase = await ref.read(exportMediaUseCaseProvider.future);
    final result = await useCase.invoke(
      itemsToDownload,
      onProgress: (processed, total, fileName) {
        progressNotifier.updateProgress(
          SyncProgress(
            status: SyncStatus.processing,
            totalItems: total,
            processedItems: processed,
            currentFileName: fileName,
          ),
        );
      },
    );

    result.when(
      success: (_) {
        progressNotifier.reset();
        ref.read(librarySelectionNotifierProvider.notifier).clearSelection();
        ref.invalidate(libraryViewModelProvider);
      },
      failure: (error) {
        progressNotifier.setStatus(
          SyncStatus.error,
          errorMessage: error.message,
        );
        throw error;
      },
    );
  }

  /// 指定されたアイテムを共有する
  Future<void> shareItems(
    List<MediaItem> allItems,
    List<int> ids, {
    Rect? sharePositionOrigin,
  }) async {
    if (ids.isEmpty) return;

    final itemsToShare = allItems
        .where((item) => ids.contains(item.id))
        .toList();
    if (itemsToShare.isEmpty) return;

    final docsDir = await getPrivateStorageDirectory();
    final xFiles = <XFile>[];
    final tempFiles = <File>[];

    final storageService = await ref.read(
      externalStorageServiceProvider.future,
    );

    for (final item in itemsToShare) {
      if (item.type == MediaType.file) {
        String? fullPath;
        if (item.sourceType == MediaSourceType.externalReference) {
          fullPath = await storageService.copyToTemp(
            Uri.parse(item.path),
            p.basename(item.path),
          );
          if (fullPath != null) {
            tempFiles.add(File(fullPath));
          }
        } else {
          fullPath = p.join(docsDir.path, item.path);
        }

        if (fullPath != null && await File(fullPath).exists()) {
          xFiles.add(XFile(fullPath, name: p.basename(item.path)));
        }
      }
    }

    if (xFiles.isNotEmpty) {
      try {
        await SharePlus.instance.share(
          ShareParams(files: xFiles, sharePositionOrigin: sharePositionOrigin),
        );
      } finally {
        for (final file in tempFiles) {
          if (await file.exists()) {
            await file.delete().catchError((_) => file);
          }
        }
      }
    }
  }

  /// テキストをクリップボードにコピーする
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
