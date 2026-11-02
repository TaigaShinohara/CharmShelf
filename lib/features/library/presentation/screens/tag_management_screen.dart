import 'dart:async';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_preset_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_export_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/facet_form_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_import_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

/// 直感的で説明書なしでも操作できるタグ管理画面
class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  /// 選択中のFacet ID（null のときは「すべて」）
  int? _selectedFacetId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  String _sortMode = 'name'; // 'name', 'count', 'date'
  bool _isChipView = true;
  bool _isSettingUpPresets = false;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    final normalized = value.trim().toLowerCase();
    if (normalized == _searchQuery) return;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _searchQuery = normalized);
    });
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _createFromSearch() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) {
      _clearSearch();
      return;
    }
    await showTagFormSheet(
      context,
      initialName: name,
      initialFacetId: _selectedFacetId,
      onCreated: (created) {
        if (!mounted) return;
        _searchDebounceTimer?.cancel();
        _searchController.text = created.name;
        setState(() {
          _searchQuery = created.name.trim().toLowerCase();
          _selectedFacetId = created.facetId;
        });
      },
    );
  }

  Future<void> _handleSetupPresets(BuildContext context) async {
    if (_isSettingUpPresets) return;

    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.tagSetupPresetsConfirmTitle,
      message: l10n.tagSetupPresetsConfirmMessage,
      confirmLabel: l10n.tagSetupPresetsConfirmAction,
      cancelLabel: l10n.commonCancel,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSettingUpPresets = true);

    try {
      final presetService = await ref.read(tagPresetServiceProvider.future);
      final count = await presetService.createStandardPresets();
      ref.invalidate(tagListViewModelProvider);
      ref.invalidate(tagFacetListViewModelProvider);

      if (mounted) {
        snackBar.success(
          context: this.context,
          message: l10n.tagPresetsCreated(count),
        );
      }
    } catch (e) {
      if (mounted) {
        AppLogger.e(LogTag.ui, 'Setup presets error', e);
        snackBar.error(
          context: this.context,
          message: userSafeErrorMessage(e, l10n),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSettingUpPresets = false);
      }
    }
  }

  Future<void> _handleDeleteTag(BuildContext context, Tag tag) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.tagDeleteConfirm,
      message: l10n.tagDeleteMessage(tag.name),
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await ref.read(tagListViewModelProvider.notifier).deleteTag(tag.id);
      } catch (e) {
        if (mounted) {
          AppLogger.e(LogTag.ui, 'Delete tag error', e);
          ref
              .read(snackBarServiceProvider)
              .error(
                context: this.context,
                message: userSafeErrorMessage(e, l10n),
              );
        }
      }
    }
  }

  void _showTagActionSheet(Tag tag) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showActionBottomSheet<String>(
      context,
      title: tag.name,
      items: [
        ActionSheetItem(
          icon: Icons.edit_outlined,
          label: l10n.commonEdit,
          value: 'edit',
        ),
        ActionSheetItem(
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          value: 'delete',
          isDestructive: true,
        ),
      ],
    );

    if (!mounted) return;
    if (result == 'edit') {
      showTagFormSheet(context, tag: tag);
    } else if (result == 'delete') {
      _handleDeleteTag(context, tag);
    }
  }

  void _showSortDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
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

  void _showFacetManagementModal(BuildContext context, List<TagFacet> facets) {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet(
      context,
      title: l10n.tagManageFacets,
      child: _FacetManagementSheet(facets: facets),
    );
  }

  void _showImportModal(BuildContext context) {
    showTagImportSheet(context);
  }

  Future<void> _handleExport(
    BuildContext context,
    List<TagFacet> facets,
  ) async {
    final selectedFacet = facets.where((facet) => facet.id == _selectedFacetId);
    await ref
        .read(tagExportProvider.notifier)
        .export(context, selectedFacet: selectedFacet.firstOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final asyncTags = ref.watch(tagListViewModelProvider);
    final asyncFacets = ref.watch(tagFacetListViewModelProvider);

    return Scaffold(
      body: asyncFacets.when(
        data: (facets) {
          return asyncTags.when(
            data: (tags) => _buildContent(context, tags, facets, l10n, theme),
            loading: () => const LoadingWidget(),
            error: (e, st) => Center(
              child: ErrorStateWidget(
                error: e is AppError
                    ? e
                    : AppError.ui(
                        userSafeErrorMessage(e, l10n),
                        original: e,
                        stackTrace: st,
                        context: 'TagManagementScreen.tags',
                      ),
                onRetry: () => ref.invalidate(tagListViewModelProvider),
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(
          child: ErrorStateWidget(
            error: e is AppError
                ? e
                : AppError.ui(
                    userSafeErrorMessage(e, l10n),
                    original: e,
                    stackTrace: st,
                    context: 'TagManagementScreen.facets',
                  ),
            onRetry: () => ref.invalidate(tagFacetListViewModelProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Tag> allTags,
    List<TagFacet> facets,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final facetById = {for (final f in facets) f.id: f};
    final orderedFacets = List<TagFacet>.from(facets)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // タグの絞り込み
    final query = _searchQuery;
    final filteredTags = allTags.where((t) {
      if (_selectedFacetId != null && t.facetId != _selectedFacetId) {
        return false;
      }
      if (query.isNotEmpty && !t.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    _sortTags(filteredTags);

    // 分類ごとのタグ件数マップ
    final tagCountByFacet = <int?, int>{};
    for (final tag in allTags) {
      tagCountByFacet[tag.facetId] = (tagCountByFacet[tag.facetId] ?? 0) + 1;
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          PremiumSliverAppBar(
            titleText: l10n.tagManageTitle,
            inlineTitle: true,
            actions: [
              IconButton(
                key: const ValueKey('tag-add-new'),
                icon: const CharmIcon.add(),
                tooltip: l10n.tagAddNew,
                onPressed: () {
                  ref.read(feedbackServiceProvider).lightImpact();
                  showTagFormSheet(context, initialFacetId: _selectedFacetId);
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.commonMenu,
                onSelected: (value) {
                  if (value == 'facets') {
                    _showFacetManagementModal(context, facets);
                  } else if (value == 'import') {
                    _showImportModal(context);
                  } else if (value == 'export') {
                    _handleExport(context, facets);
                  } else if (value == 'presets') {
                    _handleSetupPresets(context);
                  }
                },
                itemBuilder: (context) => [
                  AppPopupMenuItem.text(
                    value: 'facets',
                    iconData: Icons.category_outlined,
                    text: l10n.tagManageFacets,
                  ),
                  AppPopupMenuItem.text(
                    value: 'presets',
                    iconData: Icons.auto_awesome_outlined,
                    text: l10n.tagSetupPresetsAction,
                  ),
                  const PopupMenuDivider(),
                  AppPopupMenuItem.text(
                    value: 'import',
                    iconData: LibraryActionIcons.importData,
                    text: l10n.tagImportTabTitle,
                  ),
                  AppPopupMenuItem.text(
                    value: 'export',
                    iconData: LibraryActionIcons.exportData,
                    text: l10n.tagExportAction,
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 検索バー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.tagSearchHint,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        prefixIcon: CharmIcon.search(
                          size: AppIconSize.md,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  size: AppIconSize.sm,
                                ),
                                tooltip: l10n.commonClear,
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        border: const OutlineInputBorder(
                          borderRadius: AppRadius.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      onChanged: _handleSearchChanged,
                    ),
                  ),
                ),

                // 2. 分類フィルターバー（横スクロールチップ）
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      // 「すべて」チップ
                      FacetChip(
                        label: l10n.tagAllFacets,
                        count: allTags.length,
                        isSelected: _selectedFacetId == null,
                        showDot: false,
                        onSelected: (_) =>
                            setState(() => _selectedFacetId = null),
                      ),
                      AppSpacing.gapHorizontalSm,

                      // 各分類チップ
                      ...orderedFacets.map((facet) {
                        final isSelected = _selectedFacetId == facet.id;
                        final count = tagCountByFacet[facet.id] ?? 0;
                        final color = facet.colorValue != null
                            ? Color(facet.colorValue!)
                            : theme.colorScheme.primary;

                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: FacetChip(
                            label: facet.name,
                            color: color,
                            count: count,
                            isSelected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedFacetId = isSelected ? null : facet.id;
                              });
                            },
                          ),
                        );
                      }),

                      // ＋ 分類追加ボタン
                      ActionChip(
                        avatar: const Icon(Icons.add, size: AppIconSize.sm),
                        label: AppText(l10n.tagFacetTabTitle),
                        onPressed: () => showFacetFormSheet(context),
                      ),
                    ],
                  ),
                ),

                // 3. ツールバー（件数・表示切替・ソート）
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          _selectedFacetId == null
                              ? l10n.tagAllCount(filteredTags.length)
                              : '${facetById[_selectedFacetId]?.name ?? l10n.libraryTagUncategorized} (${filteredTags.length})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // チップ/リスト切替
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusSm,
                          ),
                        ),
                        onPressed: () {
                          ref.read(feedbackServiceProvider).selection();
                          setState(() => _isChipView = !_isChipView);
                        },
                        icon: Icon(
                          _isChipView
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                          size: AppIconSize.md,
                        ),
                        tooltip: _isChipView
                            ? l10n.tagViewList
                            : l10n.tagViewChips,
                      ),
                      AppSpacing.gapHorizontalXs,
                      // ソート
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusSm,
                          ),
                        ),
                        onPressed: () => _showSortDialog(context),
                        icon: const Icon(
                          LibraryActionIcons.sort,
                          size: AppIconSize.md,
                        ),
                        tooltip: l10n.tagSortTitle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      body: allTags.isEmpty && query.isEmpty
          ? _buildEmptyState(context, l10n, theme)
          : filteredTags.isEmpty
          ? _buildSearchEmptyState(
              l10n,
              canSearchAllCategories:
                  _selectedFacetId != null &&
                  allTags.any((tag) => tag.name.toLowerCase().contains(query)),
            )
          : _isChipView
          ? _buildTagChipsView(
              context,
              allTags,
              filteredTags,
              orderedFacets,
              facetById,
              l10n,
              theme,
            )
          : _buildListView(context, filteredTags, facetById, l10n, theme),
    );
  }

  Widget _buildSearchEmptyState(
    AppLocalizations l10n, {
    required bool canSearchAllCategories,
  }) {
    final hasQuery = _searchQuery.isNotEmpty;
    final actions = <Widget>[];
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
    );
    if (canSearchAllCategories) {
      actions.add(
        FilledButton.tonal(
          key: const ValueKey('tag-search-all-categories'),
          style: buttonStyle,
          onPressed: () => setState(() => _selectedFacetId = null),
          child: Text(l10n.tagSearchAllCategories, textAlign: TextAlign.center),
        ),
      );
    }
    if (hasQuery) {
      final label = Text(l10n.tagCreateFromSearch, textAlign: TextAlign.center);
      actions.add(
        canSearchAllCategories
            ? OutlinedButton(
                key: const ValueKey('tag-create-from-search'),
                style: buttonStyle,
                onPressed: _createFromSearch,
                child: label,
              )
            : FilledButton(
                key: const ValueKey('tag-create-from-search'),
                style: buttonStyle,
                onPressed: _createFromSearch,
                child: label,
              ),
      );
      actions.add(
        TextButton(
          key: const ValueKey('tag-clear-search'),
          style: buttonStyle,
          onPressed: _clearSearch,
          child: Text(l10n.libraryClearSearch, textAlign: TextAlign.center),
        ),
      );
    }
    return EmptyStateWidget(
      title: l10n.tagNoTagsMessage,
      subtitle: hasQuery ? l10n.tagCreateFromSearchHint : null,
      icon: Icons.search_off_outlined,
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: actions,
      ),
    );
  }

  void _sortTags(List<Tag> tags) {
    if (_sortMode == 'date') {
      tags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortMode == 'count') {
      tags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    } else {
      tags.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  /// 初回・タグ0件時のウェルカム空状態
  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.7,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: AppIconSize.xxl,
                color: theme.colorScheme.primary,
              ),
            ),
            AppSpacing.gapVerticalLg,
            AppText(
              l10n.tagEmptyGuideTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.gapVerticalSm,
            AppText(
              l10n.tagEmptyGuideSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            AppSpacing.gapVerticalXl,

            // おすすめタグ一括セットアップボタン
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMd,
                ),
              ),
              onPressed: _isSettingUpPresets
                  ? null
                  : () => _handleSetupPresets(context),
              icon: _isSettingUpPresets
                  ? const SizedBox(
                      width: AppIconSize.sm,
                      height: AppIconSize.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt),
              label: AppText(l10n.tagSetupPresetsAction),
            ),
            AppSpacing.gapVerticalMd,

            // 手動作成ボタン
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMd,
                ),
              ),
              onPressed: () => showTagFormSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.tagCreate),
            ),
          ],
        ),
      ),
    );
  }

  /// 一目でタグとわかる AppTag ベースのタグチップ表示（Wrap）
  Widget _buildTagChipsView(
    BuildContext context,
    List<Tag> allTags,
    List<Tag> filteredTags,
    List<TagFacet> orderedFacets,
    Map<int, TagFacet> facetById,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    // 検索中、または特定の分類が選択されている場合はフラットな Wrap タグチップ一覧
    if (_searchQuery.isNotEmpty || _selectedFacetId != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          AppTagWrap(
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

                return AppTag(
                  label: tag.name,
                  color: color,
                  size: AppTagSize.large,
                  count: '${tag.usageCount}',
                  icon: tag.isHidden ? Icons.visibility_off_outlined : null,
                  isDimmed: tag.isHidden,
                  onTap: () => showTagFormSheet(context, tag: tag),
                  onLongPress: () {
                    ref.read(feedbackServiceProvider).mediumImpact();
                    _showTagActionSheet(tag);
                  },
                  longPressHint: l10n.tagMoreActions(tag.name),
                );
              }),
              // ＋ タグを追加ボタン
              AppTag(
                label: l10n.tagQuickAdd,
                icon: Icons.add,
                variant: AppTagVariant.outline,
                size: AppTagSize.large,
                color: theme.colorScheme.primary,
                onTap: () =>
                    showTagFormSheet(context, initialFacetId: _selectedFacetId),
              ),
            ],
          ),
        ],
      );
    }

    // 「すべて」選択時は分類ごとの見出しセクション ＋ Wrap タグチップ一覧
    final tagsByFacet = <int?, List<Tag>>{};
    for (final tag in allTags) {
      tagsByFacet.putIfAbsent(tag.facetId, () => []).add(tag);
    }
    for (final list in tagsByFacet.values) {
      _sortTags(list);
    }

    // 表示する分類IDリスト（分類順 + 未分類）
    final sections = <int?>[
      for (final f in orderedFacets)
        if (tagsByFacet[f.id]?.isNotEmpty ?? false) f.id,
      if (tagsByFacet[null]?.isNotEmpty ?? false) null,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final facetId = sections[sectionIndex];
        final facet = facetId != null ? facetById[facetId] : null;
        final facetTags = tagsByFacet[facetId] ?? const <Tag>[];
        final facetName = facet?.name ?? l10n.libraryTagUncategorized;
        final color = facet?.colorValue != null
            ? Color(facet!.colorValue!)
            : theme.colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // セクション見出し
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: facetName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: ' (${facetTags.length})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: ValueKey('tag-facet-quick-add-$facetId'),
                      onPressed: () =>
                          showTagFormSheet(context, initialFacetId: facetId),
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
              const SizedBox(height: 8),

              // タグチップ群（Wrap）
              AppTagWrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  ...facetTags.map((tag) {
                    return AppTag(
                      label: tag.name,
                      color: color,
                      size: AppTagSize.large,
                      count: '${tag.usageCount}',
                      icon: tag.isHidden ? Icons.visibility_off_outlined : null,
                      isDimmed: tag.isHidden,
                      onTap: () => showTagFormSheet(context, tag: tag),
                      onLongPress: () {
                        ref.read(feedbackServiceProvider).mediumImpact();
                        _showTagActionSheet(tag);
                      },
                      longPressHint: l10n.tagMoreActions(tag.name),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 詳細リスト表示（詳細情報の確認・整理に最適）
  Widget _buildListView(
    BuildContext context,
    List<Tag> tags,
    Map<int, TagFacet> facetById,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        final facet = tag.facetId != null ? facetById[tag.facetId!] : null;
        final color = facet?.colorValue != null
            ? Color(facet!.colorValue!)
            : theme.colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2,
              ),
              onTap: () => showTagFormSheet(context, tag: tag),
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      tag.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tag.isHidden
                            ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              )
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tag.isHidden) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: theme.colorScheme.error.withValues(alpha: 0.8),
                    ),
                  ],
                ],
              ),
              subtitle: facet != null
                  ? Text(
                      facet.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tag.usageCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: l10n.tagMoreActions(tag.name),
                    onSelected: (value) {
                      if (value == 'edit') {
                        showTagFormSheet(context, tag: tag);
                      } else if (value == 'delete') {
                        _handleDeleteTag(context, tag);
                      }
                    },
                    itemBuilder: (context) => [
                      AppPopupMenuItem.text(
                        value: 'edit',
                        iconData: Icons.edit_outlined,
                        text: l10n.commonEdit,
                      ),
                      AppPopupMenuItem.text(
                        value: 'delete',
                        iconData: Icons.delete_outline,
                        iconColor: theme.colorScheme.error,
                        textColor: theme.colorScheme.error,
                        text: l10n.commonDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 分類（Facet）管理用のボトムシート
class _FacetManagementSheet extends ConsumerWidget {
  final List<TagFacet> facets;

  const _FacetManagementSheet({required this.facets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final orderedFacets = List<TagFacet>.from(facets)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return SizedBox(
      height: 480,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.tagFacetTabTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => showFacetFormSheet(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.commonAdd),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: orderedFacets.length,
              onReorderItem: (oldIndex, newIndex) async {
                final updated = List<TagFacet>.from(orderedFacets);
                final item = updated.removeAt(oldIndex);
                updated.insert(newIndex, item);
                try {
                  await ref
                      .read(tagFacetListViewModelProvider.notifier)
                      .reorderFacets(updated);
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBarMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(userSafeErrorMessage(e, l10n))),
                    );
                  }
                }
              },
              itemBuilder: (context, index) {
                final facet = orderedFacets[index];
                final color = facet.colorValue != null
                    ? Color(facet.colorValue!)
                    : theme.colorScheme.primary;

                return Padding(
                  key: ValueKey(facet.id),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: () => showFacetFormSheet(context, facet: facet),
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        facet.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            tooltip: l10n.commonEdit,
                            onPressed: () =>
                                showFacetFormSheet(context, facet: facet),
                          ),
                          Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
