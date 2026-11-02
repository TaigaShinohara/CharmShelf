import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/helpers/catalog_navigation_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tree_view_state_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/shared/widgets/catalog_tile.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

/// スムーズなアニメーション展開とネストされたグループ背景・接続線を持つ階層ツリーノード
class TreeFolderNode extends ConsumerWidget {
  final MediaItem item;
  final int depth;
  final bool isLastChild;
  final bool showChildren;

  const TreeFolderNode({
    super.key,
    required this.item,
    this.depth = 0,
    this.isLastChild = false,
    this.showChildren = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final isInternal = mode == AppMode.internal;
    final isFolder = item.type == MediaType.folder;

    final isSelected = isInternal
        ? ref.watch(
            librarySelectionNotifierProvider.select(
              (s) => s.isSelected(item.id),
            ),
          )
        : false;
    final isSelectionMode = isInternal
        ? ref.watch(
            librarySelectionNotifierProvider.select((s) => s.isSelectionMode),
          )
        : false;
    final isSimpleDisplay = ref.watch(globalSimpleDisplayProvider);

    final isExpanded = isFolder
        ? ref.watch(
            expandedFoldersNotifierProvider.select(
              (set) => set.contains(item.path),
            ),
          )
        : false;

    final collection = item.collection.value;
    final representsCollection =
        collection != null &&
        collection.path == item.path &&
        collection.isCatalog;

    void toggleSelection() {
      ref
          .read(librarySelectionNotifierProvider.notifier)
          .toggleSelection(item.id);
    }

    Future<void> handleTap() async {
      if (isSelectionMode) {
        toggleSelection();
      } else if (item.type == MediaType.folder) {
        if (representsCollection) {
          await openFolderCatalogViewer(
            context: context,
            ref: ref,
            folder: item,
            collection: collection,
            mode: mode,
          );
        } else {
          ref
              .read(mediaFilterNotifierProvider(mode).notifier)
              .updateParentPath(item.path);
        }
      } else if (item.type == MediaType.file) {
        ref.invalidate(mediaItemProvider(item.id));
        MediaViewerRoute(
          id: item.id,
          $extra: ViewerRouteArgs(
            initialItem: item,
            sourceContext: ViewerSourceContext.folder(
              parentPath: item.parentPath,
              appMode: mode,
            ),
          ),
        ).push(context);
      }
    }

    void handleLongPress() {
      if (isInternal) {
        toggleSelection();
      } else {
        showAppBottomSheet(
          context,
          showCloseButton: true,
          child: representsCollection
              ? CollectionActionSheet(
                  collectionPath: item.path,
                  initialTitle: collection.title,
                  item: item,
                )
              : FileActionSheet(item: item),
        );
      }
    }

    void toggleExpand() {
      ref.read(expandedFoldersNotifierProvider.notifier).toggle(item.path);
    }

    final theme = Theme.of(context);
    final isDeep = depth > 0;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          left: showChildren ? 0 : depth.clamp(0, 8).toDouble() * 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 親タイル
            if (representsCollection)
              CatalogTile(
                path: item.path,
                title: p.basename(item.path),
                alias: null,
                coverImagePath:
                    collection.coverImagePath ??
                    (item.isImage ? item.path : null),
                isFavorite: false,
                tier: collection.mediaTier,
                type: item.type,
                isSelected: isSelected,
                isSelectionMode: isSelectionMode,
                item: item,
                isSimpleDisplay: isSimpleDisplay,
                showTreeLeadingSpacer: true,
                onTap: () => handleTap(),
                onLongPress: handleLongPress,
              )
            else
              Container(
                decoration: isExpanded
                    ? BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 3.0,
                          ),
                        ),
                      )
                    : null,
                child: MediaListTile(
                  item: item,
                  isSelectionMode: isSelectionMode,
                  isSelected: isSelected,
                  isSimpleDisplay: isSimpleDisplay,
                  depth: showChildren && isDeep ? 1 : 0,
                  isExpanded: isExpanded,
                  onToggleExpand: isFolder ? toggleExpand : null,
                  onTap: () => handleTap(),
                  onLongPress: handleLongPress,
                ),
              ),

            // 子階層のアニメーション展開コンテナ
            if (isFolder && showChildren)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? _buildChildrenContainer(context, ref, theme)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenContainer(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final asyncChildren = ref.watch(folderChildrenProvider(item.path));
    final l10n = AppLocalizations.of(context)!;

    return asyncChildren.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (children) {
        if (children.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 32, top: 6, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.libraryEmptyFolder,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(left: 18, top: 2, bottom: 6, right: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow.withValues(
              alpha: 0.65,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.45),
                width: 2.0,
              ),
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
              right: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
            ),
          ),

          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: children.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final child = children[index];
              final isLast = index == children.length - 1;
              return TreeFolderNode(
                key: ValueKey('tree_node_${child.id}_${depth + 1}'),
                item: child,
                depth: depth + 1,
                isLastChild: isLast,
              );
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
