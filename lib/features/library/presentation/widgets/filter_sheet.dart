import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/features/security/presentation/utils/security_action_guard.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';

class FilterSheet extends ConsumerStatefulWidget {
  final AppMode mode;

  const FilterSheet({super.key, required this.mode});

  static Future<void> show(
    BuildContext context, {
    required AppMode mode,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: false,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(mode: mode),
    );
  }

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  // ドラフト（一時保存）フィルター状態
  late MediaFilter _draftFilter;
  final _tagFilterKey = GlobalKey<_TagFilterSectionState>();

  @override
  void initState() {
    super.initState();
    // 初期のグローバルフィルター状態をドラフトとして複製
    _draftFilter = ref.read(mediaFilterNotifierProvider(widget.mode));
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _resetDraft() {
    setState(() {
      _draftFilter = _draftFilter.copyWith(
        tiers: null,
        isFavorite: null,
        mediaTypes: null,
        hasTags: null,
        isHidden: (ref.read(secretModeProvider).value ?? false)
            ? null
            : false,
        tagIds: null,
        excludedTagIds: null,
      );
      _tagFilterKey.currentState?.reset();
    });
  }

  Future<void> _setHiddenSelected(bool selected) async {
    if (!selected) {
      setState(() {
        // 「通常」は残したまま非表示だけを外す。
        _draftFilter = _draftFilter.copyWith(isHidden: false);
      });
      return;
    }

    final authenticated = await SecurityActionGuard.requireAuth(
      context,
      ref,
      title: AppLocalizations.of(context)!.hiddenItemsTitle,
    );
    if (!authenticated || !mounted) return;

    setState(() {
      final normalSelected = _draftFilter.isHidden != true;
      _draftFilter = _draftFilter.copyWith(
        // 通常も選択中なら両方表示（null）、非表示だけなら true。
        isHidden: normalSelected ? null : true,
      );
    });
  }

  void _setNormalSelected(bool selected) {
    setState(() {
      if (!selected) {
        // 非表示を残したまま通常だけを外す。
        _draftFilter = _draftFilter.copyWith(isHidden: true);
        return;
      }
      final hiddenSelected = _draftFilter.isHidden != false;
      _draftFilter = _draftFilter.copyWith(
        // 非表示も選択中なら両方表示（null）、通常だけなら false。
        isHidden: hiddenSelected ? null : false,
      );
    });
  }

  void _applyAndClose() {
    final notifier = ref.read(
      mediaFilterNotifierProvider(widget.mode).notifier,
    );
    notifier.applyFilterConditions(_draftFilter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ドラッグハンドル & ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          LibraryActionIcons.filter,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.commonFilter,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        AppMenuActionFeedback(
                          icon: Icons.refresh,
                          iconSize: 18,
                          onPressed: _resetDraft,
                          builder: (context, icon, onPressed) =>
                              TextButton.icon(
                                onPressed: onPressed,
                                icon: icon,
                                label: Text(l10n.commonReset),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // スクロール可能なフィルター選択コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    // 1. ティア
                    _SectionHeader(title: l10n.librarySelectTier),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: MediaTier.values
                          .where((e) => e != MediaTier.none)
                          .map((tier) {
                            final isSelected =
                                _draftFilter.tiers?.contains(tier.value) ??
                                false;
                            return FilterChip(
                              label: Semantics(
                                button: true,
                                selected: isSelected,
                                label: tier.localizedLabel(context),
                                child: Text(tier.localizedLabel(context)),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  final current = List<int>.from(
                                    _draftFilter.tiers ?? [],
                                  );
                                  if (selected) {
                                    current.add(tier.value);
                                  } else {
                                    current.remove(tier.value);
                                  }
                                  _draftFilter = _draftFilter.copyWith(
                                    tiers: current.isEmpty ? null : current,
                                  );
                                });
                              },
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 20),

                    // 2. お気に入り
                    _SectionHeader(title: l10n.libraryFilterFavorite),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.isFavorite == null,
                            label: l10n.commonAll,
                            child: Text(l10n.commonAll),
                          ),
                          selected: _draftFilter.isFavorite == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  isFavorite: null,
                                );
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.isFavorite == true,
                            label: l10n.libraryFilterFavoriteOnly,
                            child: Text(l10n.libraryFilterFavoriteOnly),
                          ),
                          selected: _draftFilter.isFavorite == true,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  isFavorite: true,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. 表示状態
                    _SectionHeader(title: l10n.libraryFilterVisibility),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.isHidden != true,
                            label: l10n.libraryFilterVisible,
                            child: Text(l10n.libraryFilterVisible),
                          ),
                          selected: _draftFilter.isHidden != true,
                          onSelected: _setNormalSelected,
                        ),
                        FilterChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.isHidden != false,
                            label: l10n.libraryFilterHidden,
                            child: Text(l10n.libraryFilterHidden),
                          ),
                          selected: _draftFilter.isHidden != false,
                          onSelected: _setHiddenSelected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. 種類
                    _SectionHeader(title: l10n.libraryFilterMediaType),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: Semantics(
                            button: true,
                            selected:
                                _draftFilter.mediaTypes?.contains(
                                  MediaType.folder,
                                ) ??
                                false,
                            label: l10n.commonFolder,
                            child: Text(l10n.commonFolder),
                          ),
                          selected:
                              _draftFilter.mediaTypes?.contains(
                                MediaType.folder,
                              ) ??
                              false,
                          onSelected: (selected) {
                            setState(() {
                              final current = List<MediaType>.from(
                                _draftFilter.mediaTypes ?? [],
                              );
                              if (selected) {
                                current.add(MediaType.folder);
                              } else {
                                current.remove(MediaType.folder);
                              }
                              _draftFilter = _draftFilter.copyWith(
                                mediaTypes: current.isEmpty ? null : current,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: Semantics(
                            button: true,
                            selected:
                                _draftFilter.mediaTypes?.contains(
                                  MediaType.file,
                                ) ??
                                false,
                            label: l10n.commonFile,
                            child: Text(l10n.commonFile),
                          ),
                          selected:
                              _draftFilter.mediaTypes?.contains(
                                MediaType.file,
                              ) ??
                              false,
                          onSelected: (selected) {
                            setState(() {
                              final current = List<MediaType>.from(
                                _draftFilter.mediaTypes ?? [],
                              );
                              if (selected) {
                                current.add(MediaType.file);
                              } else {
                                current.remove(MediaType.file);
                              }
                              _draftFilter = _draftFilter.copyWith(
                                mediaTypes: current.isEmpty ? null : current,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. タグ状態
                    _SectionHeader(title: l10n.libraryFilterTagStatus),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.hasTags == null,
                            label: l10n.commonAll,
                            child: Text(l10n.commonAll),
                          ),
                          selected: _draftFilter.hasTags == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  hasTags: null,
                                );
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.hasTags == true,
                            label: l10n.libraryFilterHasTags,
                            child: Text(l10n.libraryFilterHasTags),
                          ),
                          selected: _draftFilter.hasTags == true,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  hasTags: true,
                                );
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Semantics(
                            button: true,
                            selected: _draftFilter.hasTags == false,
                            label: l10n.libraryFilterNoTags,
                            child: Text(l10n.libraryFilterNoTags),
                          ),
                          selected: _draftFilter.hasTags == false,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  hasTags: false,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 5. 個別タグ（初期状態は折りたたみ）
                    _TagFilterSection(
                      key: _tagFilterKey,
                      filter: _draftFilter,
                      onChanged: (filter) {
                        setState(() => _draftFilter = filter);
                      },
                    ),
                  ],
                ),
              ),

              // フッター・アクションボタン
              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.commonCancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppMenuActionFeedback(
                          icon: LibraryActionIcons.filter,
                          onPressed: () {},
                          onFeedbackComplete: _applyAndClose,
                          builder: (context, icon, onPressed) =>
                              FilledButton.icon(
                                onPressed: onPressed,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: icon,
                                label: Text(l10n.commonApply),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagFilterSection extends ConsumerStatefulWidget {
  final MediaFilter filter;
  final ValueChanged<MediaFilter> onChanged;

  const _TagFilterSection({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  ConsumerState<_TagFilterSection> createState() => _TagFilterSectionState();
}

class _TagFilterSectionState extends ConsumerState<_TagFilterSection> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _expanded = false;
  final Set<int?> _expandedFacets = <int?>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void reset() {
    setState(() {
      _searchController.clear();
      _expandedFacets.clear();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _query) return;
    setState(() => _query = query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedCount = widget.filter.tagIds?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CharmIcon.filter(color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.libraryFilterByTag,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    selectedCount == 0 ? l10n.commonAll : '$selectedCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          _buildExpandedContent(context),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagListViewModelProvider);
    final facetsAsync = ref.watch(tagFacetListViewModelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.librarySearchHint,
            prefixIcon: const CharmIcon.search(size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    tooltip: l10n.commonClear,
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _searchController.clear,
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 12),
        tagsAsync.when(
          data: (allTags) {
            if (allTags.isEmpty) return Text(l10n.libraryNoTagsAvailable);
            final query = _query.toLowerCase();
            final filteredTags = query.isEmpty
                ? allTags
                : allTags
                      .where((tag) => tag.name.toLowerCase().contains(query))
                      .toList();
            if (filteredTags.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.libraryNoItems,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return facetsAsync.when(
              data: (facets) =>
                  _buildFacetGroups(context, filteredTags, facets),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(userSafeErrorMessage(error, l10n)),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(userSafeErrorMessage(error, l10n)),
        ),
      ],
    );
  }

  Widget _buildFacetGroups(
    BuildContext context,
    List<Tag> tags,
    List<TagFacet> facets,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final facetById = {for (final facet in facets) facet.id: facet};
    final tagsByFacet = <int?, List<Tag>>{};
    for (final tag in tags) {
      tagsByFacet.putIfAbsent(tag.facetId, () => <Tag>[]).add(tag);
    }
    final facetIds = <int?>[
      ...(facets.map((facet) => facet.id).toList()..sort(
        (a, b) => (facetById[a]?.sortOrder ?? 0).compareTo(
          facetById[b]?.sortOrder ?? 0,
        ),
      )),
      if (tagsByFacet.containsKey(null)) null,
    ];

    return Column(
      children: [
        for (final facetId in facetIds)
          if ((tagsByFacet[facetId] ?? const <Tag>[]).isNotEmpty)
            _buildFacet(
              context,
              facetId,
              tagsByFacet[facetId]!,
              facetById[facetId],
              l10n,
              theme,
            ),
      ],
    );
  }

  Widget _buildFacet(
    BuildContext context,
    int? facetId,
    List<Tag> tags,
    TagFacet? facet,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final isExpanded = _expandedFacets.contains(facetId);
    final facetName = facet?.name ?? l10n.tagFacetNone;
    final facetColor = facet?.colorValue != null
        ? Color(facet!.colorValue!)
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.circle, color: facetColor, size: 10),
            title: Text(
              facetName,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: facetColor.withValues(alpha: 0.8),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tags.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedFacets.remove(facetId);
              } else {
                _expandedFacets.add(facetId);
              }
            }),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AppTagWrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags) _buildTag(context, tag, facet),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, Tag tag, TagFacet? facet) {
    final isSelected = widget.filter.tagIds?.contains(tag.id) ?? false;
    return AppTag(
      label: tag.name,
      color: tag.getEffectiveColor(context, facet),
      size: AppTagSize.large,
      isSelected: isSelected,
      count: '${tag.usageCount}',
      icon: tag.isHidden ? Icons.visibility_off_outlined : null,
      isDimmed: tag.isHidden,
      onTap: () {
        final current = List<int>.from(widget.filter.tagIds ?? <int>[]);
        if (isSelected) {
          current.remove(tag.id);
        } else {
          current.add(tag.id);
        }
        widget.onChanged(
          widget.filter.copyWith(tagIds: current.isEmpty ? null : current),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
