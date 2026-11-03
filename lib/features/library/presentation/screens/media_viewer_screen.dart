import 'package:private_shelf/core/performance/interaction_trace.dart';

import 'dart:io';
import 'dart:async';

import '../providers/catalog_viewer_items_provider.dart';

import 'package:private_shelf/shared/widgets/feedback/deferred_progress_bar.dart';

import '../helpers/viewer_history_gate.dart';
import '../providers/viewing_history_provider.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_page.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/presentation/widgets/video_player_view.dart';
import 'package:private_shelf/features/library/presentation/widgets/audio_player_view.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/widgets/text_viewer.dart';
import 'package:private_shelf/features/library/presentation/widgets/pdf_viewer.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';

import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/helpers/media_viewer_action_helper.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/light_swipe_page_scroll_physics.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_image_viewer.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_bottom_overlay.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_item_action_buttons.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_player_overlay.dart';
import 'package:private_shelf/features/library/presentation/widgets/player_common_widgets.dart';
import 'package:private_shelf/features/library/presentation/utils/image_cache_helper.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/unsupported_file_view.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_preload_coordinator.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_image_cache_lease.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_session_topology.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

import '../../domain/models/import_preview_source.dart';

class MediaViewerScreen extends ConsumerStatefulWidget {
  final int? initialItemId;
  final MediaItem? initialItem;
  final ViewerSourceContext? sourceContext;
  final bool embeddedInOverlay;
  final bool _previewOnly;
  bool get previewOnly => _previewOnly || initialItem?.isImportPreview == true;

  const MediaViewerScreen({
    super.key,
    this.initialItemId,
    this.initialItem,
    this.sourceContext,
    this.embeddedInOverlay = false,
    this._previewOnly = false,
  }) : assert(
         initialItemId != null || initialItem != null,
         'Either initialItemId or initialItem must be provided',
       );

  factory MediaViewerScreen.preview({
    Key? key,
    required ImportPreviewSource source,
  }) => MediaViewerScreen(
    key: key,
    initialItem: source.toViewerItem(),
    previewOnly: true,
  );

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  PageController? _pageController;
  Drag? _forwardedPageDrag;
  late int _currentIndex;
  late int _pendingPageIndex;
  MediaItem? _currentItem;
  late final ViewerHistoryGate _historyGate = ViewerHistoryGate((
    item,
    openedAt,
  ) {
    if (!widget.previewOnly) unawaited(_recordOpenedFile(item, openedAt));
  });

  bool _initialized = false;
  List<MediaItem>? _sessionInputItems;
  List<MediaItem> _sessionEffectiveItems = const [];
  List<ViewerPage> _sessionPages = const [];
  ViewerSessionTopology? _sessionTopology;
  Map<int, int> _sessionFileIndexById = const {};
  ViewerPagesParam? _sessionPagesParam;
  int _sessionGeneration = 0;
  int _lastSettledSessionGeneration = -1;
  int _pageFocusGeneration = 0;
  int _lastSettledFocusGeneration = -1;
  int _playRequestGeneration = 0;
  bool _hasPendingAspectPageRefresh = false;
  bool _startedPlaybackInStandaloneViewer = false;
  final Object _playbackOwner = Object();
  int? _imagePreloadTargetLimit;
  DateTime? _lastBackHandledAt;
  static const Duration _backHandlingCooldown = Duration(milliseconds: 700);

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

  PlayerNotifier? _playerNotifier;
  Timer? _pageSettleTimer;
  bool _isPageScrolling = false;
  final ViewerPreloadCoordinator _preloadCoordinator = ViewerPreloadCoordinator(
    maxConcurrent: 1,
  );

