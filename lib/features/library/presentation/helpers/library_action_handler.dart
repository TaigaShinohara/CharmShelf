import 'device_file_actions.dart';
import 'system_file_picker.dart';
import 'dart:io';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/helpers/import_picker_notification_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/archive_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/tag_management_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/trash_screen.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/security/presentation/utils/security_action_guard.dart';
import 'package:private_shelf/features/library/presentation/widgets/bulk_tag_selector_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/create_folder_dialog.dart';
import 'package:private_shelf/features/library/presentation/screens/move_destination_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/folder_picker_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/filter_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_sort_dialog.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// ライブラリ画面のダイアログ起動・メニュー操作・一括操作などのアクションハンドラー
class LibraryActionHandler {
  const LibraryActionHandler();

  /// 選択中の項目を一括でカタログ化／解除する。
  Future<void> handleBulkCatalog(
    BuildContext context,
    WidgetRef ref,
    AppMode mode, {
    required bool decatalogify,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isInternal = mode == AppMode.internal;
    final items = isInternal
        ? (ref.read(libraryViewModelProvider).value ?? [])
              .where(
                (item) => ref
                    .read(libraryViewModelProvider.notifier)
                    .selectedIds
                    .contains(item.id),
              )
              .toList()
        : (ref.read(externalLibraryViewModelProvider).value ?? [])
              .where(
                (item) => ref
                    .read(externalLibraryViewModelProvider.notifier)
                    .selectedIds
                    .contains(item.id),
              )
              .toList();
    final externalCollectionSelections = !isInternal
        ? ref
              .read(externalLibraryViewModelProvider.notifier)
              .selectedCollectionPaths
        : const <String>{};

    if (items.isEmpty && externalCollectionSelections.isEmpty) return;
    if (externalCollectionSelections.isNotEmpty) return;

    final catalogStates = items.map(_isCatalogItem).toList(growable: false);
    final allEligible =
        catalogStates.isNotEmpty &&
        catalogStates.every((isCatalog) => isCatalog == decatalogify);
    if (!allEligible) return;

    final confirmed = await _showBulkCatalogConfirmDialog(
      context,
      l10n,
      count: items.length,
      decatalogify: decatalogify,
    );
    if (!confirmed || !context.mounted) return;

    var completed = 0;
    Object? firstError;
    for (final item in items) {
      try {
        final notifier = ref.read(
          collectionNotifierProvider(item.path).notifier,
        );
        if (decatalogify) {
          await notifier.decatalogify();
        } else {
          await notifier.catalogify();
        }
        completed++;
      } catch (error, stack) {
        firstError ??= error;
        AppLogger.e(
          LogTag.storage,
          '一括カタログ操作に失敗: path=${item.path}',
          error,
          stack,
        );
      }
    }

    if (completed == items.length) {
      if (isInternal) {
        ref.read(libraryViewModelProvider.notifier).clearSelection();
        ref.invalidate(libraryViewModelProvider);
      } else {
        ref.read(externalLibraryViewModelProvider.notifier).clearSelection();
        ref.invalidate(externalLibraryViewModelProvider);
        ref.invalidate(externalFolderListProvider);
      }
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decatalogify
                  ? l10n.libraryBulkDecatalogifySuccess(completed)
                  : l10n.libraryBulkCatalogifySuccess(completed),
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      final message = completed == 0
          ? userSafeErrorMessage(firstError, l10n)
          : l10n.libraryBulkCatalogPartialResult(completed, items.length);
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  bool canBulkCatalog(
    WidgetRef ref,
    AppMode mode, {
    required bool decatalogify,
  }) {
    final isInternal = mode == AppMode.internal;
    final items = isInternal
        ? (ref.read(libraryViewModelProvider).value ?? [])
              .where(
                (item) => ref
                    .read(libraryViewModelProvider.notifier)
                    .selectedIds
                    .contains(item.id),
              )
              .toList()
        : (ref.read(externalLibraryViewModelProvider).value ?? [])
              .where(
                (item) => ref
                    .read(externalLibraryViewModelProvider.notifier)
                    .selectedIds
                    .contains(item.id),
              )
              .toList();
    if (!isInternal &&
        ref
            .read(externalLibraryViewModelProvider.notifier)
            .selectedCollectionPaths
            .isNotEmpty) {
      return false;
    }
    return items.isNotEmpty &&
        items.every((item) => _isCatalogItem(item) == decatalogify);
  }

  bool _isCatalogItem(MediaItem item) {
    final collection = item.collection.value;
    return collection != null &&
        collection.path == item.path &&
        collection.isCatalog;
  }

  Future<bool> _showBulkCatalogConfirmDialog(
    BuildContext context,
    AppLocalizations l10n, {
    required int count,
    required bool decatalogify,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              decatalogify
                  ? l10n.libraryBulkDecatalogifyConfirmTitle
                  : l10n.libraryBulkCatalogifyConfirmTitle,
            ),
            content: Text(
              decatalogify
                  ? l10n.libraryBulkDecatalogifyConfirmMessage(count)
                  : l10n.libraryBulkCatalogifyConfirmMessage(count),
            ),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: FilledButton(
                  style: decatalogify
                      ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.error,
                          foregroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    decatalogify
                        ? l10n.libraryBulkDecatalogify
                        : l10n.libraryBulkCatalogify,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// フォルダ作成ダイアログの表示
  Future<void> showCreateFolderDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final vm = ref.read(libraryViewModelProvider.notifier);
      await vm.createFolder(name.trim());
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, 'フォルダ作成に失敗: $name', error, stack);
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> showExternalBulkTierDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final vm = ref.read(externalLibraryViewModelProvider.notifier);
    if (!vm.canApplyBulkTier) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<MediaTier>(
      context: context,
      builder: (context) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: Text(l10n.librarySelectTier),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: MediaTier.values
                .map(
                  (tier) => ListTile(
                    leading: Icon(
                      LibraryActionIcons.rank,
                      color: tier.color(context),
                    ),
                    title: Text(tier.localizedLabel(context)),
                    onTap: () => Navigator.pop(context, tier),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          DialogCloseButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: l10n.commonCancel,
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await vm.bulkUpdateTier(result);
      } catch (error) {
        if (context.mounted) showErrorSnackBar(context, error);
      }
    }
  }

  /// 一括タグ設定シートの表示と適用
  Future<void> showBulkTagSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isInternal = mode == AppMode.internal;
    final canApply = isInternal
        ? ref.read(libraryViewModelProvider.notifier).canApplyBulkTags
        : ref.read(externalLibraryViewModelProvider.notifier).canApplyBulkTags;
    if (!canApply) return;

    final selectedIds = isInternal
        ? ref.read(libraryViewModelProvider.notifier).selectedIds
        : ref.read(externalLibraryViewModelProvider.notifier).selectedIds;

    if (selectedIds.isEmpty) return;

    AppLogger.d(LogTag.ui, '一括タグダイアログを開く: selectedItems=${selectedIds.length}');

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BulkTagSelectorSheet(
        selectedCount: selectedIds.length,
        onApply: (tags) async {
          AppLogger.d(
            LogTag.ui,
            '一括タグ更新を開始: selectedItems=${selectedIds.length}, selectedTags=${tags.length}',
          );
          try {
            if (isInternal) {
              await ref
                  .read(libraryViewModelProvider.notifier)
                  .bulkUpdateTags(tags, add: true);
            } else {
              await ref
                  .read(externalLibraryViewModelProvider.notifier)
                  .bulkUpdateTags(tags, add: true);
            }
            if (context.mounted) {
              AppSnackBarMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.libraryBulkTagUpdateSuccess)),
              );
            }
          } catch (error, stack) {
            AppLogger.e(LogTag.ui, '一括タグ更新に失敗', error, stack);
            if (context.mounted) {
              showErrorSnackBar(context, error);
            }
          }
        },
      ),
    );
  }

  /// プラットフォームに応じた保存先の案内テキストを取得
  String getDownloadDestinationText(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (Platform.isIOS) {
      return l10n.libraryDownloadDestinationIOS;
    } else if (Platform.isAndroid) {
      return l10n.libraryDownloadDestinationAndroid;
    } else {
      return l10n.libraryDownloadDestinationGeneric;
    }
  }

  /// ダウンロード確認ダイアログの表示
  Future<bool> showDownloadConfirmDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final destination = getDownloadDestinationText(context, l10n);
    final theme = Theme.of(context);

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.libraryDownloadConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.libraryDownloadConfirmMessage),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.libraryDownloadDestinationLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              destination,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.libraryDownload),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 一括ダウンロードの実行
  Future<void> handleBulkDownload(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    final isInternal = mode == AppMode.internal;
    final l10n = AppLocalizations.of(context)!;
    final vm = ref.read(libraryViewModelProvider.notifier);
    final selectedIds = vm.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    final confirmed = await showDownloadConfirmDialog(context, l10n);
    if (!confirmed || !context.mounted) return;

    try {
      if (isInternal) {
        await vm.downloadItems(selectedIds);
        if (context.mounted) {
          final destination = getDownloadDestinationText(context, l10n);
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.libraryDownloadSuccessWithDestination(destination),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, '一括ダウンロードに失敗', error, stack);
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  /// 一括移動の実行
  Future<void> handleBulkMove(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isInternal = mode == AppMode.internal;
    if (!isInternal) return;

    final vm = ref.read(libraryViewModelProvider.notifier);
    final selectedIds = vm.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    final allItems = ref.read(libraryViewModelProvider).value ?? [];
    final selectedItems = allItems
        .where((item) => selectedIds.contains(item.id))
        .toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.libraryMoveConfirmTitle),
        content: Text(l10n.libraryMoveConfirmMessage(selectedItems.length)),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.libraryMove),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final movingPaths = selectedItems.map((item) => item.path).toSet();
    final currentParentPath = selectedItems.first.parentPath;

    final newParentPath = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => MoveDestinationScreen(
          movingItemPaths: movingPaths,
          currentParentPath: currentParentPath,
        ),
      ),
    );
    if (!context.mounted) return;

    if (newParentPath != null) {
      // 現在の親フォルダと同じなら何もしない
      final normalizedNew = newParentPath.isEmpty ? '' : newParentPath;
      final normalizedOld =
          (currentParentPath == null || currentParentPath.isEmpty)
          ? ''
          : currentParentPath;
      if (normalizedNew == normalizedOld) return;

      // Undo用の移動元親パスを記録
      final rollbackTargets = selectedItems
          .map((i) => (id: i.id, oldParent: i.parentPath))
          .toList();

      try {
        await vm.bulkMoveItems(
          selectedIds,
          newParentPath.isEmpty ? null : newParentPath,
        );
        if (context.mounted) {
          final messenger = AppSnackBarMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.libraryMoveSuccess),
              action: SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  try {
                    for (final target in rollbackTargets) {
                      final latest =
                          ref.read(libraryViewModelProvider).value ?? [];
                      final item = latest.firstWhere(
                        (i) => i.id == target.id,
                        orElse: () =>
                            allItems.firstWhere((i) => i.id == target.id),
                      );
                      await vm.moveItem(item, target.oldParent);
                    }
                  } catch (e, st) {
                    AppLogger.e(LogTag.ui, '移動の取り消し(Undo)に失敗', e, st);
                  }
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (error, stack) {
        AppLogger.e(LogTag.ui, '一括移動に失敗', error, stack);
        if (context.mounted) {
          showErrorSnackBar(context, error);
        }
      }
    }
  }

  /// 一括複製の実行
  Future<void> handleBulkDuplicate(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isInternal = mode == AppMode.internal;
    if (!isInternal) return;

    final selectedIds = ref
        .read(libraryViewModelProvider.notifier)
        .selectedIds
        .toList();
    if (selectedIds.isEmpty) return;

    // フォルダピッカーダイアログの表示
    final newParentPath = await showFolderPickerDialog(
      context,
      title: l10n.libraryCopyTo,
    );

    if (newParentPath != null && context.mounted) {
      try {
        final vm = ref.read(libraryViewModelProvider.notifier);
        await vm.bulkDuplicateItems(
          selectedIds,
          targetParentPath: newParentPath,
        );
        if (context.mounted) {
          final messenger = AppSnackBarMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.libraryCopySuccess),
              action: SnackBarAction(
                label: l10n.settingsFileActionShow,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  ref
                      .read(
                        mediaFilterNotifierProvider(AppMode.internal).notifier,
                      )
                      .updateParentPath(newParentPath);
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (error, stack) {
        AppLogger.e(LogTag.ui, '一括複製に失敗', error, stack);
        if (context.mounted) {
          showErrorSnackBar(context, error);
        }
      }
    }
  }

  /// ライブラリのメニューアクションを起動
  Future<void> handleMenuAction(
    String value,
    BuildContext context,
    WidgetRef ref,
    MediaFilter filter,
    AppMode mode,
  ) async {
    try {
      if (value == 'filter') {
        await FilterSheet.show(context, mode: mode);
      } else if (value == 'sort') {
        await showLibrarySortDialog(context, ref, mode: mode);
      } else if (value == 'view_mode') {
        final current = ref.read(globalViewModeProvider);
        await ref
            .read(mediaFilterNotifierProvider(mode).notifier)
            .updateViewMode(
              current == ViewMode.grid ? ViewMode.list : ViewMode.grid,
            );
      } else if (value == 'simple_display') {
        final current = ref.read(globalSimpleDisplayProvider);
        await ref
            .read(mediaFilterNotifierProvider(mode).notifier)
            .updateSimpleDisplay(!current);
      } else if (value == 'catalog_display') {
        final current = filter.onlyCatalogs;
        ref
            .read(mediaFilterNotifierProvider(mode).notifier)
            .updateOnlyCatalogs(!current);
      } else if (value == 'secret_mode') {
        final isSecretMode = ref.read(secretModeProvider).value ?? false;
        if (!isSecretMode) {
          final ok = await SecurityActionGuard.requireAuth(context, ref);
          if (!ok || !context.mounted) return;
        }
        await ref.read(secretModeProvider.notifier).toggle();
      } else if (value == 'archive') {
        final ok = await SecurityActionGuard.requireAuth(context, ref);
        if (!ok || !context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ArchiveScreen()));
      } else if (value == 'trash') {
        final ok = await SecurityActionGuard.requireAuth(context, ref);
        if (!ok || !context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
      } else if (value == 'tags') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TagManagementScreen()));
      }
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, 'メニュー操作に失敗: $value', error, stack);
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  /// インポート/追加アクションの分岐
  Future<void> handleAddAction(
    String value,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (value == 'folder') {
        await showCreateFolderDialog(context, ref);
      } else if (ref.read(systemFilePickerIsAndroidProvider) &&
          (value == 'import_folder' ||
              value == 'import_file' ||
              value == 'import_source')) {
        final target = ref
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .parentPath;
        if (value == 'import_source') {
          await showDeviceFileActions(context, ref, targetParentPath: target);
        } else {
          await performDeviceFileAction(
            value == 'import_file'
                ? DeviceFileAction.importFiles
                : DeviceFileAction.importFolder,
            context,
            ref,
            targetParentPath: target,
          );
        }
      } else if (value == 'import_folder') {
        final storageService = await ref.read(
          externalStorageServiceProvider.future,
        );
        final uri = await runImportPicker(
          title: l10n.libraryReturnToTagShelfTitle,
          body: l10n.libraryReturnToTagShelfBody,
          pick: storageService.pickFolder,
        );
        if (uri != null && context.mounted) {
          final filter = ref.read(
            mediaFilterNotifierProvider(AppMode.internal),
          );
          ref
              .read(importFlowNotifierProvider.notifier)
              .startScan(uri, targetParentPath: filter.parentPath);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
          );
        }
      } else if (value == 'import_file') {
        final picked = await runImportPicker(
          title: l10n.libraryReturnToTagShelfTitle,
          body: l10n.libraryReturnToTagShelfBody,
          pick: () => FilePicker.pickFiles(type: FileType.any),
        );
        final paths = picked?.map((f) => f.path).whereType<String>().toList();
        if (paths != null && paths.isNotEmpty && context.mounted) {
          final filter = ref.read(
            mediaFilterNotifierProvider(AppMode.internal),
          );
          ref
              .read(importFlowNotifierProvider.notifier)
              .startFilesScan(paths, targetParentPath: filter.parentPath);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
          );
        }
      }
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, '追加操作に失敗: $value', error, stack);
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  /// エラーSnackBarの安全な表示
  void showErrorSnackBar(BuildContext context, Object error, {WidgetRef? ref}) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final isPermissionError =
        error is AppError && error.category == ErrorCategory.permission;

    final snackBar = SnackBar(
      content: Text(userSafeErrorMessage(error, l10n)),
      action: isPermissionError
          ? SnackBarAction(
              label: l10n.settingsImportNotificationOpenSettings,
              onPressed: () async {
                if (ref != null) {
                  await ref
                      .read(permissionRepositoryProvider)
                      .openAppSettings();
                } else {
                  await PermissionRepositoryImpl().openAppSettings();
                }
              },
            )
          : null,
    );

    AppSnackBarMessenger.of(context).showSnackBar(snackBar);
  }
}
