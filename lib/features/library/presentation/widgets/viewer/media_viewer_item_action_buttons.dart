import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/helpers/media_viewer_action_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_top_overlay.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

/// 閲覧画面のファイル操作（リスト・情報・サムネイル・お気に入り・その他）。
class MediaViewerItemActionButtons extends ConsumerWidget {
  final MediaItem item;
  final ViewerSourceContext? sourceContext;
  final VoidCallback onBackToCatalogContents;
  final bool expanded;

  const MediaViewerItemActionButtons({
    super.key,
    required this.item,
    required this.sourceContext,
    required this.onBackToCatalogContents,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItem = ref.watch(mediaItemProvider(item.id));
    final currentItemDetail =
        asyncItem.asData?.value ?? asyncItem.value ?? item;
    final linkedCollection = currentItemDetail.collection.value;
    final directCollection = ref
        .watch(collectionNotifierProvider(item.path))
        .asData
        ?.value;
    final latestCollection =
        MediaViewerActionHelper.resolveWorkCollectionForItem(
          item,
          linkedCollection: linkedCollection,
          directCollection: directCollection,
        );
    final isFav = latestCollection?.isFavorite ?? false;

    return Row(
      mainAxisAlignment: expanded
          ? MainAxisAlignment.spaceEvenly
          : MainAxisAlignment.start,
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (sourceContext?.kind == ViewerSourceKind.catalog)
          IconButton(
            key: const ValueKey('viewer-back-to-catalog-contents'),
            icon: const Icon(Icons.view_list),
            tooltip: l10n.viewerBackToCatalogContents,
            onPressed: onBackToCatalogContents,
          ),
        IconButton(
          key: const ValueKey('viewer-file-info'),
          icon: const Icon(Icons.info_outline),
          tooltip: l10n.viewerShowInfo,
          onPressed: () => showAppBottomSheet(
            context,
            title: l10n.viewerShowInfo,
            child: MediaViewerTopOverlay(item: currentItemDetail),
          ),
        ),
        if (item.isVideo)
          IconButton(
            icon: const Icon(Icons.center_focus_weak),
            tooltip: l10n.viewerSetThumbnail,
            onPressed: () => MediaViewerActionHelper.showThumbnailOptions(
              context,
              ref,
              item,
            ),
          ),
        if (latestCollection != null)
          IconButton(
            tooltip: isFav
                ? l10n.settingsCollectionUnfavorite
                : l10n.settingsCollectionFavorite,
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Theme.of(context).colorScheme.error : null,
            ),
            onPressed: () async {
              await ref
                  .read(mediaViewerViewModelProvider.notifier)
                  .toggleFavorite(latestCollection, item);
            },
          ),
        IconButton(
          tooltip: l10n.libraryMoreActions,
          icon: const Icon(Icons.more_vert),
          onPressed: () => MediaViewerActionHelper.showViewerActions(
            context,
            ref,
            currentItemDetail,
          ),
        ),
      ],
    );
  }
}