  @override
  void initState() {
    super.initState();
    _currentItem = widget.initialItem;
    _currentIndex = 0;
    _pendingPageIndex = 0;

    ViewerImageCacheLease.acquire();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playerNotifier = ref.read(playerNotifierProvider.notifier);

    final targetLimit = calculateTargetImageLimit(context);
    final previousTargetLimit = _imagePreloadTargetLimit;
    _imagePreloadTargetLimit = targetLimit;
    if (_initialized &&
        previousTargetLimit != null &&
        previousTargetLimit != targetLimit) {
      // ResizeImage keys include the decode target. Drop pending work for the
      // old display metrics and prepare the settled neighborhood again after
      // widgets have rebuilt with the new MediaQuery.
      _preloadCoordinator.cancelPending();
      final settledIndex = _lastSettledIndex;
      if (settledIndex != null) {
        _scheduleNearbyPreparation(_sessionPages, settledIndex);
      }
    }
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _playRequestGeneration++;
    _cancelForwardedPageDrag();
    _pageSettleTimer?.cancel();
    _preloadCoordinator.dispose();
    if (!widget.embeddedInOverlay && _startedPlaybackInStandaloneViewer) {
      final playerNotifier = _playerNotifier;
      final playbackOwner = _playbackOwner;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.previewOnly) {
          unawaited(playerNotifier?.stop(owner: playbackOwner));
        } else {
          playerNotifier?.minimizeToMiniPlayer(owner: playbackOwner);
        }
      });
    }
    _pageController?.dispose();
    _singleTapTimer?.cancel();
    ViewerImageCacheLease.release();

    super.dispose();
  }

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  int _activePointerCount = 0;
  Timer? _singleTapTimer;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  void _handlePointerDown(PointerDownEvent event) {
    _activePointerCount++;
    if (_activePointerCount == 1) {
      _pointerDownPosition = event.position;
      _pointerDownTime = DateTime.now();
    } else {
      _singleTapTimer?.cancel();
      _pointerDownPosition = null;
      _pointerDownTime = null;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final downPos = _pointerDownPosition;
    if (downPos != null && (event.position - downPos).distance > 18.0) {
      _pointerDownPosition = null;
      _pointerDownTime = null;
      _singleTapTimer?.cancel();
    }
  }

  void _handlePointerUp(
    PointerUpEvent event, {
    required bool isImage,
    bool handlesOwnTaps = false,
  }) {
    _activePointerCount = (_activePointerCount - 1).clamp(0, 99);
    final downPos = _pointerDownPosition;
    final downTime = _pointerDownTime;
    _pointerDownPosition = null;
    _pointerDownTime = null;
    // PDF links and selection have their own tap classification. Observing the
    // raw pointer here would also toggle controls for a consumed annotation tap.
    if (handlesOwnTaps) return;

    if (downPos != null && downTime != null && _activePointerCount == 0) {
      final elapsed = DateTime.now().difference(downTime);
      final distance = (event.position - downPos).distance;

      if (elapsed < const Duration(milliseconds: 350) && distance < 18.0) {
        _processScreenTap(event.position, isImage: isImage);
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointerCount = (_activePointerCount - 1).clamp(0, 99);
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _singleTapTimer?.cancel();
  }

  void _processScreenTap(Offset position, {required bool isImage}) {
    final showControls = ref.read(mediaViewerViewModelProvider).showControls;

    if (showControls) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      final topThreshold =
          MediaQuery.paddingOf(context).top + kToolbarHeight + 60;
      final bottomReserve = isImage
          ? 120
          : (_currentItem != null &&
                (_currentItem!.isVideo || _currentItem!.isAudio))
          ? kPlayerBottomTapGuard
          : 120;
      final bottomThreshold =
          screenHeight - (MediaQuery.paddingOf(context).bottom + bottomReserve);
      if (position.dy < topThreshold || position.dy > bottomThreshold) {
        return;
      }
    }

    if (!isImage) {
      _toggleControls();
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastTapTime;
    final lastPos = _lastTapPosition;
    _lastTapTime = now;
    _lastTapPosition = position;

    if (lastTime != null &&
        lastPos != null &&
        now.difference(lastTime) < const Duration(milliseconds: 280) &&
        (position - lastPos).distance < 40.0) {
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      return;
    }

    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _toggleControls();
      }
    });
  }

  void _toggleControls() {
    ref.read(mediaViewerViewModelProvider.notifier).toggleControls();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleClosePressed();
      },
      child: Theme(
        data: AppTheme.dark,
        child: Builder(
          builder: (context) {
            final effectiveItem = _currentItem ?? widget.initialItem;
            if (effectiveItem == null) {
              final targetId = widget.initialItemId;
              if (targetId == null) {
                return _buildLoadingScaffold(context);
              }
              final asyncItem = ref.watch(mediaItemProvider(targetId));
              return asyncItem.when(
                loading: () => _buildLoadingScaffold(context),
                error: (err, _) => _buildErrorScaffold(context, err),
                data: (item) {
                  if (item == null) {
                    return _buildErrorScaffold(context, 'Media item not found');
                  }
                  _currentItem = item;
                  return _resolveViewerContent(context, item);
                },
              );
            }
            return _resolveViewerContent(context, effectiveItem);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, Object err) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Text(
          userSafeErrorMessage(err, AppLocalizations.of(context)!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _resolveViewerContent(BuildContext context, MediaItem item) {
    if (!widget.previewOnly &&
        item.sourceType == MediaSourceType.externalReference) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.referenceMigrationDescription,
          ),
        ),
      );
    }
    if (widget.previewOnly) {
      final previews = widget.sourceContext?.customItems;
      return _buildViewerBody(
        context,
        previews != null &&
                previews.isNotEmpty &&
                previews.every((entry) => entry.isImportPreview)
            ? previews
            : [item],
      );
    }

    final sourceContext = widget.sourceContext;
    if (sourceContext != null) {
      switch (sourceContext.kind) {
        case ViewerSourceKind.recent:
          final recentAsync = ref.watch(recentMediaProvider);
          return recentAsync.when(
            loading: () => _buildLoadingScaffold(context),
            error: (err, _) => _buildErrorScaffold(context, err),
            data: (items) =>
                _buildViewerBody(context, items.isNotEmpty ? items : [item]),
          );
        case ViewerSourceKind.catalog:
          final filter = sourceContext.catalogFilter;
          if (filter != null) {
            final pending = ref.watch(catalogViewerItemsProvider(filter));
            return _buildViewerBody(
              context,
              pending.value ?? sourceContext.customItems ?? [item],
              sourcePending: !pending.hasValue,
              sourceError: pending.hasError && !pending.isLoading,
              onRetrySource: () =>
                  ref.invalidate(catalogViewerItemsProvider(filter)),
            );
          }
          return _buildViewerBody(context, sourceContext.customItems ?? [item]);
        case ViewerSourceKind.customList:
          final items = sourceContext.customItems ?? [item];
          return _buildViewerBody(context, items);
        case ViewerSourceKind.single:
          return _buildViewerBody(context, [item]);
        case ViewerSourceKind.folder:
          if (sourceContext.appMode == AppMode.external ||
              item.requiresSourceAccess) {
            return _buildExternalViewer(
              context,
              parentPath: sourceContext.parentPath ?? item.parentPath,
            );
          }
          return _buildInternalViewer(context);
        case ViewerSourceKind.favorites:
        case ViewerSourceKind.tag:
          return _buildInternalViewer(context);
      }
    }

    final isExternal = item.requiresSourceAccess;
    if (isExternal) {
      return _buildExternalViewer(context, parentPath: item.parentPath);
    }
    return _buildInternalViewer(context);
  }

  Widget _buildExternalViewer(BuildContext context, {String? parentPath}) {
    final folderItemsAsync = ref.watch(externalFolderItemsProvider(parentPath));

    return folderItemsAsync.when(
      loading: () => _buildLoadingScaffold(context),
      error: (err, _) => _buildErrorScaffold(context, err),
      data: (items) => _buildViewerBody(context, items),
    );
  }

  Widget _buildInternalViewer(BuildContext context) {
    final mediaListAsync = ref.watch(libraryViewModelProvider);

    return mediaListAsync.when(
      loading: () => _buildLoadingScaffold(context),
      error: (err, stack) => _buildErrorScaffold(context, err),
      data: (items) => _buildViewerBody(context, items),
    );
  }

  void _ensureViewerSession(List<MediaItem> items, MediaItem current) {
    final previousItems = _sessionInputItems;
    if (_initialized && identical(previousItems, items)) {
      return;
    }

    final fileItems = items
        .where((item) => item.type == MediaType.file)
        .toList(growable: false);
    final containsCurrent = fileItems.any((item) => item.id == current.id);
    final effectiveItems = containsCurrent ? fileItems : <MediaItem>[current];
    final topology = ViewerSessionTopology.capture(
      effectiveItems,
      splitSpreadResolver: (item) {
        final linkedCollection = item.collection.value;
        if (linkedCollection != null) return linkedCollection.splitSpreadView;
        final collectionPath = item.parentPath ?? item.path;
        return ref
                .read(collectionNotifierProvider(collectionPath))
                .asData
                ?.value
                ?.splitSpreadView ??
            false;
      },
    );
    if (_initialized && previousItems != null && topology == _sessionTopology) {
      // Metadata writes may allocate a new source list even though the visible
      // pages are identical. Preserve PageView and its decoded child elements.
      _sessionInputItems = items;
      return;
    }
    final pagesParam = ViewerPagesParam(
      effectiveItems,
      sourceContext: widget.sourceContext,
    );
    final pages = ref.read(viewerPagesProvider(pagesParam));
    final targetIndex = _findInitialPageIndex(pages, current.id);
    final isFirstSession = !_initialized;
    final generation = ++_sessionGeneration;
    _historyGate.beginSession(
      generation,
      preserveCurrent:
          widget.sourceContext?.catalogFilter != null &&
              previousItems?.length == 1 &&
              containsCurrent
          ? current
          : null,
    );

    _preloadCoordinator.cancelPending();
    _sessionInputItems = items;
    _sessionEffectiveItems = effectiveItems;
    _sessionPages = pages;
    _sessionTopology = topology;
    _sessionPagesParam = pagesParam;
    _sessionFileIndexById = {
      for (var index = 0; index < effectiveItems.length; index++)
        effectiveItems[index].id: index,
    };
    _lastAspectPreloadedFileIndex = null;
    _previousPreloadIndex = null;
    _currentIndex = targetIndex;
    _pendingPageIndex = targetIndex;
    _pageFocusGeneration++;
    _hasPendingAspectPageRefresh = false;
    if (pages.isNotEmpty) _currentItem = pages[targetIndex].item;
    _initialized = true;

    if (!isFirstSession &&
        widget.sourceContext?.catalogFilter != null &&
        previousItems?.length == 1 &&
        targetIndex != 0) {
      // Install the anchored controller before this frame, not in a later jump.
      final oldController = _pageController;
      _pageController = PageController(
        initialPage: targetIndex,
        keepPage: false,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => oldController?.dispose(),
      );
    }
    if (isFirstSession) {
      // The controller is created only after the real source list is known, so
      // Flutter never builds page 0 and jumps to the requested file afterward.
      _pageController = PageController(initialPage: targetIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _sessionGeneration ||
          !identical(pages, _sessionPages) ||
          pages.isEmpty) {
        return;
      }
      final controller = _pageController;
      if (!isFirstSession &&
          controller != null &&
          controller.hasClients &&
          (controller.page?.round() ?? targetIndex) != targetIndex) {
        controller.jumpToPage(targetIndex);
      }
      _settlePageWork(pages, targetIndex);
    });
  }

  Widget _buildViewerBody(
    BuildContext context,
    List<MediaItem> items, {
    bool sourcePending = false,
    bool sourceError = false,
    VoidCallback? onRetrySource,
  }) {
    final pageDirection = ref.watch(viewerPageDirectionProvider);
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final current =
        _currentItem ??
        widget.initialItem ??
        (items.isNotEmpty ? items.first : null);
    if (current == null) {
      return _buildLoadingScaffold(context);
    }

    _ensureViewerSession(items, current);
    final effectiveItems = _sessionEffectiveItems;
    final viewerPages = _sessionPages;

    final totalPages = viewerPages.length;
    final l10n = AppLocalizations.of(context)!;

    if (_currentIndex >= 0 && _currentIndex < viewerPages.length) {
      _currentItem = viewerPages[_currentIndex].item;
    } else if (viewerPages.isNotEmpty) {
      _currentItem = viewerPages[0].item;
      _currentIndex = 0;
    } else {
      _currentItem = current;
    }

    final activeItem = _currentItem ?? current;

    final asyncItem = widget.previewOnly
        ? null
        : ref.watch(mediaItemProvider(activeItem.id));
    final currentItemDetail =
        asyncItem?.asData?.value ?? asyncItem?.value ?? activeItem;
    final linkedCollection = currentItemDetail.collection.value;
    final directCollection = widget.previewOnly
        ? null
        : ref.watch(collectionNotifierProvider(activeItem.path)).asData?.value;
    final latestCollection =
        MediaViewerActionHelper.resolveWorkCollectionForItem(
          activeItem,
          linkedCollection: linkedCollection,
          directCollection: directCollection,
        );

    final showControls = ref.watch(
      mediaViewerViewModelProvider.select((s) => s.showControls),
    );

    final currentFileIndex = _sessionFileIndexById[activeItem.id] ?? -1;

    final currentSplitSide =
        _currentIndex >= 0 && _currentIndex < viewerPages.length
        ? viewerPages[_currentIndex].splitSide
        : null;

    final title = latestCollection?.title ?? p.basename(activeItem.path);
    final isPlayer = activeItem.isVideo || activeItem.isAudio;

    final bodyContent = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space):
            _togglePlaybackFromKeyboard,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          _moveToPage(
            viewerPages,
            _currentIndex +
                (pageDirection == ViewerPageDirection.rightToLeft ? 1 : -1),
          );
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          _moveToPage(
            viewerPages,
            _currentIndex +
                (pageDirection == ViewerPageDirection.rightToLeft ? -1 : 1),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: (e) => _handlePointerUp(
            e,
            isImage: activeItem.isImage,
            handlesOwnTaps: activeItem.isPdf,
          ),
          onPointerCancel: _handlePointerCancel,
          child: Stack(
            children: [
              Dismissible(
                key: const Key('media_viewer_dismissible'),
                // ビューアーは縦方向の下スワイプだけで閉じる。PageView の
                // 横スワイプを Dismissible に渡さないことで、ページ送り中の
                // 誤クローズを防ぐ。
                // プレイヤー展開中（embeddedInOverlay）は、コンテンツ側の
                // 下スワイプ閉じとの競合を避けるために無効化する。
                // PDF scrolling and selection handles must own both drag axes.
                // Close PDFs with the close button or the system Back action.
                direction: widget.embeddedInOverlay || activeItem.isPdf
                    ? DismissDirection.none
                    : DismissDirection.down,
                dismissThresholds: const {DismissDirection.down: 0.25},
                resizeDuration: null,
                onDismissed: (_) => _handleClosePressed(),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.previewOnly && activeItem.isPdf
                        ? MediaQuery.paddingOf(context).top + kToolbarHeight
                        : 0,
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) =>
                        _handlePageScrollNotification(
                          viewerPages,
                          notification,
                        ),
                    child: PageView.builder(
                      key: const Key('media_viewer_page_view'),
                      controller: _pageController,
                      reverse: pageDirection == ViewerPageDirection.rightToLeft,
                      allowImplicitScrolling: true,
                      physics: activeItem.isPdf
                          ? const NeverScrollableScrollPhysics(
                              parent: LightSwipePageScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                            )
                          : const LightSwipePageScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                      itemCount: totalPages,
                      onPageChanged: (index) =>
                          _activatePageAt(viewerPages, index),
                      itemBuilder: (context, index) {
                        final page = viewerPages[index];
                        final item = page.item;
                        final isInitialItem =
                            (widget.initialItem?.id ?? widget.initialItemId) ==
                            item.id;
                        final renderHeavyContent =
                            _lastSettledSessionGeneration ==
                                _sessionGeneration &&
                            _lastSettledIndex == index;
                        final historyGeneration = _sessionGeneration;
                        void onContentReady() {
                          if (!mounted || widget.previewOnly) return;
                          if (index == _currentIndex && !_isPageScrolling) {
                            InteractionTrace.finish('catalog_first_content');
                          }
                          _historyGate.loaded(
                            item,
                            generation: historyGeneration,
                          );
                        }

                        final pageKey = ValueKey(
                          'viewer-page-${item.id}-${page.splitSide?.name ?? 'full'}',
                        );

                        return RepaintBoundary(
                          key: pageKey,
                          child: Builder(
                            builder: (context) {
                              if (item.requiresSourceAccess) {
                                return _buildExternalFileView(
                                  context,
                                  item,
                                  isInitialItem: isInitialItem,
                                  renderHeavyContent: renderHeavyContent,
                                  onContentReady: onContentReady,
                                );
                              }

                              final file = File(p.join(docsPath, item.path));
                              if (!renderHeavyContent &&
                                  (item.isVideo || item.isAudio)) {
                                return ColoredBox(
                                  color: Theme.of(context).appColors.overlay,
                                );
                              }

                              if (item.isDirectlyViewableImage) {
                                return MediaImageViewer(
                                  file: file,
                                  item: item,
                                  splitSide: page.splitSide,
                                  onContentReady: onContentReady,
                                  isInitialHero:
                                      isInitialItem && _currentIndex == index,
                                  onTap: () {},
                                  onUnscaledHorizontalDragStart:
                                      _startForwardedPageDrag,
                                  onUnscaledHorizontalDragUpdate:
                                      _updateForwardedPageDrag,
                                  onUnscaledHorizontalDragEnd:
                                      _endForwardedPageDrag,
                                  onUnscaledHorizontalDragCancel:
                                      _cancelForwardedPageDrag,
                                );
                              }

                              if (!renderHeavyContent) {
                                return ColoredBox(
                                  color: Theme.of(context).appColors.overlay,
                                );
                              } else if (item.isVideo) {
                                return VideoPlayerView(
                                  item: item,
                                  onContentReady: onContentReady,
                                  onClosePressed: _handleClosePressed,
                                );
                              } else if (item.isAudio) {
                                return AudioPlayerView(
                                  item: item,
                                  onContentReady: onContentReady,
                                  onClosePressed: _handleClosePressed,
                                );
                              } else if (item.isText) {
                                return TextViewer(
                                  item: item,
                                  renderContent: renderHeavyContent,
                                  onContentReady: onContentReady,
                                );
                              } else if (item.isPdf) {
                                if (!renderHeavyContent) {
                                  return const ColoredBox(color: Colors.black);
                                }
                                return PdfViewer(
                                  item: item,
                                  onTap: _toggleControls,
                                  onContentReady: onContentReady,
                                  onUnscaledHorizontalDragStart: totalPages > 1
                                      ? _startForwardedPageDrag
                                      : null,
                                  onUnscaledHorizontalDragUpdate: totalPages > 1
                                      ? _updateForwardedPageDrag
                                      : null,
                                  onUnscaledHorizontalDragEnd: totalPages > 1
                                      ? _endForwardedPageDrag
                                      : null,
                                  onUnscaledHorizontalDragCancel: totalPages > 1
                                      ? _cancelForwardedPageDrag
                                      : null,
                                );
                              }

                              return _buildUnsupportedFileView(context, item);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // コントロール・オーバーレイ群
              // Import previews have no library toolbar. Keep an explicit exit
              // when PDF drags cannot dismiss, including on devices without Back.
              if (widget.previewOnly && activeItem.isPdf)
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    minimum: const EdgeInsets.all(8),
                    child: IconButton.filledTonal(
                      key: const Key('media_viewer_pdf_preview_close'),
                      tooltip: l10n.commonClose,
                      onPressed: _handleClosePressed,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              if (showControls && !widget.previewOnly)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).appColors.overlay
                                .withValues(alpha: 0.85),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppBar(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  surfaceTintColor: Colors.transparent,
                                  iconTheme: IconThemeData(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                  actionsIconTheme: IconThemeData(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                  leading: IconButton(
                                    tooltip: l10n.commonClose,
                                    icon: Icon(
                                      widget.embeddedInOverlay
                                          ? Icons.keyboard_arrow_down
                                          : Icons.close,
                                    ),
                                    onPressed: _handleClosePressed,
                                  ),
                                  title: isPlayer
                                      ? null
                                      : Text(
                                          title,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                  actions: [
                                    if (sourceError)
                                      IconButton(
                                        key: const ValueKey(
                                          'catalog-pages-retry',
                                        ),
                                        tooltip: l10n.commonRetry,
                                        icon: const Icon(Icons.refresh),
                                        onPressed: onRetrySource,
                                      ),
                                    if (!isPlayer)
                                      MediaViewerItemActionButtons(
                                        item: currentItemDetail,
                                        sourceContext: widget.sourceContext,
                                        onBackToCatalogContents:
                                            _handleBackToCatalogContents,
                                      ),
                                  ],
                                ),
                                DeferredProgressBar(
                                  key: const ValueKey('catalog-pages-progress'),
                                  active: sourcePending && !sourceError,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isPlayer)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: MediaViewerPlayerOverlay(
                            item: currentItemDetail,
                            title: title,
                            sourceContext: widget.sourceContext,
                            onBackToCatalogContents:
                                _handleBackToCatalogContents,
                          ),
                        )
                      else if (!sourcePending)
                        MediaViewerBottomOverlay(
                          totalPages: totalPages,
                          currentIndex: _currentIndex,
                          totalFiles: effectiveItems.length,
                          currentFileIndex: currentFileIndex,
                          splitSide: currentSplitSide,
                          pageDirection: pageDirection,
                          onPageChanged: (newIndex) =>
                              _moveToPage(viewerPages, newIndex),
                          onPageDirectionChanged: _toggleViewerPageDirection,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).appColors.overlay,
      body: bodyContent,
    );
  }

  Future<void> _toggleViewerPageDirection() async {
    final current = ref.read(viewerPageDirectionProvider);
    await ref
        .read(viewerPageDirectionAsyncProvider.notifier)
        .setValue(
          current == ViewerPageDirection.rightToLeft
              ? ViewerPageDirection.leftToRight
              : ViewerPageDirection.rightToLeft,
        );
  }

  int _findInitialPageIndex(List<ViewerPage> pages, dynamic targetItemId) {
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].item.id == targetItemId) {
        return i;
      }
    }
    return 0;
  }

  Widget _buildExternalFileView(
    BuildContext context,
    MediaItem item, {
    bool isInitialItem = false,
    bool renderHeavyContent = true,
    VoidCallback? onContentReady,
  }) {
    if (!item.isViewableInApp) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleControls,
        child: _buildUnsupportedFileView(context, item),
      );
    }

    if (!renderHeavyContent &&
        (item.isVideo || item.isAudio || item.isText || item.isPdf)) {
      return ColoredBox(color: Theme.of(context).appColors.overlay);
    }

    final previewAsync = ref.watch(externalFilePreviewProvider(item));

    return previewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          userSafeErrorMessage(err, AppLocalizations.of(context)!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (tempPath) {
        if (tempPath == null) {
          return const ViewerStatePanel(kind: ViewerFailureKind.missing);
        }
        final file = File(tempPath);

        if (item.isDirectlyViewableImage) {
          return MediaImageViewer(
            file: file,
            item: item,
            isInitialHero: isInitialItem,
            onContentReady: onContentReady,
            onTap: () {},
            onUnscaledHorizontalDragStart: _startForwardedPageDrag,
            onUnscaledHorizontalDragUpdate: _updateForwardedPageDrag,
            onUnscaledHorizontalDragEnd: _endForwardedPageDrag,
            onUnscaledHorizontalDragCancel: _cancelForwardedPageDrag,
          );
        } else if (item.isVideo) {
          return VideoPlayerView(
            item: item,
            onContentReady: onContentReady,
            onClosePressed: _handleClosePressed,
          );
        } else if (item.isAudio) {
          return AudioPlayerView(
            item: item,
            onContentReady: onContentReady,
            onClosePressed: _handleClosePressed,
          );
        } else if (item.isText) {
          return TextViewer(item: item, onContentReady: onContentReady);
        } else if (item.isPdf) {
          return PdfViewer(
            item: item,
            onTap: _toggleControls,
            onContentReady: onContentReady,
            onUnscaledHorizontalDragStart: _sessionPages.length > 1
                ? _startForwardedPageDrag
                : null,
            onUnscaledHorizontalDragUpdate: _sessionPages.length > 1
                ? _updateForwardedPageDrag
                : null,
            onUnscaledHorizontalDragEnd: _sessionPages.length > 1
                ? _endForwardedPageDrag
                : null,
            onUnscaledHorizontalDragCancel: _sessionPages.length > 1
                ? _cancelForwardedPageDrag
                : null,
          );
        }

        return _buildUnsupportedFileView(context, item);
      },
    );
  }

  Widget _buildUnsupportedFileView(BuildContext context, MediaItem item) {
    return UnsupportedFileView(item: item);
  }

  int? _lastAspectPreloadedFileIndex;
  int? _lastSettledIndex;
  int? _lastSettledItemId;
  int? _previousPreloadIndex;

  void _prepareNearbyFiles(List<ViewerPage> pages, int currentIndex) {
    if (pages.isEmpty || !mounted) return;

    final docsPath = ref.read(appDocumentsPathSyncProvider);
    final targetLimit =
        _imagePreloadTargetLimit ?? calculateTargetImageLimit(context);
    final candidateIndexes = buildViewerPreloadIndexes(
      currentIndex: currentIndex,
      previousIndex: _previousPreloadIndex,
      itemCount: pages.length,
    );
    final requests = <ViewerPreloadRequest>[];
    final effectiveItems = _sessionEffectiveItems;
    final fileIndex = _sessionFileIndexById[pages[currentIndex].item.id];
    if (fileIndex != null && _lastAspectPreloadedFileIndex != fileIndex) {
      final item = effectiveItems[fileIndex];
      requests.add(
        ViewerPreloadRequest(
          key: 'aspect:$_sessionGeneration:${item.id}:${item.path}:$fileIndex',
          priority: 0,
          run: () => _preloadNearbyAspectRatios(effectiveItems, fileIndex),
        ),
      );
    }

    for (var order = 0; order < candidateIndexes.length; order++) {
      final index = candidateIndexes[order];
      final item = pages[index].item;
      if (!item.isDirectlyViewableImage || item.isSvg) continue;

      final key = 'image:${item.sourceType.name}:${item.path}:$targetLimit';
      requests.add(
        ViewerPreloadRequest(
          key: key,
          priority: order + 1,
          // Flutter can evict decoded images independently of this
          // coordinator. Re-submit on later settles: precacheImage is cheap on
          // a hit and performs the required decode again after eviction.
          retainCompletion: false,
          run: () async {
            if (!mounted) return;
            File? file;
            if (item.requiresSourceAccess) {
              final tempPath = await ref.read(
                externalFilePreviewProvider(item).future,
              );
              if (tempPath != null) file = File(tempPath);
            } else if (item.isDirectlyViewableImage) {
              file = File(p.join(docsPath, item.path));
            }

            if (!mounted || file == null) return;
            await precacheImageFile(
              context: context,
              file: file,
              targetLimit: targetLimit,
            );
          },
        ),
      );
    }

    _preloadCoordinator.replacePending(requests);
    _previousPreloadIndex = currentIndex;
  }

  Future<void> _preloadNearbyAspectRatios(
    List<MediaItem> items,
    int centerIndex,
  ) async {
    if (items.isEmpty) return;
    if (_lastAspectPreloadedFileIndex == centerIndex) return;
    _lastAspectPreloadedFileIndex = centerIndex;
    final generation = _sessionGeneration;

    bool hasNewSplitRatio;
    try {
      hasNewSplitRatio = await ensureAspectRatiosCachedAround(
        ref: ref,
        items: items,
        centerIndex: centerIndex,
        radius: 3,
      );
    } catch (error, stackTrace) {
      if (mounted && generation == _sessionGeneration) {
        if (_lastAspectPreloadedFileIndex == centerIndex) {
          _lastAspectPreloadedFileIndex = null;
        }
        AppLogger.w(
          LogTag.ui,
          'Viewer aspect-ratio preload failed',
          error,
          stackTrace,
        );
      }
      rethrow;
    }
    if (!mounted || generation != _sessionGeneration) return;
    if (hasNewSplitRatio) {
      _hasPendingAspectPageRefresh = true;
      _applyPendingAspectPageRefresh();
    }
  }

  void _applyPendingAspectPageRefresh() {
    if (!mounted || !_hasPendingAspectPageRefresh || _isPageScrolling) return;
    final pagesParam = _sessionPagesParam;
    if (pagesParam == null) return;
    _hasPendingAspectPageRefresh = false;
    ref.invalidate(viewerPagesProvider(pagesParam));
    setState(() => _sessionInputItems = null);
  }

  void _activatePageAt(List<ViewerPage> pages, int index) {
    if (index < 0 || index >= pages.length) return;
    final isSamePage = _pendingPageIndex == index;

    if (!isSamePage) {
      // Keep the committed shell state separate from PageView's transient
      // focus. Even an unrelated provider rebuild during the gesture cannot
      // leak the next file's title, controls, or metadata before ScrollEnd.
      _pendingPageIndex = index;
      _pageFocusGeneration++;
      // Cancel an unresolved external preview/play request as soon as the
      // focused page changes, rather than leaving a race window until settle.
      _playRequestGeneration++;
    }

    // onPageChanged fires while the PageView may still be animating. Keep the
    // transition callback light and defer I/O/player work until scroll end.
    if (!_isPageScrolling) {
      _schedulePageSettle(pages, index);
    }
  }

  bool _handlePageScrollNotification(
    List<ViewerPage> pages,
    ScrollNotification notification,
  ) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    if (notification is ScrollStartNotification) {
      _isPageScrolling = true;
      _historyGate.beginTransition();
      _pageSettleTimer?.cancel();
      _preloadCoordinator.cancelPending();
    } else if (notification is ScrollEndNotification) {
      _isPageScrolling = false;
      _pageSettleTimer?.cancel();
      _settlePageWork(pages, _pendingPageIndex);
      _applyPendingAspectPageRefresh();
    }
    return false;
  }

  void _schedulePageSettle(List<ViewerPage> pages, int index) {
    _pageSettleTimer?.cancel();
    final generation = _sessionGeneration;
    _pageSettleTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _isPageScrolling || generation != _sessionGeneration) {
        return;
      }
      _settlePageWork(pages, index);
    });
  }

  void _settlePageWork(List<ViewerPage> pages, int index) {
    if (!mounted ||
        !identical(pages, _sessionPages) ||
        index < 0 ||
        index >= pages.length) {
      return;
    }
    final item = pages[index].item;
    if (!widget.previewOnly) {
      _historyGate.settle(
        item,
        visit: '$_sessionGeneration:$_pageFocusGeneration:$index:${item.id}',
        at: DateTime.now(),
      );
    }
    if (_lastSettledSessionGeneration == _sessionGeneration &&
        _lastSettledFocusGeneration == _pageFocusGeneration &&
        _lastSettledIndex == index &&
        _lastSettledItemId == item.id) {
      // ScrollStart discards queued work. A short/cancelled drag may settle on
      // the same page, so restart its neighborhood even when no page commit is
      // needed.
      _scheduleNearbyPreparation(pages, index);
      return;
    }
    // Mark first so a provider-triggered rebuild cannot recursively commit the
    // same page through another ScrollEndNotification.
    setState(() {
      _currentIndex = index;
      _currentItem = item;
      _lastSettledSessionGeneration = _sessionGeneration;
      _lastSettledFocusGeneration = _pageFocusGeneration;
      _lastSettledIndex = index;
      _lastSettledItemId = item.id;
    });
    if (!widget.previewOnly) {
      ref
          .read(mediaViewerViewModelProvider.notifier)
          .setCurrentPage(index, item);
    }
    final playRequestGeneration = ++_playRequestGeneration;
    _autoPlayIfNeeded(item, playRequestGeneration);
    _scheduleNearbyPreparation(pages, index);
  }

  Future<void> _recordOpenedFile(MediaItem item, DateTime openedAt) async {
    // Capture the dependency while mounted. A confirmed visible file must still
    // be saved if the user closes the viewer while the database opens.
    try {
      final repositoryFuture = ref.read(
        viewingHistoryRepositoryProvider.future,
      );
      final repository = await repositoryFuture;
      await repository.record(item, openedAt: openedAt);
    } catch (error) {
      AppLogger.w(LogTag.ui, 'Could not record viewed file', error);
    }
  }

  void _scheduleNearbyPreparation(List<ViewerPage> pages, int index) {
    final sessionGeneration = _sessionGeneration;
    final focusGeneration = _pageFocusGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isPageScrolling ||
          sessionGeneration != _sessionGeneration ||
          focusGeneration != _pageFocusGeneration ||
          !identical(pages, _sessionPages) ||
          _lastSettledIndex != index) {
        return;
      }
      _prepareNearbyFiles(pages, index);
    });
  }

  void _moveToPage(List<ViewerPage> pages, int index) {
    final controller = _pageController;
    if (index < 0 ||
        index >= pages.length ||
        controller == null ||
        !controller.hasClients) {
      return;
    }
    controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _startForwardedPageDrag(DragStartDetails details) {
    _cancelForwardedPageDrag();
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;

    // The image's leaf recognizer wins before InteractiveViewer's one-finger
    // scale/pan recognizer. Forward the drag to the PageView's own position so
    // its physics, notifications, and page settling behavior remain unchanged.
    late final Drag drag;
    drag = controller.position.drag(details, () {
      if (identical(_forwardedPageDrag, drag)) {
        _forwardedPageDrag = null;
      }
    });
    _forwardedPageDrag = drag;
  }

  void _updateForwardedPageDrag(DragUpdateDetails details) {
    _forwardedPageDrag?.update(details);
  }

  void _endForwardedPageDrag(DragEndDetails details) {
    final drag = _forwardedPageDrag;
    _forwardedPageDrag = null;
    drag?.end(details);
  }

  void _cancelForwardedPageDrag() {
    final drag = _forwardedPageDrag;
    _forwardedPageDrag = null;
    drag?.cancel();
  }

  void _togglePlaybackFromKeyboard() {
    final item = _currentItem;
    if (item == null || (!item.isVideo && !item.isAudio)) return;
    final playerState = ref.read(playerNotifierProvider);
    final notifier = ref.read(playerNotifierProvider.notifier);
    if (playerState.isPlaying) {
      unawaited(notifier.pause());
    } else {
      unawaited(notifier.resume());
    }
  }

  void _handleClosePressed() {
    if (widget.embeddedInOverlay) {
      ref.read(playerNotifierProvider.notifier).collapse();
      return;
    }
    if (_shouldIgnoreBackAction()) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    }
  }

  void _handleBackToCatalogContents() {
    final sourceContext = widget.sourceContext;
    if (sourceContext?.kind != ViewerSourceKind.catalog ||
        sourceContext?.parentPath == null ||
        sourceContext?.appMode == null) {
      return;
    }
    ref
        .read(mediaFilterNotifierProvider(sourceContext!.appMode!).notifier)
        .updateParentPath(sourceContext.parentPath);
    _handleClosePressed();
  }

  void _autoPlayIfNeeded(MediaItem item, int requestGeneration) {
    final isPlayable = item.isVideo || item.isAudio;
    if (!isPlayable) return;
    final playerState = ref.read(playerNotifierProvider);
    final shouldAutoPlay = widget.embeddedInOverlay
        ? playerState.isExpanded
        : true;
    if (!shouldAutoPlay) return;
    final isSameItem = playerState.currentItem?.id == item.id;
    final hasActiveController =
        playerState.chewieController != null || playerState.audioPlayer != null;
    final shouldStart =
        !isSameItem ||
        (!hasActiveController && !playerState.isInitializing) ||
        playerState.error != null;
    if (!shouldStart) return;
    unawaited(_playItem(item, requestGeneration));
  }

  bool _isCurrentPlayRequest(MediaItem item, int requestGeneration) {
    return mounted &&
        requestGeneration == _playRequestGeneration &&
        _lastSettledItemId == item.id;
  }

  Future<void> _playItem(MediaItem item, int requestGeneration) async {
    File? sourceFile;
    if (item.requiresSourceAccess) {
      final tempPath = await ref.read(externalFilePreviewProvider(item).future);
      if (!_isCurrentPlayRequest(item, requestGeneration)) return;
      if (tempPath != null) {
        final file = File(tempPath);
        if (await file.exists()) {
          sourceFile = file;
        }
      }
    }

    if (!_isCurrentPlayRequest(item, requestGeneration)) return;
    if (!widget.embeddedInOverlay) {
      _startedPlaybackInStandaloneViewer = true;
    }
    await ref
        .read(playerNotifierProvider.notifier)
        .play(
          item,
          file: sourceFile,
          isExpanded: widget.embeddedInOverlay,
          showMiniPlayer: !widget.previewOnly,
          playlist: _sessionEffectiveItems,
          owner: _playbackOwner,
        );
  }
}
