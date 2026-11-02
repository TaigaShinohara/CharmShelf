import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/trash_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/folder_picker_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/shared/widgets/dialogs/input_dialog.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trashState = ref.watch(trashViewModelProvider);
    final itemsAsync = trashState.items;
    final isBusy = trashState.isBusy || trashState.busyItemIds.isNotEmpty;
    final isSimpleDisplay = ref.watch(globalSimpleDisplayProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(
            titleText: l10n.libraryTrashTitle,
            inlineTitle: true,
            actions: [
              if (itemsAsync.value?.isNotEmpty == true)
                TextButton(
                  onPressed: isBusy ? null : () => _emptyTrash(context, ref),
                  child: Text(l10n.libraryTrashEmptyAction),
                ),
            ],
          ),
          if (isBusy)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 3),
            ),
          itemsAsync.when(
            loading: () => const SliverLoadingWidget(),
            error: (e, st) {
              AppLogger.e(LogTag.ui, 'ゴミ箱一覧の読み込み失敗', e, st);
              final appError = e is AppError
                  ? e
                  : AppError.ui(
                      l10n.commonErrorOccurred,
                      original: e,
                      stackTrace: st,
                      context: 'TrashScreen.build',
                    );
              return SliverErrorStateWidget(
                error: appError,
                onRetry: () =>
                    ref.read(trashViewModelProvider.notifier).refresh(),
              );
            },
            data: (items) {
              if (items.isEmpty) {
                return SliverEmptyStateWidget(
                  icon: Icons.delete_outline,
                  title: l10n.libraryTrashEmpty,
                  action: FilledButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.libraryTitle),
                    onPressed: () {
                      ref.read(currentTabIndexProvider.notifier).goToLibrary();
                      Navigator.of(context).maybePop();
                    },
                  ),
                );
              }
              return SliverPadding(
                padding: AppSpacing.edgeInsetsSm,
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isItemBusy =
                        trashState.isBusy ||
                        trashState.busyItemIds.contains(item.id);
                    return MediaListTile(
                      item: item,
                      isSimpleDisplay: isSimpleDisplay,
                      subtitle: isSimpleDisplay
                          ? const SizedBox.shrink()
                          : Text(
                              _itemDetails(context, item, l10n),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                      onTap: isItemBusy
                          ? null
                          : () => _showItemOptions(context, ref, item),
                      trailing: isItemBusy
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.restore_outlined),
                              tooltip: l10n.libraryTrashRestore,
                              onPressed: () => _handleAction(
                                context,
                                ref,
                                item,
                                _TrashAction.restore,
                              ),
                            ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _itemDetails(
    BuildContext context,
    MediaItem item,
    AppLocalizations l10n,
  ) {
    final details = <String>[l10n.libraryTrashOriginalLocation(item.path)];
    final trashedAt = item.trashedAt?.toLocal();
    if (trashedAt != null) {
      final material = MaterialLocalizations.of(context);
      final date = material.formatMediumDate(trashedAt);
      final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(trashedAt));
      details.add(l10n.libraryTrashDeletedAt('$date $time'));
    }
    return details.join('\n');
  }

  Future<void> _showItemOptions(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    ref.read(feedbackServiceProvider).lightImpact();
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_TrashAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ActionBottomSheet<_TrashAction>(
        title: p.basename(item.path),
        items: [
          ActionSheetItem<_TrashAction>(
            icon: Icons.restore,
            label: l10n.libraryTrashRestore,
            value: _TrashAction.restore,
          ),
          ActionSheetItem<_TrashAction>(
            icon: Icons.delete_forever,
            label: l10n.libraryTrashDeletePermanently,
            value: _TrashAction.deletePermanently,
            isDestructive: true,
          ),
        ],
      ),
    );
    if (action != null && context.mounted) {
      await _handleAction(context, ref, item, action);
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
    _TrashAction action, {
    String? newName,
    String? newParentPath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);

    if (action == _TrashAction.restore &&
        newName == null &&
        newParentPath == null) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.libraryTrashRestore,
        message: l10n.libraryTrashRestoreConfirmMessage(p.basename(item.path)),
        confirmLabel: l10n.libraryTrashRestore,
        cancelLabel: l10n.commonCancel,
      );
      if (!confirmed || !context.mounted) return;
    } else if (action == _TrashAction.deletePermanently) {
      final repository = await ref.read(mediaRepositoryProvider.future);
      final itemsResult = await repository.getTrashedItems(item.path);
      final collectionsResult = await repository.getTrashedCollections(
        item.path,
      );
      if (!context.mounted) return;
      final totalCount =
          (itemsResult.dataOrNull?.length ?? 0) +
          (collectionsResult.dataOrNull?.length ?? 0);
      final targetName = p.basename(item.path);
      final confirmMessage = [
        l10n.libraryTrashDeleteConfirmWithCount(totalCount),
        '',
        targetName,
      ].join('\n');
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.libraryTrashDeletePermanently,
        message: confirmMessage,
        confirmLabel: l10n.libraryTrashDeletePermanently,
        cancelLabel: l10n.commonCancel,
        isDestructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    final viewModel = ref.read(trashViewModelProvider.notifier);
    final result = action == _TrashAction.restore
        ? await viewModel.restoreItem(
            item,
            newName: newName,
            newParentPath: newParentPath,
          )
        : await viewModel.permanentlyDeleteItem(item);

    if (!context.mounted) return;

    if (result.isFailure) {
      final hasConflict =
          result.errorOrNull?.additionalData?.containsKey('conflictingPaths') ==
          true;
      if (hasConflict) {
        final rawConflicts =
            result.errorOrNull?.additionalData?['conflictingPaths'];
        final conflictingPaths = rawConflicts is List
            ? rawConflicts.whereType<String>().toList(growable: false)
            : const <String>[];
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceBetween,
            title: Text(l10n.libraryTrashRestoreConflict),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.libraryTrashRestoreConflictPaths),
                AppSpacing.gapVerticalSm,
                for (final path in conflictingPaths.take(5)) Text('• $path'),
              ],
            ),
            actions: [
              DialogCloseButton(
                onPressed: () => Navigator.pop(dialogContext),
                semanticLabel: l10n.libraryTrashRestoreCancel,
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final resultName = await showInputDialog(
                    context,
                    title: l10n.libraryTrashRestoreWithNewName,
                    initialText: p.basename(item.path),
                    hintText: l10n.commonRenameHint,
                  );
                  if (resultName != null &&
                      resultName.trim().isNotEmpty &&
                      resultName.trim() != p.basename(item.path) &&
                      context.mounted) {
                    _handleAction(
                      context,
                      ref,
                      item,
                      action,
                      newName: resultName.trim(),
                    );
                  }
                },
                child: Text(l10n.libraryTrashRestoreWithNewName),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final resultParentPath = await showFolderPickerDialog(
                    context,
                    title: l10n.libraryTrashRestoreToAnotherLocation,
                  );
                  if (resultParentPath != null && context.mounted) {
                    _handleAction(
                      context,
                      ref,
                      item,
                      action,
                      newParentPath: resultParentPath,
                    );
                  }
                },
                child: Text(l10n.libraryTrashRestoreToAnotherLocation),
              ),
            ],
          ),
        );
      } else {
        final error = result.errorOrNull;
        snackBar.error(
          context: context,
          message: error == null
              ? l10n.commonErrorOccurred
              : userSafeErrorMessage(error, l10n),
        );
      }
    }
  }

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final trashState = ref.read(trashViewModelProvider);
    final count = trashState.items.value?.length ?? 0;

    final confirmed = await showConfirmDialog(
      context,
      title: l10n.libraryTrashEmptyAction,
      message: l10n.libraryTrashEmptyConfirmWithCountAll(count),
      confirmLabel: l10n.libraryTrashEmptyAction,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final viewModel = ref.read(trashViewModelProvider.notifier);
    final result = await viewModel.emptyTrash();
    if (!context.mounted) return;

    final error = result.errorOrNull;
    final deleted = error?.additionalData?['deletedCount'] as int?;
    final total = error?.additionalData?['totalCount'] as int?;
    final failedItems = _extractFailedItems(
      error?.additionalData?['failedItems'],
    );
    final message = result.isSuccess
        ? l10n.libraryTrashEmptySuccess(result.dataOrNull ?? 0)
        : deleted != null && total != null
        ? l10n.libraryTrashEmptyPartial(deleted, total)
        : l10n.commonErrorOccurred;

    if (result.isFailure && failedItems.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          actionsAlignment: MainAxisAlignment.spaceBetween,
          title: Text(l10n.libraryTrashEmptyPartialDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              AppSpacing.gapVerticalMd,
              Text(l10n.libraryTrashEmptyPartialFailedItems),
              AppSpacing.gapVerticalSm,
              for (final item in failedItems.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('• ${item.displayName}'),
                ),
              if (failedItems.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.commonFailedItemsOthers(failedItems.length - 5),
                  ),
                ),
            ],
          ),
          actions: [
            DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext),
              semanticLabel: l10n.commonClose,
            ),
          ],
        ),
      );
    } else {
      if (result.isSuccess) {
        snackBar.success(context: context, message: message);
      } else {
        snackBar.warning(context: context, message: message);
      }
    }
  }

  List<_FailedTrashItem> _extractFailedItems(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => _FailedTrashItem(
            path: item['path'] as String? ?? '',
            displayName: item['displayName'] as String? ?? '',
            type: item['type'] as String? ?? '',
          ),
        )
        .where((item) => item.displayName.isNotEmpty)
        .toList(growable: false);
  }
}

enum _TrashAction { restore, deletePermanently }

class _FailedTrashItem {
  const _FailedTrashItem({
    required this.path,
    required this.displayName,
    required this.type,
  });

  final String path;
  final String displayName;
  final String type;
}
