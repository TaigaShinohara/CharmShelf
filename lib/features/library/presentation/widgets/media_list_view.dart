import 'package:flutter/foundation.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
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
import 'package:private_shelf/shared/widgets/catalog_tile.dart';

import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/tree_folder_node.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

class MediaListView extends ConsumerWidget {
  final List<MediaItem> items;
  final AppMode? appMode;
  final Widget? header;
  final MediaFilter? filterOverride;
  final ScrollController? controller;

  const MediaListView({
    super.key,
    required this.items,
    this.appMode,
    this.header,
    this.filterOverride,
    this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const minScrollbarThickness = 5.0;
    const maxScrollbarThickness = 10.0;
    const minScrollbarThumbLength = 48.0;
    final rawScrollbarThickness = MediaQuery.sizeOf(context).width * 0.012;
    final scrollbarThickness = rawScrollbarThickness
        .clamp(minScrollbarThickness, maxScrollbarThickness)
        .toDouble();
    final platform = Theme.of(context).platform;
    final alwaysShowScrollbar =
        kIsWeb ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;

    final mode = (appMode ?? ref.watch(appModeProvider))!;
    final filter =
        filterOverride ??
        ref.watch<MediaFilter>(mediaFilterNotifierProvider(mode));
    final parentPathKey = filter.parentPath ?? 'root';

    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.libraryNoItems));
    }

    final isTreeMode =
        mode == AppMode.internal &&
        !filter.onlyCatalogs &&
        (filter.searchQuery == null || filter.searchQuery!.isEmpty);
    final treeItems = isTreeMode
        ? ref.watch(treeMediaItemsProvider(items))
        : null;

    return RawScrollbar(
      controller: controller,
      thumbVisibility: alwaysShowScrollbar,
      interactive: true,
      thickness: scrollbarThickness,
      minThumbLength: minScrollbarThumbLength,
      child: ListView.separated(
        controller: controller,
        key: PageStorageKey('media_tree_list_${mode.name}_$parentPathKey'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount:
            (treeItems?.length ?? items.length) + (header == null ? 0 : 1),
        separatorBuilder: (context, index) => header != null && index == 0
            ? const SizedBox.shrink()
            : const Divider(height: 1, thickness: 0.5),
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header!;
          final itemIndex = index - (header == null ? 0 : 1);
          if (isTreeMode) {
            final node = treeItems![itemIndex];
            return TreeFolderNode(
              key: ValueKey('tree_${node.item.id}'),
              item: node.item,
              depth: node.depth,
              isLastChild: itemIndex == treeItems.length - 1,
              showChildren: false,
            );
          } else {
            final item = items[itemIndex];
            return _SelectableMediaListTile(
              key: ValueKey('flat_${item.id}'),
              item: item,
              contextItems: items,
              mode: mode,
            );
          }
        },
      ),
    );
  }
}

class _SelectableMediaListTile extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem>? contextItems;
  final AppMode mode;

  const _SelectableMediaListTile({
    super.key,
    required this.item,
    this.contextItems,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInternal = mode == AppMode.internal;

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
        if (representsCollection && !collection.isExternal) {
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
        final filter = ref.read(mediaFilterNotifierProvider(mode));
        final isFiltered =
            (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) ||
            (filter.tagIds != null && filter.tagIds!.isNotEmpty) ||
            filter.isFavorite == true ||
            (filter.tiers != null && filter.tiers!.isNotEmpty) ||
            filter.mediaTypes != null ||
            filter.hasTags != null;

        final sourceContext =
            (isFiltered || mode == AppMode.external) && contextItems != null
            ? ViewerSourceContext.customList(contextItems!)
            : ViewerSourceContext.folder(
                parentPath: item.parentPath,
                appMode: mode,
              );

        MediaViewerRoute(
          id: item.id,
          $extra: ViewerRouteArgs(
            initialItem: item,
            sourceContext: sourceContext,
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

    if (representsCollection) {
      return CatalogTile(
        path: item.path,
        title: p.basename(item.path),
        alias: null,
        coverImagePath:
            collection.coverImagePath ?? (item.isImage ? item.path : null),
        isFavorite: false,
        tier: collection.mediaTier,
        type: item.type,
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
        item: item,
        isSimpleDisplay: isSimpleDisplay,
        onTap: () => handleTap(),
        onLongPress: handleLongPress,
      );
    } else {
      return MediaListTile(
        item: item,
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        isSimpleDisplay: isSimpleDisplay,
        onTap: () => handleTap(),
        onLongPress: handleLongPress,
      );
    }
  }
}
