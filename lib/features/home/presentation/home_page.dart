import '../../library/presentation/helpers/library_action_handler.dart';
import '../../library/presentation/widgets/library_import_button.dart';
import 'dart:async';
import 'providers/personal_library_state_provider.dart';
import 'widgets/last_opened_file_card.dart';
import 'widgets/recent_history_widgets.dart';
import 'widgets/recent_collection_card.dart';
import '../../library/domain/models/recently_opened_file.dart';
import '../../library/presentation/providers/viewing_history_provider.dart';
import '../../samples/presentation/sample_preview_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:path/path.dart' as p;

import '../../../core/error/app_error.dart';
import '../../../core/error/error_boundary.dart';
import '../../../core/error/error_display_service.dart';
import '../../../core/feedback/feedback_providers.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/logger/log_tag.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../core/utils/tab_navigator.dart';
import '../../settings/presentation/settings_page.dart';
import '../../library/presentation/widgets/collection_card.dart';
import '../../library/presentation/widgets/collection_action_sheet.dart';
import '../../library/presentation/widgets/file_action_sheet.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/sheets/app_bottom_sheet.dart';
import 'providers/home_library_items_provider.dart';
import 'providers/favorite_collections_provider.dart';
import 'providers/recently_viewed_collections_provider.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/providers/tab_navigation_provider.dart';
import '../../../core/providers/tutorial_providers.dart';
import '../../../shared/widgets/tutorial/tutorial_catalog.dart';
import '../../../shared/widgets/tutorial/tutorial_overlay.dart';
import '../../library/domain/models/collection.dart';
import '../../library/presentation/providers/media_filter_provider.dart';
import '../../library/presentation/widgets/library_mode_title.dart';
import '../../settings/presentation/providers/app_mode_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _actionHandler = const LibraryActionHandler();

  Widget _importActions() => _HomeImportActions(
    onImportFolder: () =>
        _actionHandler.handleAddAction('import_folder', context, ref),
    onImportFile: () =>
        _actionHandler.handleAddAction('import_file', context, ref),
  );

  void _listenAsyncError<T>(
    BuildContext context,
    ProviderListenable<AsyncValue<T>> provider,
    String sectionName,
  ) {
    ref.listen<AsyncValue<T>>(provider, (previous, next) {
      if (!next.hasError || !context.mounted) return;
      final error = next.error;
      final appError = error is AppError
          ? error.withContext('HomePage.$sectionName')
          : AppError.unknown(
              error.toString(),
              original: error,
              stackTrace: next.stackTrace,
              context: 'HomePage.$sectionName',
            );

      ErrorDisplayService.show(context, appError, ref: ref);
    });
  }

  void _listenHomeSectionErrors(BuildContext context) {
    _listenAsyncError(
      context,
      favoriteCollectionsProvider,
      'favoriteCollectionsProvider',
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(recentlyOpenedFilesProvider);
    ref.invalidate(homeLibraryItemsProvider);
    ref.invalidate(recentlyViewedCollectionsProvider);
    ref.invalidate(favoriteCollectionsProvider);

    try {
      await Future.wait([
        ref.read(recentlyOpenedFilesProvider.future),
        ref.read(homeLibraryItemsProvider.future),
        ref.read(recentlyViewedCollectionsProvider.future),
        ref.read(favoriteCollectionsProvider.future),
      ]);
    } catch (_) {
      // エラーログや通知は _listenHomeSectionErrors で補獲されるため無視
    }
  }

  Widget _sampleEntry(BuildContext context) {
    return SliverToBoxAdapter(
      child: _SampleEntry(onPressed: () => _showSamples(context)),
    );
  }

  Future<void> _showSamples(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (sampleContext) => SamplePreviewScreen(
          onAddFiles: () {
            Navigator.of(sampleContext).pop();
            ref
                .read(pendingLibraryLaunchActionProvider.notifier)
                .requestImportFile();
            ref.read(currentTabIndexProvider.notifier).goToLibrary();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final libraryItemsAsync = ref.watch(homeLibraryItemsProvider);
    final personalState = ref.watch(personalLibraryStateProvider);
    _listenHomeSectionErrors(context);
    ref.listen(appModeProvider, (prev, next) {
      if (prev == next) return;
      AppLogger.i(LogTag.navigation, 'ホームモード切替: ${prev?.name} -> ${next.name}');
    });

    final page = Scaffold(
      body: ErrorBoundary(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              PremiumSliverAppBar(
                inlineTitle: true,
                title: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/icon/private_shelf_icon.svg',
                      width: AppIconSize.xl,
                      height: AppIconSize.xl,
                    ),
                    AppSpacing.gapHorizontalSm,
                    Flexible(
                      child: LibraryModeTitle(
                        title: l10n.appTitle,
                        showTitle: true,
                        titleGradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: l10n.settingsTitle,
                    onPressed: () =>
                        TabNavigator.push(context, const SettingsPage()),
                  ),
                ],
              ),
              const SliverPadding(padding: AppSpacing.verticalXs),
              SliverToBoxAdapter(
                child: RecentHistorySection<RecentlyOpenedFile>(
                  title: l10n.homeLastOpenedTitle,
                  icon: const Icon(Icons.history),
                  provider: recentlyOpenedFilesProvider,
                  listProvider: recentFilesHistoryProvider,
                  itemBuilder: (_, entry) => LastOpenedFileCard(
                    key: ValueKey(entry.item.uid ?? entry.item.path),
                    entry: entry,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RecentHistorySection<MediaCollection>(
                  title: l10n.homeRecentlyViewedTitle,
                  icon: const CatalogizeIcon(),
                  provider: recentlyViewedCollectionsProvider,
                  listProvider: recentCollectionsHistoryProvider,
                  itemBuilder: (context, collection) => RecentCollectionCard(
                    key: ValueKey(collection.path),
                    collection: collection,
                    onTap: () => _handleCollectionTap(context, ref, collection),
                    onActions: () => _showCollectionActions(
                      context,
                      ref,
                      collection: collection,
                    ),
                  ),
                ),
              ),
              ...libraryItemsAsync.when(
                data: (items) {
                  final showStarter =
                      items.isEmpty ||
                      personalState.value?.showFirstImportGuide == true;
                  final sampleEntry = _sampleEntry(context);
                  return [
                    if (showStarter) ...[
                      SliverToBoxAdapter(
                        child: _HomeStarterGuide(
                          isFirstImport:
                              personalState.value?.hasImported != true,
                          importActions: _importActions(),
                        ),
                      ),
                      if (items.isNotEmpty)
                        SliverToBoxAdapter(
                          child: TextButton(
                            onPressed: () => dismissPersonalImportGuide(ref),
                            child: Text(l10n.homeDismissStarter),
                          ),
                        ),
                      sampleEntry,
                    ],
                    if (!showStarter)
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: _importActions(),
                            ),
                          ),
                        ),
                      ),
                    if (items.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _CollectionSection(
                          icon: const Icon(Icons.favorite),
                          iconColorType: _HomeIconColorType.error,
                          titleKey: _HomeSectionTitle.favorite,
                          provider: favoriteCollectionsProvider,
                        ),
                      ),
                      const SliverPadding(padding: AppSpacing.verticalXl),
                    ],
                    if (!showStarter) sampleEntry,
                  ];
                },
                loading: () => [
                  const SliverLoadingWidget(),
                  _sampleEntry(context),
                ],
                error: (e, st) {
                  final appError = e is AppError
                      ? e
                      : AppError.ui(
                          l10n.commonErrorOccurred,
                          original: e,
                          stackTrace: st,
                          context: 'HomePage.build',
                        );
                  return [
                    SliverErrorStateWidget(
                      error: appError,
                      onRetry: _onRefresh,
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );

    final review = ref.watch(tutorialReviewRequestProvider);
    if (review?.id != TutorialIds.home) return page;
    return TutorialOverlay(
      preview: true,
      tutorialId: TutorialIds.home,
      steps: homeTutorialSteps(l10n),
      onPreviewDismissed: () {
        ref.read(tutorialReviewRequestProvider.notifier).clear();
      },
      child: page,
    );
  }
}

const double _kCollectionCardAspectRatio = 0.82;

enum _HomeSectionTitle { recentlyViewed, favorite }

enum _HomeIconColorType { primary, error }

class _CollectionSection extends ConsumerStatefulWidget {
  const _CollectionSection({
    required this.icon,
    required this.titleKey,
    required this.provider,
    this.iconColorType = _HomeIconColorType.primary,
  });

  final Widget icon;
  final _HomeSectionTitle titleKey;
  final ProviderListenable<AsyncValue<List<MediaCollection>>> provider;
  final _HomeIconColorType iconColorType;

  @override
  ConsumerState<_CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends ConsumerState<_CollectionSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionsAsync = ref.watch(widget.provider);

    final collections = collectionsAsync.value;
    if (collectionsAsync.isLoading && collections == null) {
      return const SizedBox.shrink();
    }
    if (collections != null && collections.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = collections?.length;
    final showSeeMore = count != null && count > _maxDisplayCount;
    final title = _title(l10n);
    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _SectionTitle(
                icon: widget.icon,
                title: title,
                count: count,
                iconColor: widget.iconColorType == _HomeIconColorType.error
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            if (showSeeMore)
              TextButton.icon(
                onPressed: () {
                  TabNavigator.push(
                    context,
                    _CollectionCatalogListPage(
                      titleKey: widget.titleKey,
                      provider: widget.provider,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: AppIconSize.sm,
                ),
                label: AppText(l10n.homeSeeMore),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        collectionsAsync.when(
          data: (items) {
            final displayItems = items
                .take(_maxDisplayCount)
                .toList(growable: false);

            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(16) / 16;
                      final availableWidth =
                          constraints.maxWidth - (AppSpacing.md * 2);
                      final minimumCardWidth = textScale >= 1.6 ? 190.0 : 132.0;
                      final columnCount = (availableWidth / minimumCardWidth)
                          .floor()
                          .clamp(1, 3);
                      final aspectRatio = textScale >= 1.6
                          ? 0.7
                          : _kCollectionCardAspectRatio;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final collection = displayItems[index];
                          return RepaintBoundary(
                            child: CollectionCard(
                              collection: collection,
                              onTap: () => _handleCollectionTap(
                                context,
                                ref,
                                collection,
                              ),
                              onLongPress: () => _showCollectionActions(
                                context,
                                ref,
                                collection: collection,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, st) => _SectionErrorState(
            onRetry: () {
              switch (widget.titleKey) {
                case _HomeSectionTitle.recentlyViewed:
                  ref.invalidate(recentlyViewedCollectionsProvider);
                case _HomeSectionTitle.favorite:
                  ref.invalidate(favoriteCollectionsProvider);
              }
            },
          ),
        ),
      ],
    );
  }

  int get _maxDisplayCount =>
      widget.titleKey == _HomeSectionTitle.recentlyViewed ? 3 : 9;

  String _title(AppLocalizations l10n) {
    return switch (widget.titleKey) {
      _HomeSectionTitle.recentlyViewed => l10n.homeRecentlyViewedTitle,
      _HomeSectionTitle.favorite => l10n.homeFavoriteCollectionsTitle,
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.count,
  });

  final Widget icon;
  final String title;
  final Color iconColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = count != null && count! > 0 ? '$title ($count)' : title;
    return Row(
      children: [
        IconTheme.merge(
          data: IconThemeData(size: AppIconSize.md, color: iconColor),
          child: icon,
        ),
        AppSpacing.gapHorizontalSm,
        Expanded(
          child: AppText(
            label,
            maxLines: 2,
            minFontSize: 14,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// ホームの「さらに見る」から開くカタログ一覧。
class _CollectionCatalogListPage extends ConsumerWidget {
  const _CollectionCatalogListPage({
    required this.titleKey,
    required this.provider,
  });

  final _HomeSectionTitle titleKey;
  final ProviderListenable<AsyncValue<List<MediaCollection>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionsAsync = ref.watch(provider);
    final title = titleKey == _HomeSectionTitle.favorite
        ? l10n.homeFavoriteCollectionsTitle
        : l10n.homeRecentlyViewedTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: collectionsAsync.when(
        data: (collections) => collections.isEmpty
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(16) / 16;
                  final minimumCardWidth = textScale >= 1.6 ? 190.0 : 132.0;
                  final columnCount = (constraints.maxWidth / minimumCardWidth)
                      .floor()
                      .clamp(1, 3);
                  return GridView.builder(
                    padding: AppSpacing.edgeInsetsMd,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: textScale >= 1.6
                          ? 0.7
                          : _kCollectionCardAspectRatio,
                    ),
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return CollectionCard(
                        collection: collection,
                        onTap: () =>
                            _handleCollectionTap(context, ref, collection),
                        onLongPress: () => _showCollectionActions(
                          context,
                          ref,
                          collection: collection,
                        ),
                      );
                    },
                  );
                },
              ),
        loading: () => const Center(child: LoadingWidget(compact: true)),
        error: (error, stack) =>
            Center(child: AppText(l10n.commonErrorOccurred)),
      ),
    );
  }
}

class _SectionErrorState extends StatelessWidget {
  const _SectionErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: AppSpacing.edgeInsetsMd,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              l10n.commonErrorOccurred,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            AppSpacing.gapHorizontalXs,
            IconButton(
              icon: const Icon(Icons.refresh, size: AppIconSize.md),
              tooltip: l10n.commonRetry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _triggerTapHaptics(WidgetRef ref) async {
  await ref.read(feedbackServiceProvider).lightImpact();
}

Future<void> _triggerLongPressHaptics(WidgetRef ref) async {
  await ref.read(feedbackServiceProvider).mediumImpact();
}

Future<void> _handleCollectionTap(
  BuildContext context,
  WidgetRef ref,
  MediaCollection collection,
) async {
  await _triggerTapHaptics(ref);
  if (!context.mounted) return;

  try {
    final mode = collection.isExternal ? AppMode.external : AppMode.internal;
    await ref.read(appModeAsyncProvider.notifier).setMode(mode);
    if (!context.mounted) return;

    if (collection.type == CollectionType.file) {
      final parentDir = p.dirname(collection.path);
      ref
          .read(mediaFilterNotifierProvider(mode).notifier)
          .updateParentPath(parentDir == '.' ? null : parentDir);
    } else {
      ref
          .read(mediaFilterNotifierProvider(mode).notifier)
          .updateParentPath(collection.path);
    }

    if (ModalRoute.of(context)?.settings.name == '/home/recent-history') {
      Navigator.of(context).pop();
    }
    ref.read(currentTabIndexProvider.notifier).goToLibrary();
    AppLogger.i(LogTag.navigation, 'ホームからコレクションへ遷移: ${collection.path}');
  } catch (error, stack) {
    AppLogger.e(LogTag.navigation, 'コレクション遷移に失敗', error, stack);
    if (!context.mounted) return;

    final appError = error is AppError
        ? error.withContext('HomePage.handleCollectionTap')
        : AppError.ui(
            'ホーム画面でコレクション遷移に失敗しました',
            severity: ErrorSeverity.warning,
            original: error,
            stackTrace: stack,
            context: 'HomePage.handleCollectionTap',
          );
    ErrorDisplayService.show(context, appError, ref: ref);
  }
}

Future<void> _showCollectionActions(
  BuildContext context,
  WidgetRef ref, {
  required MediaCollection collection,
}) async {
  await _triggerLongPressHaptics(ref);
  if (!context.mounted) return;

  try {
    await showAppBottomSheet(
      context,
      showCloseButton: true,
      child: collection.favoriteItem != null
          ? FileActionSheet(item: collection.favoriteItem!)
          : CollectionActionSheet(
              collectionPath: collection.path,
              initialTitle: collection.alias ?? collection.title,
            ),
    );
  } catch (error, stack) {
    AppLogger.e(LogTag.ui, 'コレクションアクション表示に失敗', error, stack);
    if (!context.mounted) return;

    final appError = error is AppError
        ? error.withContext('HomePage.showCollectionActions')
        : AppError.ui(
            'ホーム画面でコレクションアクション表示に失敗しました',
            severity: ErrorSeverity.warning,
            original: error,
            stackTrace: stack,
            context: 'HomePage.showCollectionActions',
          );
    ErrorDisplayService.show(context, appError, ref: ref);
  }
}

class _SampleEntry extends StatelessWidget {
  const _SampleEntry({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.auto_stories_outlined),
          label: Text(AppLocalizations.of(context)!.homeTrySamples),
        ),
      ),
    );
  }
}

class _HomeStarterGuide extends StatelessWidget {
  final bool isFirstImport;
  const _HomeStarterGuide({
    required this.importActions,
    this.isFirstImport = true,
  });

  final Widget importActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: AppIconSize.emptyState,
                color: Theme.of(context).colorScheme.primary,
              ),
              AppSpacing.gapVerticalLg,
              AppText(
                isFirstImport ? l10n.homeGuideTitle : l10n.homeAddMoreFiles,
                key: const ValueKey('home-starter-title'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
                maxLines: 3,
                minFontSize: 16,
                wrapWords: false,
              ),
              AppSpacing.gapVerticalSm,
              AppText(l10n.homeFirstImportMessage, textAlign: TextAlign.center),
              AppSpacing.gapVerticalLg,
              importActions,
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeImportActions extends StatelessWidget {
  const _HomeImportActions({
    required this.onImportFolder,
    required this.onImportFile,
  });

  final VoidCallback onImportFolder;
  final VoidCallback onImportFile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LibraryImportButton.folder(
        key: const ValueKey('home-add-folders'),
        onPressed: onImportFolder,
      ),
      AppSpacing.gapVerticalSm,
      LibraryImportButton.file(
        key: const ValueKey('home-add-files'),
        onPressed: onImportFile,
      ),
    ],
  );
}
