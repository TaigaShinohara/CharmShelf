import 'dart:async';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/data/repositories/tag_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/screens/tag_management_screen.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TagSelectorWidget extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTagChanged;
  final ValueNotifier<bool>? saveInProgress;

  const TagSelectorWidget({
    super.key,
    required this.item,
    this.onTagChanged,
    this.saveInProgress,
  });

  @override
  ConsumerState<TagSelectorWidget> createState() => _TagSelectorWidgetState();
}

class _TagSelectorWidgetState extends ConsumerState<TagSelectorWidget> {
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  bool _initialized = false;
  bool _isLoadingCollectionTags = false;
  bool _isSyncing = false;
  bool _isCreating = false;
  Tag? _pendingCreatedTag;
  int? _selectedFacetId;
  Set<int> _selectedTagIds = <int>{};
  Set<int> _initialTagIds = <int>{};
  String _sortMode = 'name'; // 'name', 'count', 'date'

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

  Future<void> _ensureCollectionTagsLoaded() async {
    if (_isLoadingCollectionTags || _initialized) return;
    _isLoadingCollectionTags = true;
    final link = widget.item.collection;
    try {
      var collection = link.value;
      if (collection == null) {
        try {
          await link.load();
          collection = link.value;
        } catch (e, stack) {
          AppLogger.e(
            LogTag.ui,
            'Failed to load collection for tags',
            e,
            stack,
          );
          collection = link.value;
        }
      }
      if (collection != null) {
        if (collection.tags.isAttached && !collection.tags.isLoaded) {
          await collection.tags.load();
        }
        _selectedTagIds = collection.tags.map((tag) => tag.id).toSet();
        _initialTagIds = {..._selectedTagIds};
      }
    } finally {
      _isLoadingCollectionTags = false;
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  bool get _hasPendingChanges {
    if (_selectedTagIds.length != _initialTagIds.length) {
      return true;
    }
    for (final id in _selectedTagIds) {
      if (!_initialTagIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  void _toggleTag(Tag tag) {
    if (_isCreating) return;
    ref.read(feedbackServiceProvider).lightImpact();
    final isRemoving = _selectedTagIds.contains(tag.id);
    setState(() {
      if (isRemoving) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
    AppLogger.d(
      LogTag.ui,
      'Tag selection toggled: tagId=${tag.id}, action=${isRemoving ? 'remove' : 'add'}, selectedCount=${_selectedTagIds.length}',
    );
    unawaited(_syncPendingChanges());
  }

  Future<void> _syncPendingChanges() async {
    if (_isSyncing || !_hasPendingChanges) {
      AppLogger.d(
        LogTag.ui,
        'Tag sync skipped: isSyncing=$_isSyncing, hasPendingChanges=$_hasPendingChanges',
      );
      return;
    }
    final messenger = AppSnackBarMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSyncing = true);
    widget.saveInProgress?.value = true;
    try {
      final tagListFromState = ref.read(tagListViewModelProvider).value;
      final List<Tag> allTags;
      if (tagListFromState != null) {
        allTags = tagListFromState;
      } else {
        final repo = await ref.read(tagRepositoryProvider.future);
        final result = await repo.getAll();
        allTags = result.dataOrNull ?? const <Tag>[];
      }
      final syncUseCase = ref.read(syncCollectionTagsUseCaseProvider);
      while (_hasPendingChanges) {
        final targetIds = {..._selectedTagIds};
        final targetTags = allTags
            .where((tag) => targetIds.contains(tag.id))
            .toList();

        AppLogger.i(
          LogTag.ui,
          'Immediate tag sync started: targetCount=${targetTags.length}',
        );

        final result = await syncUseCase.invoke(widget.item, targetTags);
        final error = result.errorOrNull;
        if (error != null) {
          AppLogger.e(LogTag.ui, 'Immediate tag sync failed', error);
          throw error;
        }

        _initialTagIds = targetIds;
        if (mounted) {
          _invalidateTagConsumers();
        }
        AppLogger.i(
          LogTag.ui,
          'Immediate tag sync completed: selectedCount=${targetIds.length}',
        );
      }
    } catch (e, stack) {
      AppLogger.e(LogTag.ui, 'Immediate tag sync error', e, stack);
      if (mounted) {
        setState(() => _selectedTagIds = {..._initialTagIds});
        messenger.showSnackBar(
          SnackBar(content: Text(userSafeErrorMessage(e, l10n))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        widget.saveInProgress?.value = _isCreating;
      }
    }
  }

  Future<void> _createAndAttach(String name) async {
    if (_isCreating || _isSyncing) return;
    setState(() => _isCreating = true);
    widget.saveInProgress?.value = true;
    try {
      final tag = _pendingCreatedTag?.name == name
          ? _pendingCreatedTag!
          : await ref
                .read(tagListViewModelProvider.notifier)
                .addTag(name, facetId: _selectedFacetId);
      _pendingCreatedTag = tag;
      await _attachCreatedTag(tag);
    } catch (error) {
      _showCreateError(error);
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
        widget.saveInProgress?.value = _isSyncing;
      }
    }
  }

  Future<void> _showCreateForm({int? facetId}) async {
    if (_isCreating || _isSyncing) return;
    Tag? created;
    await showTagFormSheet(
      context,
      initialFacetId: facetId,
      initialName: _searchController.text.trim(),
      onCreated: (tag) => created = tag,
    );
    if (created == null || !mounted) return;
    _searchController.text = created!.name;
    setState(() {
      _isCreating = true;
      _pendingCreatedTag = created;
    });
    widget.saveInProgress?.value = true;
    try {
      await _attachCreatedTag(created!);
    } catch (error) {
      _showCreateError(error);
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
        widget.saveInProgress?.value = _isSyncing;
      }
    }
  }

  Future<void> _attachCreatedTag(Tag tag) async {
    // Creation and attachment have separate failure modes. Keep the persisted
    // tag for retry, and show it as selected only after attachment succeeds.
    final repository = await ref.read(tagRepositoryProvider.future);
    final tagsResult = await repository.getAll();
    final loadError = tagsResult.errorOrNull;
    if (loadError != null) throw loadError;
    final byId = {
      for (final existing in tagsResult.dataOrNull!) existing.id: existing,
      tag.id: tag,
    };
    final targetIds = {..._selectedTagIds, tag.id};
    final result = await ref.read(syncCollectionTagsUseCaseProvider).invoke(
      widget.item,
      [for (final id in targetIds) byId[id]!],
    );
    final error = result.errorOrNull;
    if (error != null) throw error;
    _initialTagIds = targetIds;
    _pendingCreatedTag = null;
    if (!mounted) return;
    setState(() => _selectedTagIds = {...targetIds});
    _invalidateTagConsumers();
  }

  void _showCreateError(Object error) {
    if (!mounted) return;
    AppSnackBarMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userSafeErrorMessage(error, AppLocalizations.of(context)!),
        ),
      ),
    );
  }

  void _invalidateTagConsumers() {
    final path = widget.item.collection.value?.path;
    if (path != null) ref.invalidate(collectionNotifierProvider(path));
    ref.invalidate(libraryViewModelProvider);
    ref.invalidate(externalFolderListProvider);
    ref.invalidate(externalFolderItemsProvider);
    ref.invalidate(externalRootItemsProvider);
    widget.onTagChanged?.call();
  }

  Widget _buildCreateAction(AppLocalizations l10n, {String? name}) {
    final retry = _pendingCreatedTag;
    final label = retry != null && retry.name == name
        ? l10n.tagAttachCreated(retry.name)
        : name != null && name.isNotEmpty
        ? l10n.tagCreateAndAttach(name)
        : l10n.tagQuickAdd;
    return FilledButton.icon(
      key: const ValueKey('tag-selector-create-and-attach'),
      onPressed: _isCreating || _isSyncing
          ? null
          : name != null && name.isNotEmpty
          ? () => _createAndAttach(name)
          : () => _showCreateForm(facetId: _selectedFacetId),
      icon: _isCreating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
      label: Text(label),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final asyncTags = ref.watch(visibleTagListProvider);
    final asyncFacets = ref.watch(tagFacetListViewModelProvider);

    final content = asyncFacets.when(
      data: (facets) {
        return asyncTags.when(
          data: (allTags) {
            if (!_initialized && !_isLoadingCollectionTags) {
              _ensureCollectionTagsLoaded();
            }
            final facetById = {for (final facet in facets) facet.id: facet};
            final orderedFacets = List<TagFacet>.from(facets)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            final query = _searchController.text.trim().toLowerCase();

            // 検索・フィルタリングされたタグ
            final filteredTags = allTags.where((tag) {
              if (_selectedFacetId != null && tag.facetId != _selectedFacetId) {
                return false;
              }
              if (query.isNotEmpty && !tag.name.toLowerCase().contains(query)) {
                return false;
              }
              return true;
            }).toList();

            // ソート処理
            if (_sortMode == 'date') {
              filteredTags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            } else if (_sortMode == 'count') {
              filteredTags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
            } else {
              filteredTags.sort((a, b) => a.name.compareTo(b.name));
            }

            // 分類ごとのタグ件数マップ
            final tagCountByFacet = <int?, int>{};
            for (final tag in allTags) {
              tagCountByFacet[tag.facetId] =
                  (tagCountByFacet[tag.facetId] ?? 0) + 1;
            }

            return Column(
              children: [
                // 選択中タグを操作しやすい画面上部に固定表示
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: PrimaryScrollController.maybeOf(context),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 検索バー ＆ ソート ＆ 管理画面遷移
                        Row(
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: TextField(
                                  key: const ValueKey('tag-selector-search'),
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
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const TagManagementScreen(),
                                  ),
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

                        // 2. 分類フィルターバー（横スクロールチップ）
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

                        // 3. タグ一覧（タグクラウド）
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
              ],
            );
          },
          error: (e, stack) {
            AppLogger.e(LogTag.ui, 'Error loading tags', e, stack);
            return const SizedBox();
          },
          loading: () =>
              Skeletonizer(enabled: true, child: _buildSkeleton(context, l10n)),
        );
      },
      error: (e, stack) {
        AppLogger.e(LogTag.ui, 'Error loading facets', e, stack);
        return const SizedBox();
      },
      loading: () =>
          Skeletonizer(enabled: true, child: _buildSkeleton(context, l10n)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: content,
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
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Container(
          key: const ValueKey('tag-selected-section'),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.tagSelectedCount(selectedTags.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppTagWrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: selectedTags.map((tag) {
                      final facet = facetById[tag.facetId];

                      return Semantics(
                        button: true,
                        label: l10n.tagActionRemove(tag.name),
                        onTap: _isCreating ? null : () => _toggleTag(tag),
                        excludeSemantics: true,
                        child: AppTag(
                          label: tag.name,
                          color: tag.getEffectiveColor(context, facet),
                          size: AppTagSize.small,
                          isDimmed: tag.isHidden,
                          onTap: _isCreating ? null : () => _toggleTag(tag),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
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
    final enteredName = _searchController.text.trim();
    final hasExactMatch = allTags.any(
      (tag) =>
          tag.name.toLowerCase() == query &&
          (_selectedFacetId == null || tag.facetId == _selectedFacetId),
    );
    final pending = _pendingCreatedTag;
    final shouldOfferCreation = enteredName.isNotEmpty && !hasExactMatch;
    final shouldOfferRetry =
        pending != null &&
        pending.name == enteredName &&
        !_selectedTagIds.contains(pending.id);

    if (query.isNotEmpty || _selectedFacetId != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filteredTags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.tagNoTagsMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              AppTagWrap(
                spacing: 8,
                runSpacing: 10,
                children: filteredTags.map((tag) {
                  final facet = facetById[tag.facetId];
                  return AppTag(
                    label: tag.name,
                    color: tag.getEffectiveColor(context, facet),
                    size: AppTagSize.large,
                    count: '${tag.usageCount}',
                    isSelected: _selectedTagIds.contains(tag.id),
                    icon: tag.isHidden ? Icons.visibility_off_outlined : null,
                    isDimmed: tag.isHidden,
                    onTap: _isCreating ? null : () => _toggleTag(tag),
                  );
                }).toList(),
              ),
            if (shouldOfferCreation || shouldOfferRetry) ...[
              const SizedBox(height: 12),
              _buildCreateAction(l10n, name: enteredName),
            ] else if (query.isEmpty) ...[
              const SizedBox(height: 12),
              _buildCreateAction(l10n),
            ],
          ],
        ),
      );
    }

    // 「すべて」選択時は分類ごとの見出しセクション ＋ Wrap タグクラウド
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
          child: Column(
            children: [
              Text(
                l10n.tagNoTagsMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _buildCreateAction(l10n),
            ],
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
              // セクション見出し
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
                      key: ValueKey('tag-selector-facet-quick-add-$facetId'),
                      onPressed: _isCreating || _isSyncing
                          ? null
                          : () => _showCreateForm(facetId: facetId),
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

              // タグチップ群（Wrap）
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
                      onTap: _isCreating ? null : () => _toggleTag(tag),
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

  Widget _buildSkeleton(BuildContext context, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 100) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                8,
                (_) => Container(
                  height: 32,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
