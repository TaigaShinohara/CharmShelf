import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../domain/models/media_filter.dart';

/// Conditions that can affect discovery, rather than normal browsing defaults.
class LibraryDiscoveryConditions {
  const LibraryDiscoveryConditions({
    required this.filter,
    required this.defaultHiddenFilter,
  });

  final MediaFilter filter;
  final bool? defaultHiddenFilter;

  bool get hasQuery => filter.searchQuery?.trim().isNotEmpty == true;

  bool get hasFilters =>
      filter.tagIds?.isNotEmpty == true ||
      filter.excludedTagIds?.isNotEmpty == true ||
      filter.tiers?.isNotEmpty == true ||
      filter.mediaTypes?.isNotEmpty == true ||
      filter.hasTags != null ||
      filter.isFavorite != null ||
      filter.isHidden != defaultHiddenFilter;

  bool get canSearchEntireLibrary =>
      hasQuery && filter.keepsParentWhileSearching;

  bool get canIncludeFiles => hasQuery
      ? filter.effectiveSearchTarget == SearchTarget.catalogsOnly
      : filter.onlyCatalogs;

  bool get canRelaxConditions =>
      canSearchEntireLibrary || canIncludeFiles || hasFilters;

  bool get hasConditions => hasQuery || canRelaxConditions;
}

/// Offers only recovery actions that change the current discovery conditions.
class LibraryDiscoveryEmptyState extends StatelessWidget {
  const LibraryDiscoveryEmptyState({
    super.key,
    required this.conditions,
    required this.onSearchEntireLibrary,
    required this.onIncludeFiles,
    required this.onClearFilters,
    required this.onClearSearch,
    required this.onClearAll,
  });

  final LibraryDiscoveryConditions conditions;
  final VoidCallback onSearchEntireLibrary;
  final VoidCallback onIncludeFiles;
  final VoidCallback onClearFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = <Widget>[];

    void addRecoveryAction(String key, String label, VoidCallback onPressed) {
      final child = Text(label, textAlign: TextAlign.center);
      const style = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      );
      actions.add(
        actions.isEmpty
            ? FilledButton.tonal(
                key: ValueKey(key),
                style: style,
                onPressed: onPressed,
                child: child,
              )
            : OutlinedButton(
                key: ValueKey(key),
                style: style,
                onPressed: onPressed,
                child: child,
              ),
      );
    }

    if (conditions.canSearchEntireLibrary) {
      addRecoveryAction(
        'discovery-search-entire-library',
        l10n.librarySearchEntireLibrary,
        onSearchEntireLibrary,
      );
    }
    if (conditions.canIncludeFiles) {
      addRecoveryAction(
        'discovery-include-files',
        conditions.hasQuery
            ? l10n.librarySearchIncludeFiles
            : l10n.libraryShowFilesToo,
        onIncludeFiles,
      );
    }
    if (conditions.hasFilters) {
      addRecoveryAction(
        'discovery-clear-filters',
        l10n.libraryClearFiltersKeepQuery,
        onClearFilters,
      );
    }
    if (conditions.hasQuery) {
      actions.add(
        TextButton(
          key: const ValueKey('discovery-clear-search'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: conditions.canRelaxConditions ? onClearAll : onClearSearch,
          child: Text(
            conditions.canRelaxConditions
                ? l10n.libraryClearSearchAndFilters
                : l10n.libraryClearSearch,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final guidance = conditions.hasQuery
        ? (conditions.canRelaxConditions
              ? l10n.librarySearchNoResultsRelaxGuidance
              : l10n.librarySearchNoResultsQueryGuidance)
        : l10n.librarySearchNoResultsGuidance;

    return EmptyStateWidget(
      icon: Icons.search_off_outlined,
      title: l10n.librarySearchNoResults,
      subtitle: guidance,
      iconColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: actions,
      ),
    );
  }
}
