import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/services/clipboard_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_danger_section.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_header.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_quick_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_tile.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/controllers/library_action_sheet_controller.dart';
import 'package:private_shelf/features/library/presentation/widgets/dialogs/media_notes_editor_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';

/// カタログ/コレクション用のアクションシート
class CollectionActionSheet extends ConsumerWidget {
  final String collectionPath;
  final String? initialTitle;
  final MediaItem? item;
  final bool showSelectAction;
  final bool showOpenContentsAction;

  const CollectionActionSheet({
    super.key,
    required this.collectionPath,
    this.initialTitle,
    this.item,
    this.showSelectAction = true,
    this.showOpenContentsAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = LibraryActionSheetController(ref);

    final collectionState = ref.watch(
      collectionNotifierProvider(collectionPath),
    );

    return collectionState.when(
      data: (collection) {
        if (collection == null || collection.isCatalog != true) {
          return _buildCatalogifyPrompt(context, ref, controller, l10n);
        }

        final isExternal = collection.type == CollectionType.externalFolder;
        final title = collection.title.isNotEmpty
            ? collection.title
            : (initialTitle ?? p.basename(collectionPath));

        // 1. クイックアクションバー
        final quickActions = <QuickBarAction>[
          // お気に入り
          QuickBarAction(
            icon: collection.isFavorite
                ? Icons.favorite
                : Icons.favorite_border,
            label: collection.isFavorite
                ? l10n.settingsCollectionUnfavorite
                : l10n.settingsCollectionFavorite,
            isActive: collection.isFavorite,
            activeColor: Theme.of(context).colorScheme.error,
            onTap: () => controller.toggleFavorite(context, collectionPath),
          ),
          // タグ
          QuickBarAction(
            iconWidget: const CharmIcon.add(),
            label: l10n.settingsCollectionTag,
            onTap: () => controller.showTagDialog(context, collection),
          ),
          // ピン留め
          QuickBarAction(
            icon: collection.isPinned
                ? Icons.push_pin
                : Icons.push_pin_outlined,
            label: l10n.libraryPinHome,
            isActive: collection.isPinned,
            activeColor: Theme.of(context).colorScheme.primary,
            onTap: () => controller.togglePin(context, collectionPath),
          ),
          // 共有
          QuickBarAction(
            icon: Icons.share_outlined,
            label: l10n.commonShare,
            onTap: () {
              final box = context.findRenderObject() as RenderBox?;
              controller.shareCollection(
                context,
                collectionPath,
                item,
                sharePositionOrigin: box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null,
              );
            },
          ),
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. ヘッダー
            ActionSheetHeader(
              item: item,
              collectionPath: collectionPath,
              collection: collection,
              tags: collection.tags.isLoaded ? collection.tags.toList() : null,
              title: title,
              showOpenContentsAction: showOpenContentsAction,
              onOpenContents: () =>
                  controller.openCollectionContents(context, collection),
            ),

            // 2. クイックアクションバー
            ActionSheetQuickBar(actions: quickActions),

            // 編集情報は必要なときだけ開く。
            ActionSheetSection(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    key: const ValueKey('catalog-details'),
                    title: Text(l10n.librarySectionProperties),
                    maintainState: true,
                    children: [
                      ActionSheetTile(
                        icon: LibraryActionIcons.rank,
                        label: l10n.settingsCollectionTier,
                        subtitle: collection.mediaTier.localizedLabel(context),
                        onTap: () =>
                            controller.showTierDialog(context, collectionPath),
                      ),
                      ActionSheetTile(
                        icon: Icons.subtitles_outlined,
                        label: l10n.settingsCollectionAlias,
                        subtitle: collection.alias,
                        onTap: () =>
                            _showAliasDialog(context, ref, collection, l10n),
                      ),
                      ActionSheetTile(
                        icon: Icons.edit_note,
                        label: l10n.settingsCollectionNotes,
                        subtitle: collection.notes,
                        onTap: () =>
                            _showNotesDialog(context, ref, collection, l10n),
                      ),
                      ActionSheetSwitchTile(
                        icon: Icons.auto_stories_outlined,
                        label: l10n.settingsCollectionSplitSpread,
                        subtitle: l10n.settingsCollectionSplitSpreadHint,
                        value: collection.splitSpreadView,
                        onChanged: (value) async {
                          await ref
                              .read(
                                collectionNotifierProvider(
                                  collectionPath,
                                ).notifier,
                              )
                              .updateSplitSpreadView(value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 4. ファイル操作・管理セクション
            ActionSheetSection(
              title: l10n.librarySectionFileOps,
              children: [
                if (showSelectAction && item != null)
                  ActionSheetTile(
                    icon: Icons.check_circle_outline,
                    label: l10n.librarySelect,
                    onTap: () => controller.selectItem(context, item!),
                  ),
                if (!isExternal && item != null) ...[
                  ActionSheetTile(
                    icon: Icons.drive_file_rename_outline,
                    label: l10n.viewerRename,
                    onTap: () => controller.showRenameDialog(
                      context,
                      item!,
                      currentCollectionPath: collectionPath,
                    ),
                  ),
                  ActionSheetTile(
                    icon: LibraryActionIcons.move,
                    label: l10n.settingsFileMove,
                    onTap: () => controller.showMoveDialog(context, item!),
                  ),
                  ActionSheetTile(
                    icon: LibraryActionIcons.duplicate,
                    label: l10n.commonDuplicate,
                    onTap: () => controller.handleDuplicate(context, item!),
                  ),
                ],
                ActionSheetTile(
                  icon: Icons.copy_all_outlined,
                  label: l10n.libraryCopyCatalogInfo,
                  onTap: () =>
                      _showCopyOptionsDialog(context, ref, collection, l10n),
                ),
                if (!isExternal && item != null)
                  ActionSheetTile(
                    icon: LibraryActionIcons.download,
                    label: l10n.libraryDownload,
                    onTap: () => controller.downloadItem(context, item!),
                  ),
              ],
            ),

            // 5. セキュリティ & プライバシーセクション
            ActionSheetSection(
              title: l10n.librarySectionVisibilityOrganization,
              children: [
                ActionSheetSwitchTile(
                  icon: collection.isHidden
                      ? Icons.visibility_off
                      : Icons.visibility_outlined,
                  label: l10n.settingsFileActionHide,
                  value: collection.isHidden,
                  onChanged: (_) =>
                      controller.toggleHidden(context, collection: collection),
                ),
                ActionSheetSwitchTile(
                  icon: collection.isArchived
                      ? Icons.archive
                      : Icons.archive_outlined,
                  label: l10n.settingsFileActionArchive,
                  value: collection.isArchived,
                  onChanged: (_) =>
                      controller.toggleArchive(context, collection: collection),
                ),
              ],
            ),

            // 6. 危険エリアセクション
            ActionSheetDangerSection(
              actions: [
                DangerAction(
                  icon: isExternal ? Icons.link_off : null,
                  iconWidget: isExternal
                      ? null
                      : const CatalogizeIcon.release(),
                  label: isExternal
                      ? l10n.settingsFileActionRemoveReference
                      : l10n.settingsCollectionDecatalogify,
                  onTap: () => controller.decatalogify(context, collection),
                ),
                if (item != null && !isExternal)
                  DangerAction(
                    icon: Icons.delete_outline,
                    label: l10n.settingsFileDeleteConfirmTitle,
                    onTap: () => controller.deleteItem(context, item!),
                  ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(userSafeErrorMessage(e, l10n)),
        ),
      ),
    );
  }

  Widget _buildCatalogifyPrompt(
    BuildContext context,
    WidgetRef ref,
    LibraryActionSheetController controller,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final targetItem = item ?? (MediaItem()..path = collectionPath);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionSheetHeader(
          item: item,
          collectionPath: collectionPath,
          title: initialTitle ?? p.basename(collectionPath),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppMenuActionFeedback(
                iconWidget: CatalogizeIcon.outlined(
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                iconSize: 18,
                onPressed: () => controller.catalogify(context, targetItem),
                builder: (context, animatedIcon, onPressed) =>
                    FilledButton.icon(
                      key: const ValueKey('catalogify-button'),
                      icon: animatedIcon,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.settingsCollectionCatalogify,
                          maxLines: 1,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onPressed,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                key: const ValueKey('catalogify-hint'),
                l10n.settingsCollectionCatalogifyHint,
                softWrap: true,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showNotesDialog(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => MediaNotesEditorDialog(
        initialNotes: collection.notes,
        onSave: (notes) => ref
            .read(collectionNotifierProvider(collectionPath).notifier)
            .updateNotes(notes),
      ),
    );

    if (result != null && context.mounted) {
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commonUpdate),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showAliasDialog(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CollectionAliasDialog(
        initialAlias: collection.alias,
        originalTitle: collection.title,
      ),
    );

    if (result != null && context.mounted) {
      try {
        await ref
            .read(collectionNotifierProvider(collectionPath).notifier)
            .updateAlias(result.isEmpty ? null : result);
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.commonUpdate),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userSafeErrorMessage(e, l10n))),
          );
        }
      }
    }
  }

  Future<void> _showCopyOptionsDialog(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
    AppLocalizations l10n,
  ) async {
    final result = await showActionBottomSheet<String>(
      context,
      items: [
        ActionSheetItem(
          label: l10n.libraryCopyCatalogInfo,
          icon: Icons.info_outline,
          value: 'catalogInfo',
        ),
        ActionSheetItem(
          label: l10n.settingsCollectionTitle,
          icon: Icons.title,
          value: 'title',
        ),
        ActionSheetItem(
          label: l10n.settingsFilePath,
          icon: Icons.folder_outlined,
          value: 'path',
        ),
        if (collection.alias != null)
          ActionSheetItem(
            label: l10n.settingsCollectionAlias,
            icon: Icons.drive_file_rename_outline,
            value: 'alias',
          ),
      ],
    );

    if (result == null || !context.mounted) return;

    final clipboardService = ref.read(clipboardServiceProvider);
    Result<void, Object>? copyResult;

    switch (result) {
      case 'catalogInfo':
        final tags = collection.tags.isLoaded
            ? collection.tags.map((tag) => tag.name).join(', ')
            : '';
        final preview = [
          '${l10n.settingsCollectionTitle}: ${collection.title}',
          if (collection.alias?.isNotEmpty == true)
            '${l10n.settingsCollectionAlias}: ${collection.alias}',
          '${l10n.settingsFilePath}: ${collection.path}',
          '${l10n.libraryCatalogType}: ${collection.displayTypeLabel(context)}',
          if (tags.isNotEmpty) '${l10n.settingsCollectionTag}: $tags',
          if (collection.notes?.isNotEmpty == true)
            '${l10n.settingsCollectionNotes}: ${collection.notes}',
          '${l10n.settingsCollectionFavorite}: ${collection.isFavorite ? l10n.commonYes : l10n.commonNo}',
          '${l10n.settingsCollectionTier}: ${collection.mediaTier.localizedLabel(context)}',
        ].join('\n');
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.libraryCopyCatalogInfo),
            content: SingleChildScrollView(child: SelectableText(preview)),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.commonCopy),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          copyResult = await clipboardService.copyText(preview);
        }
        break;
      case 'title':
        copyResult = await clipboardService.copyText(collection.title);
        break;
      case 'path':
        copyResult = await clipboardService.copyText(collection.path);
        break;
      case 'alias':
        if (collection.alias != null) {
          copyResult = await clipboardService.copyText(collection.alias!);
        }
        break;
    }
    if (context.mounted && copyResult != null) {
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copyResult.isSuccess ? l10n.clipboardCopied : l10n.clipboardFailed,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _CollectionAliasDialog extends StatefulWidget {
  final String? initialAlias;
  final String originalTitle;

  const _CollectionAliasDialog({
    this.initialAlias,
    required this.originalTitle,
  });

  @override
  State<_CollectionAliasDialog> createState() => _CollectionAliasDialogState();
}

class _CollectionAliasDialogState extends State<_CollectionAliasDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAlias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.settingsCollectionAlias),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsCollectionAliasDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.settingsCollectionOriginalName}: ${widget.originalTitle}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.settingsCollectionAliasHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: l10n.commonCancel,
          ),
          trailing: ElevatedButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}
