import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_danger_section.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_header.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_quick_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_tile.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/controllers/library_action_sheet_controller.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

/// ファイル/フォルダ用のアクションシート
class FileActionSheet extends ConsumerWidget {
  final MediaItem item;
  final Future<void> Function()? onSetAsFolderCover;
  final bool showSelectAction;

  const FileActionSheet({
    super.key,
    required this.item,
    this.onSetAsFolderCover,
    this.showSelectAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = LibraryActionSheetController(ref);

    // 最新のアイテム情報を取得（リアクティブ）
    final currentItem = ref.watch(
      libraryViewModelProvider.select((s) {
        return s.value?.firstWhere(
              (i) => i.id == item.id,
              orElse: () => item,
            ) ??
            item;
      }),
    );

    final collectionAsync = ref.watch(
      collectionNotifierProvider(currentItem.path),
    );
    final collection = collectionAsync.value;
    final isCatalog = collection != null && collection.isCatalog;

    final isLocal = currentItem.sourceType == MediaSourceType.localCopy;
    final canCover = _canSetAsFolderCover(currentItem);

    // 1. クイックアクションバー項目
    final quickActions = <QuickBarAction>[
      // お気に入り（カタログのアクションシートと同じ位置・表示）
      QuickBarAction(
        icon: currentItem.isFavorite ? Icons.favorite : Icons.favorite_border,
        label: currentItem.isFavorite
            ? l10n.settingsCollectionUnfavorite
            : l10n.settingsCollectionFavorite,
        isActive: currentItem.isFavorite,
        activeColor: Theme.of(context).colorScheme.error,
        onTap: () => controller.toggleItemFavorite(context, currentItem),
      ),
      // 表紙に設定
      if (canCover) ...[
        QuickBarAction(
          icon: Icons.folder_shared_outlined,
          label: l10n.librarySetAsFolderCover,
          onTap: () {
            if (onSetAsFolderCover != null) {
              onSetAsFolderCover!();
            } else {
              controller.setAsFolderCover(context, currentItem);
            }
          },
        ),
      ],
      // 共有
      QuickBarAction(
        icon: Icons.share_outlined,
        label: l10n.commonShare,
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          controller.shareItem(
            context,
            currentItem,
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
        // 1. ヘッダー（サムネイル・タイトル・親カタログ情報・インライン詳細アコーディオン）
        ActionSheetHeader(
          item: currentItem,
          collection: collection,
          tags: collection?.tags.isLoaded == true
              ? collection!.tags.toList()
              : null,
          title: p.basename(currentItem.path),
        ),

        // 2. クイックアクションバー
        if (quickActions.isNotEmpty) ActionSheetQuickBar(actions: quickActions),

        // 3. ファイル操作・管理セクション
        ActionSheetSection(
          title: l10n.librarySectionFileOps,
          children: [
            if (showSelectAction)
              ActionSheetTile(
                icon: Icons.check_circle_outline,
                label: l10n.librarySelect,
                onTap: () => controller.selectItem(context, currentItem),
              ),
            if (!isCatalog)
              ActionSheetTile(
                iconWidget: const CatalogizeIcon.outlined(size: 24),
                label: l10n.settingsCollectionCatalogify,
                subtitle: l10n.settingsCollectionCatalogifyHint,
                subtitleMaxLines: null,
                onTap: () => controller.catalogify(context, currentItem),
              ),
            if (isLocal) ...[
              ActionSheetTile(
                icon: Icons.drive_file_rename_outline,
                label: l10n.viewerRename,
                onTap: () => controller.showRenameDialog(context, currentItem),
              ),
              ActionSheetTile(
                icon: LibraryActionIcons.move,
                label: l10n.settingsFileMove,
                onTap: () => controller.showMoveDialog(context, currentItem),
              ),
              ActionSheetTile(
                icon: LibraryActionIcons.duplicate,
                label: l10n.commonDuplicate,
                onTap: () => controller.handleDuplicate(context, currentItem),
              ),
            ],
            ActionSheetTile(
              icon: Icons.copy_all_outlined,
              label: l10n.commonCopyPath,
              onTap: () => controller.copyPath(context, currentItem.path),
            ),
            ActionSheetTile(
              icon: LibraryActionIcons.download,
              label: l10n.libraryDownload,
              onTap: () => controller.downloadItem(context, currentItem),
            ),
          ],
        ),

        // 4. セキュリティ & プライバシーセクション
        ActionSheetSection(
          title: l10n.librarySectionVisibilityOrganization,
          children: [
            ActionSheetSwitchTile(
              icon: currentItem.isHidden
                  ? Icons.visibility_off
                  : Icons.visibility_outlined,
              label: l10n.settingsFileActionHide,
              value: currentItem.isHidden,
              onChanged: (_) =>
                  controller.toggleHidden(context, item: currentItem),
            ),
            ActionSheetSwitchTile(
              icon: currentItem.isArchived
                  ? Icons.archive
                  : Icons.archive_outlined,
              label: l10n.settingsFileActionArchive,
              value: currentItem.isArchived,
              onChanged: (_) =>
                  controller.toggleArchive(context, item: currentItem),
            ),
          ],
        ),

        // 5. 危険エリアセクション
        ActionSheetDangerSection(
          actions: [
            DangerAction(
              icon: Icons.delete_outline,
              label: currentItem.sourceType == MediaSourceType.externalReference
                  ? l10n.settingsFileRemoveReference
                  : l10n.settingsFileDeleteConfirmTitle,
              onTap: () => controller.deleteItem(context, currentItem),
            ),
          ],
        ),
      ],
    );
  }

  bool _canSetAsFolderCover(MediaItem item) {
    final hasParent = item.parentPath != null && item.parentPath!.isNotEmpty;
    final isTargetMedia =
        item.type == MediaType.file && (item.isImage || item.isVideo);
    return hasParent && isTargetMedia;
  }
}
