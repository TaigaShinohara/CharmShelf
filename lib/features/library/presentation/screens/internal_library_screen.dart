import 'dart:async';
import 'package:private_shelf/features/library/presentation/widgets/retained_library_list.dart';
import 'package:private_shelf/shared/widgets/feedback/deferred_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/providers/back_navigation_provider.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/helpers/library_action_handler.dart';
import 'package:private_shelf/features/library/presentation/helpers/sync_dialog_handler.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_fab_visibility_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/active_condition_chips.dart';
import 'package:private_shelf/features/library/presentation/widgets/breadcrumb_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_header.dart';
import 'package:private_shelf/features/library/presentation/widgets/catalog_registration_icon.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_import_button.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_app_bar.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_discovery_empty_state.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_grid.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/library/presentation/widgets/resume_banner.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/feature_customization_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_sync_provider.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/dialogs/paged_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_selection_menu.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_sort_dialog.dart';

class InternalLibraryScreen extends ConsumerStatefulWidget {
  const InternalLibraryScreen({super.key});

  @override
  ConsumerState<InternalLibraryScreen> createState() =>
      _InternalLibraryScreenState();
}

class _InternalLibraryScreenState extends ConsumerState<InternalLibraryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  TextEditingValue _lastSearchEditingValue = TextEditingValue.empty;
  Timer? _debounce;
  bool _isSearchPending = false;
  bool _suppressSearchControllerUpdates = false;
  bool _pendingAddMenuScheduled = false;

  final SyncDialogHandler _syncDialogHandler = SyncDialogHandler();
  final LibraryActionHandler _actionHandler = const LibraryActionHandler();

  DateTime? _lastBackHandledAt;
  static const Duration _backHandlingCooldown = Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchEditingValueChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _schedulePendingAddMenu(ref.read(pendingLibraryLaunchActionProvider));
    });
  }

  void _handleSearchEditingValueChanged() {
    final value = _searchController.value;
    if (value.text == _lastSearchEditingValue.text &&
        value.composing == _lastSearchEditingValue.composing) {
      return;
    }
    _lastSearchEditingValue = value;
    if (_suppressSearchControllerUpdates) return;
    _debounce?.cancel();
    if (value.composing.isValid && !value.composing.isCollapsed) {
      if (mounted && _isSearchPending) {
        setState(() => _isSearchPending = false);
      }
      return;
    }

    if (value.text.isEmpty) {
      _submitSearch(value.text);
      return;
    }

    if (mounted) setState(() => _isSearchPending = true);

    _debounce = Timer(librarySearchDebounce, () {
      if (!mounted) return;
      setState(() => _isSearchPending = false);
      ref
          .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
          .updateSearchQuery(value.text);
    });
  }

  void _submitSearch(String query) {
    _debounce?.cancel();
    if (mounted && _isSearchPending) {
      setState(() => _isSearchPending = false);
    }
    ref
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchQuery(query);
  }

  @override
  void dispose() {
    _syncDialogHandler.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _isSearchPending = false;
    });
    _suppressSearchControllerUpdates = true;
    _searchController.clear();
    _suppressSearchControllerUpdates = false;
    _debounce?.cancel();
    ref
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .endSearch();
  }

  void _clearSearchInput() {
    _suppressSearchControllerUpdates = true;
    _searchController.clear();
    _suppressSearchControllerUpdates = false;
    _debounce?.cancel();
    if (mounted && _isSearchPending) {
      setState(() => _isSearchPending = false);
    }
  }

  void _clearSearch() {
    _clearSearchInput();
    ref
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .endSearch();
  }

  void _clearSearchAndFilters() {
    _clearSearchInput();
    ref
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .clearDiscoveryConditions();
  }

  Future<void> _showAddMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ActionBottomSheet<String>(
        title: l10n.libraryCatalogRegistration,
        enableSelectionFeedback: false,
        items: [
          ActionSheetItem<String>(
            iconWidget: const CatalogRegistrationIcon.folder(),
            label: l10n.libraryImportFolder,
            value: 'import_folder',
          ),
          ActionSheetItem<String>(
            iconWidget: const CatalogRegistrationIcon.file(),
            label: l10n.libraryImportFile,
            value: 'import_file',
          ),
          ActionSheetItem<String>(
            icon: Icons.create_new_folder,
            label: l10n.libraryCreateNewFolder,
            value: 'folder',
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await _actionHandler.handleAddAction(result, context, ref);
    }
  }

  void _schedulePendingAddMenu(LibraryLaunchAction? action) {
    if (action == null || _pendingAddMenuScheduled) {
      return;
    }
    _pendingAddMenuScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pending = ref
          .read(pendingLibraryLaunchActionProvider.notifier)
          .take();
      try {
        if (pending == LibraryLaunchAction.showAddMenu) {
          await _showAddMenu();
        } else if (pending == LibraryLaunchAction.importFile) {
          await _actionHandler.handleAddAction('import_file', context, ref);
        }
      } finally {
        _pendingAddMenuScheduled = false;
      }
    });
  }

  bool _shouldIgnoreBackAction() {
    final now = DateTime.now();
    final lastHandledAt = _lastBackHandledAt;
    if (lastHandledAt != null &&
        now.difference(lastHandledAt) < _backHandlingCooldown) {
      return true;
    }
    _lastBackHandledAt = now;
    return false;
  }

  void _handleBackNavigation({
    required bool isSelectionMode,
    required MediaFilter filter,
  }) {
    if (_shouldIgnoreBackAction()) return;
    if (isSelectionMode) {
      ref.read(backNavigationRevisionProvider.notifier).markHandled();
      ref.read(libraryViewModelProvider.notifier).clearSelection();
      return;
    }
    if (_isSearching) {
      ref.read(backNavigationRevisionProvider.notifier).markHandled();
      _stopSearch();
      return;
    }
    if (filter.parentPath == null) return;
    ref.read(backNavigationRevisionProvider.notifier).markHandled();
    ref.read(mediaFilterNotifierProvider(AppMode.internal).notifier).goUp();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.internal));
    final discoveryConditions = LibraryDiscoveryConditions(
      filter: filter,
      defaultHiddenFilter: (ref.watch(secretModeProvider).value ?? false)
          ? null
          : false,
    );
    final asyncItems = ref.watch(libraryViewModelProvider);
    final hasVisibleItems = asyncItems.value?.isNotEmpty ?? false;
    final folderManagementEnabled = ref.watch(folderManagementEnabledProvider);
    final isSelectionMode = ref.watch(
      librarySelectionNotifierProvider.select((s) => s.isSelectionMode),
    );

    ref.listen<SyncProgress>(syncProgressNotifierProvider, (previous, next) {
      _syncDialogHandler.handleSyncProgressChange(
        context,
        previous,
        next,
        '内部ライブラリ',
      );
    });

    ref.listen(libraryViewModelProvider, (previous, next) {
      if (next is AsyncError) {
        _actionHandler.showErrorSnackBar(context, next.error!);
      }
    });

    ref.listen<LibraryLaunchAction?>(
      pendingLibraryLaunchActionProvider,
      (previous, next) => _schedulePendingAddMenu(next),
    );

    final syncProgress = ref.read(syncProgressNotifierProvider);
    if (!_syncDialogHandler.isActiveSyncStatus(syncProgress.status)) {
      _syncDialogHandler.hideSyncDialogIfNeeded();
    }

    final currentCollection = filter.parentPath != null
        ? ref.watch(collectionNotifierProvider(filter.parentPath!)).value
        : null;
    final isLibraryRoot = filter.parentPath == null;

    final activeCollection = currentCollection;
    final collectionHeader =
        activeCollection == null || activeCollection.isCatalog != true
        ? null
        : Column(
            children: [
              CollectionHeader(collection: activeCollection),
              ResumeBanner(collection: activeCollection),
            ],
          );
    Widget withCollectionHeader(Widget content) {
      if (collectionHeader == null) return content;
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: collectionHeader),
          SliverFillRemaining(child: content),
        ],
      );
    }

    final hasBackButton = filter.parentPath != null;

    final canHandleBackLocally =
        _isSearching || isSelectionMode || filter.parentPath != null;

    return PopScope(
      canPop: !canHandleBackLocally,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation(isSelectionMode: isSelectionMode, filter: filter);
      },
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              LibraryAppBar(
                isSearching: _isSearching,
                selectionCount: isSelectionMode
                    ? ref.watch(librarySelectionNotifierProvider).selectedCount
                    : null,
                hasBackButton: hasBackButton,
                isLibraryRoot: isLibraryRoot,
                filter: filter,
                titleText: isLibraryRoot
                    ? null
                    : l10n.libraryCatalogContentsTitle,
                searchController: _searchController,
                onBackButtonPressed: () => _handleBackNavigation(
                  isSelectionMode: isSelectionMode,
                  filter: filter,
                ),
                onStopSearch: _stopSearch,
                onSearchSubmitted: _submitSearch,
                onSearchTargetChanged: (target) => ref
                    .read(
                      mediaFilterNotifierProvider(AppMode.internal).notifier,
                    )
                    .updateSearchTarget(target),
                onSearchScopeChanged: (withinParent) => ref
                    .read(
                      mediaFilterNotifierProvider(AppMode.internal).notifier,
                    )
                    .updateSearchWithinParent(withinParent),
                onOpenFilter: () => _actionHandler.handleMenuAction(
                  'filter',
                  context,
                  ref,
                  filter,
                  AppMode.internal,
                ),
                actions: _buildActions(context, ref, filter),
                bottom: (filter.parentPath != null)
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(56),
                        child: Consumer(
                          builder: (context, ref, child) {
                            final docsPathAsync = ref.watch(
                              applicationDocumentsPathProvider,
                            );
                            final physicalPath = docsPathAsync.when(
                              data: (docsPath) => p.join(
                                docsPath,
                                'library',
                                filter.parentPath!,
                              ),
                              loading: () => filter.parentPath ?? '',
                              error: (err, stack) => filter.parentPath ?? '',
                            );
                            return BreadcrumbBar(
                              currentPath: filter.parentPath,
                              physicalPath: physicalPath,
                              rootLabel: l10n.libraryInternalTitle,
                              onPathSelected: (path) {
                                ref
                                    .read(
                                      mediaFilterNotifierProvider(
                                        AppMode.internal,
                                      ).notifier,
                                    )
                                    .updateParentPath(path);
                              },
                            );
                          },
                        ),
                      )
                    : null,
              ),
            ];
          },
          body: Consumer(
            builder: (context, ref, child) {
              final syncProgress = ref.watch(folderSyncNotifierProvider);
              final operationProgress = ref.watch(syncProgressNotifierProvider);
              final isSyncing =
                  syncProgress.status == SyncStatus.processing ||
                  syncProgress.status == SyncStatus.scanning;
              final isOperating =
                  operationProgress.status == SyncStatus.processing ||
                  operationProgress.status == SyncStatus.scanning;

              return Column(
                children: [
                  DeferredProgressBar(
                    key: const ValueKey('library-update-progress'),
                    active:
                        isSyncing ||
                        isOperating ||
                        _isSearchPending ||
                        asyncItems.isLoading,
                  ),
                  ActiveConditionChips(
                    mode: AppMode.internal,
                    filter: filter,
                    sortOrderLabel: filter.sortOrder.localizedLabel(context),
                    onClearAll: _clearSearchAndFilters,
                    showSearchQuery: !_isSearching,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(feedbackServiceProvider).lightImpact();
                        final result = await ref
                            .read(folderSyncNotifierProvider.notifier)
                            .sync();

                        if (!context.mounted) return;
                        final snackBar = ref.read(snackBarServiceProvider);

                        if (result.isSuccess) {
                          final data = result.dataOrNull;
                          if (data != null) {
                            snackBar.success(
                              context: context,
                              message: l10n.settingsStorageSyncSuccess(
                                data.added,
                                data.updated,
                                data.missing,
                              ),
                            );
                          }
                        } else if (result.isFailure) {
                          final error = result.errorOrNull;
                          if (error != null) {
                            _actionHandler.showErrorSnackBar(
                              context,
                              error,
                              ref: ref,
                            );
                          }
                        }
                      },
                      child: Builder(
                        builder: (context) {
                          final fallback = asyncItems.when(
                            skipLoadingOnReload: true,
                            skipLoadingOnRefresh: true,
                            data: (items) {
                              if (items.isEmpty) {
                                final emptyState = _buildEmptyState(
                                  context,
                                  ref,
                                  filter,
                                  discoveryConditions,
                                );
                                return withCollectionHeader(emptyState);
                              }
                              final viewMode = ref.watch(
                                globalViewModeProvider,
                              );
                              return NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.depth == 0 &&
                                      notification
                                          is ScrollUpdateNotification &&
                                      notification.metrics.extentAfter < 600) {
                                    ref
                                        .read(libraryViewModelProvider.notifier)
                                        .loadMore();
                                  }
                                  return false;
                                },
                                child: viewMode == ViewMode.grid
                                    ? MediaGrid(header: collectionHeader)
                                    : MediaListView(
                                        items: items,
                                        header: collectionHeader,
                                      ),
                              );
                            },
                            loading: () =>
                                withCollectionHeader(const LoadingWidget()),
                            error: (err, stack) => withCollectionHeader(
                              Center(
                                child: ErrorStateWidget(
                                  error: err is AppError
                                      ? err
                                      : AppError.ui(
                                          l10n.commonErrorOccurred,
                                          original: err,
                                          stackTrace: stack,
                                          context: 'InternalLibraryScreen',
                                        ),
                                  onRetry: () {
                                    ref.invalidate(libraryViewModelProvider);
                                  },
                                ),
                              ),
                            ),
                          );
                          if (ref.watch(globalViewModeProvider) ==
                              ViewMode.grid) {
                            return fallback;
                          }
                          return RetainedLibraryList(
                            items: asyncItems,
                            filter: filter,
                            header: collectionHeader,
                            fallback: fallback,
                            onLoadMore: () => ref
                                .read(libraryViewModelProvider.notifier)
                                .loadMore(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton:
            (isSelectionMode ||
                _isSearching ||
                (!hasVisibleItems && filter.parentPath != null) ||
                _isBareEmptyLibrary(
                  filter,
                  hasVisibleItems,
                  discoveryConditions,
                ))
            ? null
            : _buildFloatingActionButton(folderManagementEnabled),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    MediaFilter filter,
  ) {
    final vm = ref.read(libraryViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final isSimpleDisplay = ref.watch(globalSimpleDisplayProvider);
    final viewMode = ref.watch(globalViewModeProvider);
    final isSecretMode = ref.watch(secretModeProvider).value ?? false;
    final menuWidth = (MediaQuery.sizeOf(context).width - 24)
        .clamp(280.0, 344.0)
        .toDouble();

    if (vm.isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonCancel,
          onPressed: () => vm.clearSelection(),
        ),
        LibrarySelectionMenu(
          mode: AppMode.internal,
          actionHandler: _actionHandler,
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: l10n.librarySearchAction,
        onPressed: _startSearch,
      ),
      PopupMenuButton<String>(
        // MainTabPage の戻る処理と同じNavigatorに載せ、閉じる操作を画面遷移へ伝播させない。
        useRootNavigator: true,
        constraints: BoxConstraints.tightFor(width: menuWidth),
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.libraryMoreActions,
        onSelected: (value) => _actionHandler.handleMenuAction(
          value,
          context,
          ref,
          filter,
          AppMode.internal,
        ),
        itemBuilder: (context) => [
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'filter',
            iconData: LibraryActionIcons.filter,
            text: l10n.commonFilter,
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'sort',
            iconData: LibraryActionIcons.sort,
            text: l10n.commonSortSettings,
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'view_mode',
            iconData: viewMode == ViewMode.grid
                ? Icons.view_list
                : Icons.grid_view,
            text: viewMode == ViewMode.grid
                ? l10n.libraryViewModeList
                : l10n.libraryViewModeGrid,
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'simple_display',
            height: 68,
            iconData: Icons.view_compact_outlined,
            text: l10n.librarySimpleDisplayTitle,
            description: isSimpleDisplay
                ? l10n.librarySimpleDisplayOnDescription
                : l10n.librarySimpleDisplayOffDescription,
            trailing: AppMenuToggleIndicator(
              isOn: isSimpleDisplay,
              onLabel: l10n.commonOn,
              offLabel: l10n.commonOff,
            ),
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'catalog_display',
            height: 68,
            icon: const CatalogizeIcon.outlined(),
            text: l10n.libraryCatalogDisplayTitle,
            description: filter.onlyCatalogs
                ? l10n.libraryCatalogDisplayOnDescription
                : l10n.libraryCatalogDisplayOffDescription,
            trailing: AppMenuToggleIndicator(
              isOn: filter.onlyCatalogs,
              onLabel: l10n.commonOn,
              offLabel: l10n.commonOff,
            ),
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'secret_mode',
            height: 68,
            iconData: isSecretMode
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            text: isSecretMode
                ? l10n.librarySecretModeOff
                : l10n.librarySecretModeOn,
            description: l10n.librarySecretModeSubtitle,
            trailing: AppMenuToggleIndicator(
              isOn: isSecretMode,
              onLabel: l10n.commonOn,
              offLabel: l10n.commonOff,
            ),
          ),
          const PopupMenuDivider(),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'tags',
            icon: const CharmIcon(),
            text: l10n.tagManageTitle,
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'archive',
            iconData: Icons.archive_outlined,
            text: l10n.libraryMenuArchive,
          ),
          AppPopupMenuItem.text(
            showSelectionFeedback: false,
            value: 'trash',
            iconData: Icons.delete_outline,
            text: l10n.libraryMenuTrash,
          ),
        ],
      ),
    ];
  }

  /// まだ何も置いていない棚のルート。絞り込み0件やフォルダの中は含めない。
  bool _isBareEmptyLibrary(
    MediaFilter filter,
    bool hasVisibleItems,
    LibraryDiscoveryConditions conditions,
  ) {
    return !hasVisibleItems &&
        filter.parentPath == null &&
        !_isSearching &&
        !conditions.hasConditions;
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    MediaFilter filter,
    LibraryDiscoveryConditions conditions,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (conditions.hasConditions) {
      final notifier = ref.read(
        mediaFilterNotifierProvider(AppMode.internal).notifier,
      );
      return LibraryDiscoveryEmptyState(
        conditions: conditions,
        onSearchEntireLibrary: () => notifier.updateSearchWithinParent(false),
        onIncludeFiles: () => conditions.hasQuery
            ? notifier.updateSearchTarget(SearchTarget.filesIncluded)
            : notifier.updateOnlyCatalogs(false),
        onClearFilters: notifier.clearFilterConditions,
        onClearSearch: _clearSearch,
        onClearAll: _clearSearchAndFilters,
      );
    }

    if (_isSearching) {
      return EmptyStateWidget(
        icon: Icons.search_rounded,
        title: l10n.librarySearchPromptTitle,
        subtitle: l10n.librarySearchPromptDescription,
        iconColor: theme.colorScheme.primary.withValues(alpha: 0.6),
      );
    }

    final isRoot = filter.parentPath == null;
    if (isRoot) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: AppIconSize.emptyState,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
                AppSpacing.gapVerticalLg,
                AppText(
                  l10n.libraryImportGuidanceTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapVerticalSm,
                AppFormattedText(
                  l10n.libraryImportGuidanceMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapVerticalLg,
                LibraryImportButton.folder(
                  key: const ValueKey('empty-library-add-folder'),
                  onPressed: () => _actionHandler.handleAddAction(
                    'import_folder',
                    context,
                    ref,
                  ),
                ),
                AppSpacing.gapVerticalSm,
                LibraryImportButton.file(
                  key: const ValueKey('empty-library-add'),
                  onPressed: () => _actionHandler.handleAddAction(
                    'import_file',
                    context,
                    ref,
                  ),
                ),
                TextButton(
                  key: const ValueKey('empty-library-new-folder'),
                  onPressed: () =>
                      _actionHandler.handleAddAction('folder', context, ref),
                  child: Text(l10n.libraryCreateNewFolder),
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => PagedDialog(
                        title: l10n.librarySupportedFormatsTitle,
                        pages: [
                          ScrollableDialogPage(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  l10n.librarySupportedFormatsPage1Title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AppSpacing.gapVerticalMd,
                                AppFormattedText(
                                  l10n.librarySupportedFormatsPage1Content,
                                ),
                              ],
                            ),
                          ),
                          ScrollableDialogPage(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  l10n.librarySupportedFormatsPage2Title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AppSpacing.gapVerticalMd,
                                AppFormattedText(
                                  l10n.librarySupportedFormatsPage2Content,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(l10n.libraryViewSupportedFormats),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return EmptyStateWidget(
      icon: Icons.folder_open_outlined,
      title: l10n.libraryEmptyMessage,
      subtitle: l10n.libraryEmptyFolderDesc,
      iconColor: theme.colorScheme.primary.withValues(alpha: 0.5),
      action: FilledButton.icon(
        key: const ValueKey('empty-folder-add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.commonAdd),
        onPressed: _showAddMenu,
      ),
    );
  }

  Widget? _buildFloatingActionButton(bool folderManagementEnabled) {
    if (!folderManagementEnabled) return null;

    // Scroll-driven visibility must not rebuild the library and its rows.
    return Consumer(
      builder: (context, ref, child) {
        if (!ref.watch(libraryFabVisibilityProvider)) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.libraryAddFiles,
          onPressed: _showAddMenu,
          child: const Icon(Icons.add),
        );
      },
    );
  }
}
