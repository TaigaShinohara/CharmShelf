import 'package:private_shelf/core/performance/interaction_trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:private_shelf/core/error/error_display_service.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

final _catalogOpenRequests = Expando<Object>('catalogOpenRequests');

class _CatalogOpenPopEntry extends PopEntry<Object?> {
  _CatalogOpenPopEntry(this.onCancel);
  final VoidCallback onCancel;
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
  @override
  void onPopInvokedWithResult(bool didPop, Object? result) => onCancel();
}

MediaItem? selectCatalogInitialItem(
  List<MediaItem> items,
  int? lastViewedItemId,
) {
  final files = items
      .where((item) => item.type == MediaType.file)
      .toList(growable: false);
  if (files.isEmpty) return null;
  if (lastViewedItemId == null) return files.first;
  return files.firstWhere(
    (item) => item.id == lastViewedItemId,
    orElse: () => files.first,
  );
}

Future<void> openFolderCatalogViewer({
  required BuildContext context,
  required WidgetRef ref,
  required MediaItem folder,
  required MediaCollection collection,
  required AppMode mode,
  VoidCallback? onEmpty,
}) async {
  final navigator = Navigator.of(context);
  if (_catalogOpenRequests[navigator] != null) return;
  InteractionTrace.start('catalog_first_content');
  final request = Object();
  _catalogOpenRequests[navigator] = request;
  final sourceRoute = ModalRoute.of(context);
  final currentFilter = ref.read(mediaFilterNotifierProvider(mode));
  final progress = OverlayEntry(
    builder: (_) => const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: LinearProgressIndicator(key: ValueKey('catalog-opening')),
        ),
      ),
    ),
  );
  final overlay = navigator.overlay!;
  overlay.insert(progress);
  var progressVisible = true;
  void clearProgress() {
    if (!progressVisible) return;
    progressVisible = false;
    progress.remove();
    progress.dispose();
  }

  var cancelled = false;
  void cancelOpen() {
    cancelled = true;
    InteractionTrace.cancel('catalog_first_content');
    clearProgress();
    if (identical(_catalogOpenRequests[navigator], request)) {
      _catalogOpenRequests[navigator] = null;
    }
  }

  final popEntry = _CatalogOpenPopEntry(cancelOpen);
  sourceRoute?.registerPopEntry(popEntry);
  final tabSubscription = ref.listenManual(currentTabIndexProvider, (
    before,
    after,
  ) {
    if (before != after) cancelOpen();
  });
  final modeSubscription = ref.listenManual(appModeProvider, (before, after) {
    if (before != after) cancelOpen();
  });
  final filterSubscription = ref.listenManual(
    mediaFilterNotifierProvider(mode),
    (before, after) {
      if (before != after) cancelOpen();
    },
  );

  try {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final catalogFilter = MediaFilter(
      parentPath: folder.path,
      sourceType: folder.sourceType,
      mediaTypes: const [MediaType.file],
      isArchived: false,
      isHidden: currentFilter.isHidden,
      sortOrder: currentFilter.sortOrder,
    );
    // Resolve the resume target through the same visibility filter; getById
    // alone could resurrect a moved, archived, or hidden file.
    MediaItem? resume;
    if (collection.lastViewedItemId != null) {
      final saved = await repository.getById(collection.lastViewedItemId!);
      if (saved.isFailure) throw saved.errorOrNull!;
      resume = saved.dataOrNull;
    }
    if (cancelled || !context.mounted) return;
    var result = await repository.getAll(
      filter: catalogFilter.copyWith(limit: 1, path: resume?.path),
    );
    if (resume != null && result.isSuccess && result.dataOrNull!.isEmpty) {
      if (cancelled || !context.mounted) return;
      result = await repository.getAll(
        filter: catalogFilter.copyWith(limit: 1),
      );
    }
    if (cancelled ||
        !context.mounted ||
        !navigator.mounted ||
        (sourceRoute != null && !sourceRoute.isCurrent) ||
        ref.read(mediaFilterNotifierProvider(mode)) != currentFilter) {
      return;
    }

    if (result.isFailure) {
      ErrorDisplayService.show(context, result.errorOrNull!, ref: ref);
      return;
    }

    final files = result.dataOrNull!
        .where((item) => item.type == MediaType.file)
        .toList(growable: false);
    final initialItem = selectCatalogInitialItem(
      files,
      collection.lastViewedItemId,
    );
    if (initialItem == null) {
      ref
          .read(mediaFilterNotifierProvider(mode).notifier)
          .updateParentPath(folder.path);
      onEmpty?.call();
      return;
    }

    clearProgress();
    ref.invalidate(mediaItemProvider(initialItem.id));
    await MediaViewerRoute(
      id: initialItem.id,
      $extra: ViewerRouteArgs(
        initialItem: initialItem,
        sourceContext: ViewerSourceContext.catalog(
          items: [initialItem],
          catalogFilter: catalogFilter,
          parentPath: folder.path,
          appMode: mode,
        ),
      ),
    ).push<void>(context);
  } catch (error) {
    if (!cancelled && context.mounted) {
      ErrorDisplayService.show(
        context,
        error is AppError
            ? error
            : AppError.ui(
                AppLocalizations.of(context)!.commonErrorOccurred,
                original: error,
              ),
        ref: ref,
      );
    }
  } finally {
    tabSubscription.close();
    modeSubscription.close();
    filterSubscription.close();
    sourceRoute?.unregisterPopEntry(popEntry);
    popEntry.canPopNotifier.dispose();
    clearProgress();
    if (identical(_catalogOpenRequests[navigator], request)) {
      _catalogOpenRequests[navigator] = null;
    }
  }
}
