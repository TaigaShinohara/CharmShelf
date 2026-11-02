import 'package:flutter/material.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';

class ActiveConditionChips extends ConsumerWidget {
  const ActiveConditionChips({
    super.key,
    required this.mode,
    required this.filter,
    required this.sortOrderLabel,
    this.onClearAll,
    this.showSearchQuery = true,
  });

  final AppMode mode;
  final MediaFilter filter;
  final String sortOrderLabel;
  final VoidCallback? onClearAll;
  final bool showSearchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mediaFilterNotifierProvider(mode).notifier);
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[];

    final searchQuery = filter.searchQuery?.trim();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchTarget = filter.effectiveSearchTarget;
      if (showSearchQuery) {
        chips.add(
          InputChip(
            avatar: const Icon(Icons.search, size: 18),
            label: Text(l10n.libraryActiveSearchQuery(searchQuery)),
            onDeleted: () => notifier.updateSearchQuery(''),
          ),
        );
      }
      if (searchTarget == SearchTarget.catalogsOnly) {
        chips.add(
          InputChip(
            avatar: const CatalogizeIcon(size: 18),
            label: Text(l10n.librarySearchCatalogsOnly),
            onDeleted: () =>
                notifier.updateSearchTarget(SearchTarget.filesIncluded),
          ),
        );
      }
    }

    if (filter.onlyCatalogs && (searchQuery == null || searchQuery.isEmpty)) {
      chips.add(
        InputChip(
          avatar: const CatalogizeIcon(size: 18),
          label: Text(l10n.libraryCatalogDisplayTitle),
          onDeleted: () => notifier.updateOnlyCatalogs(false),
        ),
      );
    }

    if (filter.sortOrder != SortOrder.addedDesc) {
      chips.add(
        InputChip(
          avatar: const Icon(LibraryActionIcons.sort, size: 18),
          label: Text(sortOrderLabel),
          onDeleted: () => notifier.updateSortOrder(SortOrder.addedDesc),
        ),
      );
    }

    final tiers = filter.tiers ?? const <int>[];
    if (tiers.isNotEmpty) {
      final labels = tiers
          .map(MediaTier.fromInt)
          .map((tier) => tier.localizedLabel(context))
          .join(', ');
      chips.add(
        InputChip(
          avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: Text(l10n.libraryActiveTiers(labels)),
          onDeleted: () => notifier.updateTiers(null),
        ),
      );
    }

    if (filter.isFavorite == true) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.favorite_outline, size: 18),
          label: Text(l10n.libraryFilterFavoriteOnly),
          onDeleted: () => notifier.updateIsFavorite(null),
        ),
      );
    }

    final mediaTypes = filter.mediaTypes ?? const <MediaType>[];
    if (mediaTypes.isNotEmpty) {
      final labels = mediaTypes
          .map(
            (type) =>
                type == MediaType.folder ? l10n.commonFolder : l10n.commonFile,
          )
          .join(', ');
      chips.add(
        InputChip(
          avatar: const Icon(Icons.category_outlined, size: 18),
          label: Text(l10n.libraryActiveMediaTypes(labels)),
          onDeleted: () => notifier.updateMediaTypes(null),
        ),
      );
    }

    if (filter.hasTags != null) {
      chips.add(
        InputChip(
          avatar: const CharmIcon(size: 18),
          label: Text(
            filter.hasTags!
                ? l10n.libraryFilterHasTags
                : l10n.libraryFilterNoTags,
          ),
          onDeleted: () => notifier.updateHasTags(null),
        ),
      );
    }

    final tagIds = filter.tagIds ?? const <int>[];
    if (tagIds.isNotEmpty) {
      final tags = ref.watch(visibleTagListProvider).value ?? const [];
      final facets =
          ref.watch(tagFacetListViewModelProvider).value ?? const [];
      final tagById = {for (final tag in tags) tag.id: tag};
      final facetById = {for (final facet in facets) facet.id: facet};

      for (final tagId in tagIds) {
        final tag = tagById[tagId];

        void removeTag() {
          final next = List<int>.from(tagIds)..remove(tagId);
          notifier.updateTagIds(next.isEmpty ? null : next);
        }

        chips.add(
          AppTag(
            label: tag?.name ?? '#$tagId',
            color: tag != null
                ? tag.getEffectiveColor(context, facetById[tag.facetId])
                : Theme.of(context).colorScheme.secondaryContainer,
            size: AppTagSize.large,
            isSelected: true,
            isDimmed: tag?.isHidden ?? false,
            actionType: AppTagActionType.minus,
            onAction: removeTag,
            onTap: removeTag,
          ),
        );
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: AppTagWrap(spacing: 8, runSpacing: 8, children: chips),
          ),
          Tooltip(
            message: l10n.libraryClearAllConditions,
            child: TextButton.icon(
              onPressed: onClearAll ?? notifier.clearDiscoveryConditions,
              icon: const Icon(LibraryActionIcons.filterClear, size: 18),
              label: Text(l10n.libraryClearAllConditions),
            ),
          ),
        ],
      ),
    );
  }
}
