import 'package:flutter/material.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/helpers/catalog_navigation_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_item_card.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

class MediaGrid extends ConsumerWidget {
  const MediaGrid({super.key, this.items, this.appMode, this.header});

  final List<MediaItem>? items;
  final AppMode? appMode;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const minScrollbarThickness = 4.0;
    const maxScrollbarThickness = 10.0;
    const minScrollbarThumbLength = 48.0;
    final rawScrollbarThickness = MediaQuery.sizeOf(context).width * 0.012;
    final scrollbarThickness = rawScrollbarThickness
        .clamp(minScrollbarThickness, maxScrollbarThickness)
        .toDouble();

    final mode = (appMode ?? ref.watch(appModeProvider))!;
    final isSimpleDisplay = ref.watch(globalSimpleDisplayProvider);
    final parentPathKey = ref.watch(
      mediaFilterNotifierProvider(mode).select((f) => f.parentPath ?? 'root'),
    );

    final asyncItems = items == null
        ? ref.watch(libraryViewModelProvider)
        : AsyncValue.data(items!);

    return asyncItems.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.libraryEmptyMessage),
          );
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final crossAxisCount = _calculateCrossAxisCount(
          screenWidth,
          isSimpleDisplay,
        );

        final filter = ref.watch(mediaFilterNotifierProvider(mode));
        List<MediaItem>? folders;
        List<MediaItem>? files;

        if (!filter.onlyCatalogs) {
          final folderList = <MediaItem>[];
          final fileList = <MediaItem>[];
          for (final item in items) {
            if (item.type == MediaType.folder) {
              folderList.add(item);
            } else {
              fileList.add(item);
            }
          }
          if (folderList.isNotEmpty && fileList.isNotEmpty) {
            folders = folderList;
            files = fileList;
          }
        }

        final hasSections = folders != null && files != null;

        if (!hasSections) {
          return RawScrollbar(
            thumbVisibility: true,
            interactive: true,
            thickness: scrollbarThickness,
            minThumbLength: minScrollbarThumbLength,
            child: ListView.builder(
              key: PageStorageKey('media_grid_${mode.name}_$parentPathKey'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(3, 12, 3, 96),
              itemCount:
                  _rowCount(items.length, crossAxisCount) +
                  (header == null ? 0 : 1),
              itemBuilder: (context, rowIndex) {
                if (header != null && rowIndex == 0) return header!;
                final contentRowIndex = rowIndex - (header == null ? 0 : 1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _MediaGridRow(
                    items: items,
                    rowIndex: contentRowIndex,
                    crossAxisCount: crossAxisCount,
                    contextItems: items,
                    mode: mode,
                  ),
                );
              },
            ),
          );
        }

        final nonNullFolders = folders;
        final nonNullFiles = files;
        final l10n = AppLocalizations.of(context)!;

        return RawScrollbar(
          thumbVisibility: true,
          interactive: true,
          thickness: scrollbarThickness,
          minThumbLength: minScrollbarThumbLength,
          child: CustomScrollView(
            key: PageStorageKey(
              'media_grid_sections_${mode.name}_$parentPathKey',
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.folder_outlined,
                  title: l10n.librarySectionFolders(nonNullFolders.length),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rowIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _MediaGridRow(
                          items: nonNullFolders,
                          rowIndex: rowIndex,
                          crossAxisCount: crossAxisCount,
                          contextItems: items,
                          mode: mode,
                        ),
                      );
                    },
                    childCount: _rowCount(
                      nonNullFolders.length,
                      crossAxisCount,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _SectionHeader(
                    icon: Icons.insert_drive_file_outlined,
                    title: l10n.librarySectionFiles(nonNullFiles.length),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rowIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _MediaGridRow(
                          items: nonNullFiles,
                          rowIndex: rowIndex,
                          crossAxisCount: crossAxisCount,
                          contextItems: items,
                          mode: mode,
                        ),
                      );
                    },
                    childCount: _rowCount(nonNullFiles.length, crossAxisCount),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      error: (err, stack) => Center(
        child: Text(userSafeErrorMessage(err, AppLocalizations.of(context)!)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

int _rowCount(int itemCount, int crossAxisCount) =>
    (itemCount + crossAxisCount - 1) ~/ crossAxisCount;

class _MediaGridRow extends StatelessWidget {
  const _MediaGridRow({
    required this.items,
    required this.rowIndex,
    required this.crossAxisCount,
    required this.contextItems,
    required this.mode,
  });

  final List<MediaItem> items;
  final int rowIndex;
  final int crossAxisCount;
  final List<MediaItem> contextItems;
  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var columnIndex = 0;
          columnIndex < crossAxisCount;
          columnIndex++
        ) ...[
          if (columnIndex > 0) const SizedBox(width: 3),
          Expanded(child: _buildCell(columnIndex)),
        ],
      ],
    );
  }

  Widget _buildCell(int columnIndex) {
    final itemIndex = rowIndex * crossAxisCount + columnIndex;
    if (itemIndex >= items.length) return const SizedBox.shrink();
    final item = items[itemIndex];
    return _SelectableMediaGridTile(
      key: ValueKey(item.id),
      item: item,
      contextItems: contextItems,
      mode: mode,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableMediaGridTile extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem>? contextItems;
  final AppMode mode;

  const _SelectableMediaGridTile({
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

    return MediaItemCard(
      item: item,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onTap: () async {
        if (isSelectionMode) {
          ref
              .read(librarySelectionNotifierProvider.notifier)
              .toggleSelection(item.id);
        } else if (item.type == MediaType.folder) {
          final collection = item.collection.value;
          final isFolderCatalog =
              collection != null &&
              collection.path == item.path &&
              collection.isCatalog;
          if (isFolderCatalog && !collection.isExternal) {
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
      },
      onLongPress: () {
        if (isInternal) {
          ref
              .read(librarySelectionNotifierProvider.notifier)
              .toggleSelection(item.id);
        } else {
          final effectiveCollection = item.collection.value;
          final representsCollection =
              effectiveCollection != null &&
              effectiveCollection.path == item.path &&
              effectiveCollection.isCatalog;
          showAppBottomSheet(
            context,
            showCloseButton: true,
            child: representsCollection
                ? CollectionActionSheet(
                    collectionPath: item.path,
                    initialTitle: effectiveCollection.title,
                    item: item,
                  )
                : FileActionSheet(item: item),
          );
        }
      },
    );
  }
}

/// 画面幅と表示モードに応じて最適なグリッド列数を算出する
int _calculateCrossAxisCount(double width, bool isSimple) {
  if (isSimple) {
    if (width >= 1200) return 8;
    if (width >= 900) return 6;
    if (width >= 600) return 5;
    return 3;
  } else {
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 600) return 4;
    return 2;
  }
}
