import 'dart:async';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/utils/tab_navigator.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/screens/tag_management_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/confirm_dialog.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

class BulkTagSelectorSheet extends ConsumerStatefulWidget {
  final int selectedCount;
  final Future<void> Function(List<Tag> tags) onApply;

  const BulkTagSelectorSheet({
    super.key,
    required this.selectedCount,
    required this.onApply,
  });

  @override
  ConsumerState<BulkTagSelectorSheet> createState() =>
      _BulkTagSelectorSheetState();
}

class _BulkTagSelectorSheetState extends ConsumerState<BulkTagSelectorSheet> {
  final Set<int> _selectedTagIds = {};
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  int? _selectedFacetId;
  String _sortMode = 'name'; // 'name', 'count', 'date'
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _toggleTag(Tag tag) {
    ref.read(feedbackServiceProvider).lightImpact();
    final isRemoving = _selectedTagIds.contains(tag.id);
    setState(() {
      if (isRemoving) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
  }

  void _showSortDialog(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) async {
    final result = await showActionBottomSheet<String>(
      context,
      title: l10n.commonSortSettings,
      items: [
        ActionSheetItem(
          icon: LibraryActionIcons.sort,
          label: l10n.commonSortByName,
          value: 'name',
          selected: _sortMode == 'name',
        ),
        ActionSheetItem(
          icon: Icons.numbers,
          label: l10n.commonSortByUsageCount,
          value: 'count',
          selected: _sortMode == 'count',
        ),
        ActionSheetItem(
          icon: Icons.update,
          label: l10n.commonSortByUpdateDate,
          value: 'date',
          selected: _sortMode == 'date',
        ),
      ],
    );
    if (result != null && mounted) {
      setState(() => _sortMode = result);
    }
  }

  Future<void> _handleApply(BuildContext context, AppLocalizations l10n) async {
    if (_selectedTagIds.isEmpty || _isApplying) return;
    final navigator = Navigator.of(context);
    final messenger = AppSnackBarMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.commonConfirm,
      message: l10n.libraryBulkTagMessage(widget.selectedCount),
      confirmLabel: l10n.commonApply,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    setState(() => _isApplying = true);
    try {
      final allTags =
          ref.read(visibleTagListProvider).value ?? const <Tag>[];
      final selectedTags = allTags
          .where((tag) => _selectedTagIds.contains(tag.id))
          .toList();
      await widget.onApply(selectedTags);
      if (context.mounted) navigator.pop();
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, 'Bulk tag apply failed in sheet', error, stack);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(userSafeErrorMessage(error, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final asyncTags = ref.watch(visibleTagListProvider);
    final asyncFacets = ref.watch(tagFacetListViewModelProvider);

    return asyncFacets.when(
      data: (facets) {
        return asyncTags.when(
          data: (allTags) {
            final facetById = {for (final facet in facets) facet.id: facet};
            final orderedFacets = List<TagFacet>.from(facets)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            final query = _searchController.text.trim().toLowerCase();

            final filteredTags = allTags.where((tag) {
              if (_selectedFacetId != null && tag.facetId != _selectedFacetId) {
                return false;
              }
              if (query.isNotEmpty && !tag.name.toLowerCase().contains(query)) {
                return false;
              }
              return true;
            }).toList();

            if (_sortMode == 'date') {
              filteredTags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            } else if (_sortMode == 'count') {
              filteredTags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
            } else {
              filteredTags.sort((a, b) => a.name.compareTo(b.name));
            }

            final tagCountByFacet = <int?, int>{};
            for (final tag in allTags) {
              tagCountByFacet[tag.facetId] =
                  (tagCountByFacet[tag.facetId] ?? 0) + 1;
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: PrimaryScrollController.maybeOf(context),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: l10n.tagSearchHint,
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                    prefixIcon: CharmIcon.search(
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
                                            tooltip: l10n.commonClear,
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchChanged('');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () =>
                                  _showSortDialog(context, l10n, theme),
                              icon: const Icon(
                                LibraryActionIcons.sort,
                                size: 18,
                              ),
                              tooltip: l10n.tagSortTitle,
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                TabNavigator.push(
                                  context,
                                  const TagManagementScreen(),
                                );
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                              ),
                              tooltip: l10n.tagGoToManagement,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            l10n.libraryBulkTagMessage(widget.selectedCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FacetChip(
                                label: l10n.tagAllFacets,
                                count: allTags.length,
                                isSelected: _selectedFacetId == null,
                                showDot: false,
                                onSelected: (_) =>
                                    setState(() => _selectedFacetId = null),
                              ),
                              const SizedBox(width: 8),
                              ...orderedFacets.map((facet) {
                                final isSelected = _selectedFacetId == facet.id;
                                final count = tagCountByFacet[facet.id] ?? 0;
                                final color = facet.colorValue != null
                                    ? Color(facet.colorValue!)
                                    : theme.colorScheme.primary;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FacetChip(
                                    label: facet.name,
                                    color: color,
                                    count: count,
                                    isSelected: isSelected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedFacetId = isSelected
                                            ? null
                                            : facet.id;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTagCloud(
                          context,
                          allTags,
                          filteredTags,
                          orderedFacets,
                          facetById,
                          query,
                          l10n,
                          theme,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSelectedTagsSection(
                    context,
                    allTags,
                    facetById,
                    l10n,
                    theme,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _selectedTagIds.isEmpty || _isApplying
                            ? null
                            : () => _handleApply(context, l10n),
                        icon: _isApplying
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.done_all),
                        label: Text(
                          '${l10n.commonApply} (${l10n.tagSelectedCount(_selectedTagIds.length)})',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (e, stack) {
            AppLogger.e(LogTag.ui, 'Error loading tags', e, stack);
            return const Center(child: CircularProgressIndicator());
          },
          loading: () => const Center(child: CircularProgressIndicator()),
        );
      },
      error: (e, stack) {
        AppLogger.e(LogTag.ui, 'Error loading facets', e, stack);
        return const Center(child: CircularProgressIndicator());
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSelectedTagsSection(
    BuildContext context,
    List<Tag> allTags,
    Map<int?, TagFacet> facetById,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final selectedTags = allTags
        .where((tag) => _selectedTagIds.contains(tag.id))
        .toList();

    if (selectedTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        key: const ValueKey('bulk-tag-selected-section'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.tagSelectedCount(selectedTags.length),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AppTagWrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedTags.map((tag) {
                  final facet = facetById[tag.facetId];
                  final color = facet?.colorValue != null
                      ? Color(facet!.colorValue!)
                      : theme.colorScheme.primary;

                  return AppTag(
                    label: tag.name,
                    color: color,
                    size: AppTagSize.large,
                    isSelected: true,
                    actionType: AppTagActionType.minus,
                    onAction: () => _toggleTag(tag),
                    onTap: () => _toggleTag(tag),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagCloud(
    BuildContext context,
    List<Tag> allTags,
    List<Tag> filteredTags,
    List<TagFacet> orderedFacets,
    Map<int, TagFacet> facetById,
    String query,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (query.isNotEmpty || _selectedFacetId != null) {
      if (filteredTags.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              l10n.tagNoTagsMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: AppTagWrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            ...filteredTags.map((tag) {
              final facet = tag.facetId != null
                  ? facetById[tag.facetId!]
                  : null;
              final color = facet?.colorValue != null
                  ? Color(facet!.colorValue!)
                  : theme.colorScheme.primary;
              final isSelected = _selectedTagIds.contains(tag.id);

              return AppTag(
                label: tag.name,
                color: color,
                size: AppTagSize.large,
                count: '${tag.usageCount}',
                isSelected: isSelected,
                icon: tag.isHidden ? Icons.visibility_off_outlined : null,
                isDimmed: tag.isHidden,
                onTap: () => _toggleTag(tag),
              );
            }),
            AppTag(
              label: l10n.tagQuickAdd,
              icon: Icons.add,
              variant: AppTagVariant.outline,
              size: AppTagSize.large,
              color: theme.colorScheme.primary,
              onTap: () async {
                final result = await showTagFormSheet(
                  context,
                  initialFacetId: _selectedFacetId,
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      );
    }

    final tagsByFacet = <int?, List<Tag>>{};
    for (final tag in allTags) {
      tagsByFacet.putIfAbsent(tag.facetId, () => []).add(tag);
    }
    for (final list in tagsByFacet.values) {
      if (_sortMode == 'date') {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (_sortMode == 'count') {
        list.sort((a, b) => b.usageCount.compareTo(a.usageCount));
      } else {
        list.sort((a, b) => a.name.compareTo(b.name));
      }
    }

    final sections = <int?>[
      for (final f in orderedFacets)
        if (tagsByFacet[f.id]?.isNotEmpty ?? false) f.id,
      if (tagsByFacet[null]?.isNotEmpty ?? false) null,
    ];

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.tagNoTagsMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((facetId) {
        final facet = facetId != null ? facetById[facetId] : null;
        final facetTags = tagsByFacet[facetId] ?? const <Tag>[];
        final facetName = facet?.name ?? l10n.libraryTagUncategorized;
        final color = facet?.colorValue != null
            ? Color(facet!.colorValue!)
            : theme.colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      facetName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${facetTags.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      key: ValueKey('bulk-tag-facet-quick-add-$facetId'),
                      onPressed: () async {
                        final result = await showTagFormSheet(
                          context,
                          initialFacetId: facetId,
                        );
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        l10n.tagQuickAdd,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppTagWrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  ...facetTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id);
                    return AppTag(
                      label: tag.name,
                      color: color,
                      size: AppTagSize.large,
                      count: '${tag.usageCount}',
                      isSelected: isSelected,
                      icon: tag.isHidden ? Icons.visibility_off_outlined : null,
                      isDimmed: tag.isHidden,
                      onTap: () => _toggleTag(tag),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Future<void> showBulkTagSelectorSheet({
  required BuildContext context,
  required int selectedCount,
  required Future<void> Function(List<Tag> tags) onApply,
}) async {
  final l10n = AppLocalizations.of(context)!;
  await showAppBottomSheet(
    context,
    useRootNavigator: true,
    title: l10n.libraryBulkTagTitle,
    useSingleChildScrollView: false,
    child: BulkTagSelectorSheet(selectedCount: selectedCount, onApply: onApply),
  );
}
