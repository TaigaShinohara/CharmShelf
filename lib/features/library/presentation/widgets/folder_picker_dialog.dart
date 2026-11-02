import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/create_folder_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

/// フォルダ移動・複製先を選択するためのピッカーダイアログ
class FolderPickerDialog extends ConsumerStatefulWidget {
  final String title;

  /// 移動対象アイテムの相対パス一覧（循環移動・自己選択を防止するため）
  final Set<String> movingItemPaths;

  /// 移動元の現在の親フォルダパス（ルートなら null または空文字）
  final String? currentParentPath;

  const FolderPickerDialog({
    super.key,
    required this.title,
    this.movingItemPaths = const {},
    this.currentParentPath,
  });

  @override
  ConsumerState<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends ConsumerState<FolderPickerDialog> {
  bool _isCreatingFolder = false;

  /// 新規フォルダ作成の処理
  Future<void> _handleCreateFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() {
      _isCreatingFolder = true;
    });

    try {
      final vm = ref.read(libraryViewModelProvider.notifier);
      await vm.createFolder(name.trim());
      if (mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.libraryCreateFolderSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.e(LogTag.ui, 'ピッカー内でのフォルダ作成に失敗: $name', e, st);
      if (mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingFolder = false;
        });
      }
    }
  }

  /// パスが移動元の親フォルダ（現在地）であるかを判定
  bool _isCurrentParent(String targetPath) {
    final normalizedTarget = targetPath.isEmpty ? '' : p.normalize(targetPath);
    final normalizedCurrentParent =
        (widget.currentParentPath == null || widget.currentParentPath!.isEmpty)
        ? ''
        : p.normalize(widget.currentParentPath!);

    return widget.movingItemPaths.isNotEmpty &&
        normalizedTarget == normalizedCurrentParent;
  }

  /// パスが移動対象自身または配下の子孫フォルダであるかを判定
  bool _isMovingSelfOrDescendant(String targetPath) {
    final normalizedTarget = targetPath.isEmpty ? '' : p.normalize(targetPath);

    for (final movingPath in widget.movingItemPaths) {
      final normalizedMoving = p.normalize(movingPath);
      if (normalizedTarget == normalizedMoving) {
        return true;
      }
      if (p.isWithin(normalizedMoving, normalizedTarget)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allItemsAsync = ref.watch(libraryViewModelProvider);

    return AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceBetween,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LibraryActionIcons.move,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.libraryMoveTargetDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(48, 48),
            ),
            icon: _isCreatingFolder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.create_new_folder_outlined, size: 18),
            tooltip: l10n.commonFolder,
            onPressed: _isCreatingFolder ? null : () => _handleCreateFolder(),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: allItemsAsync.when(
            data: (items) {
              final folders =
                  items.where((i) => i.type == MediaType.folder).toList()
                    ..sort((a, b) => a.path.compareTo(b.path));

              // 各フォルダ内のアイテム数を算出
              int getDirectChildrenCount(String? parentPath) {
                final normalizedParent =
                    (parentPath == null || parentPath.isEmpty)
                    ? ''
                    : p.normalize(parentPath);
                return items.where((i) {
                  final itemParent =
                      (i.parentPath == null || i.parentPath!.isEmpty)
                      ? ''
                      : p.normalize(i.parentPath!);
                  return itemParent == normalizedParent;
                }).length;
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: folders.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // ルートフォルダ (library/)
                    final isCurrent = _isCurrentParent('');
                    final isSelf = _isMovingSelfOrDescendant('');
                    final isDisabled = isCurrent || isSelf;
                    final rootCount = getDirectChildrenCount('');

                    return _buildFolderTile(
                      context: context,
                      theme: theme,
                      l10n: l10n,
                      icon: Icons.home_outlined,
                      title: l10n.libraryRoot,
                      subtitle: 'library/',
                      itemCount: rootCount,
                      isDisabled: isDisabled,
                      isCurrentParent: isCurrent,
                      isMovingSelf: isSelf,
                      onTap: isDisabled
                          ? null
                          : () => Navigator.pop(context, ''),
                    );
                  }

                  final folder = folders[index - 1];
                  final isCurrent = _isCurrentParent(folder.path);
                  final isSelf = _isMovingSelfOrDescendant(folder.path);
                  final isDisabled = isCurrent || isSelf;
                  final folderCount = getDirectChildrenCount(folder.path);

                  return _buildFolderTile(
                    context: context,
                    theme: theme,
                    l10n: l10n,
                    icon: Icons.folder_outlined,
                    title: p.basename(folder.path),
                    subtitle: folder.path,
                    itemCount: folderCount,
                    isDisabled: isDisabled,
                    isCurrentParent: isCurrent,
                    isMovingSelf: isSelf,
                    onTap: isDisabled
                        ? null
                        : () => Navigator.pop(context, folder.path),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(userSafeErrorMessage(err, l10n))),
            ),
          ),
        ),
      ),
      actions: [
        DialogCloseButton(
          onPressed: () => Navigator.pop(context),
          semanticLabel: l10n.commonCancel,
        ),
      ],
    );
  }

  Widget _buildFolderTile({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required IconData icon,
    required String title,
    required String subtitle,
    required int itemCount,
    required bool isDisabled,
    required bool isCurrentParent,
    required bool isMovingSelf,
    required VoidCallback? onTap,
  }) {
    final titleColor = isDisabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.onSurface;

    final subtitleColor = isDisabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : theme.colorScheme.onSurfaceVariant;

    final iconColor = isDisabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : theme.colorScheme.primary;

    final iconBgColor = isDisabled
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.5);

    final tileBgColor = isDisabled
        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    final borderColor = isDisabled
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: tileBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${l10n.libraryItemCount(itemCount)})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDisabled
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    )
                                  : theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          fontSize: 11,
                          height: 1.2,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentParent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.libraryMoveCurrentLocationBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (isMovingSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      l10n.libraryMoveSourceBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// フォルダ選択ピッカーダイアログを表示するヘルパー関数
Future<String?> showFolderPickerDialog(
  BuildContext context, {
  required String title,
  Set<String>? movingItemPaths,
  String? movingItemPath,
  bool isFolder = false,
  String? currentParentPath,
}) {
  final paths = <String>{};
  if (movingItemPaths != null) {
    paths.addAll(movingItemPaths);
  }
  if (movingItemPath != null) {
    paths.add(movingItemPath);
  }

  return showDialog<String>(
    context: context,
    builder: (context) => FolderPickerDialog(
      title: title,
      movingItemPaths: paths,
      currentParentPath: currentParentPath,
    ),
  );
}
