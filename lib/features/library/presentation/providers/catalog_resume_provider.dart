import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

typedef CatalogResumeRequest = ({
  int collectionId,
  String collectionPath,
  int itemId,
});

class CatalogResumeTarget {
  const CatalogResumeTarget({required this.item, this.lastViewedAt});

  final MediaItem item;
  final DateTime? lastViewedAt;
}

/// Reads the current target and its protection state without saving history.
/// An unavailable target returns null; a failed repository read is rethrown.
Future<CatalogResumeTarget?> resolveCatalogResumeTarget(
  MediaRepository repository,
  CatalogResumeRequest request, {
  required bool includeHidden,
}) async {
  final catalog = _read(
    await repository.getCollectionById(request.collectionId),
  );
  if (catalog == null ||
      catalog.id != request.collectionId ||
      catalog.path != request.collectionPath ||
      catalog.path.isEmpty ||
      !catalog.isCatalog ||
      catalog.lastViewedItemId != request.itemId ||
      !_collectionAvailable(catalog, includeHidden: includeHidden)) {
    return null;
  }

  final item = _read(await repository.getById(request.itemId));
  if (item == null ||
      item.id != request.itemId ||
      item.type != MediaType.file ||
      item.path.isEmpty ||
      !_itemAvailable(item, includeHidden: includeHidden)) {
    return null;
  }
  if (catalog.type == CollectionType.file) {
    if (item.path != catalog.path) return null;
  } else if (item.parentPath != catalog.path) {
    return null;
  }

  // A file may have its own collection metadata inside a folder catalog.
  if (item.path != catalog.path) {
    final itemCollection = _read(
      await repository.getCollectionByPath(item.path),
    );
    if (itemCollection != null &&
        (itemCollection.path != item.path ||
            !_collectionAvailable(
              itemCollection,
              includeHidden: includeHidden,
            ))) {
      return null;
    }
  }

  final visited = <String>{item.path};
  var parentPath = item.parentPath;
  while (true) {
    // Top-level internal items may store null/empty as their logical parent.
    // Still check an existing virtual library root before accepting them.
    final ancestorPath = parentPath == null || parentPath.isEmpty
        ? 'library'
        : parentPath;
    if (!visited.add(ancestorPath)) return null;
    final parent = _read(
      await repository.getByPath(ancestorPath, includeTrashed: true),
    );
    // `library` can be a virtual root. Every ordinary ancestor must exist.
    if (parent == null && ancestorPath != 'library') return null;
    if (parent != null &&
        (parent.path != ancestorPath ||
            parent.type != MediaType.folder ||
            !_itemAvailable(parent, includeHidden: includeHidden))) {
      return null;
    }

    final parentCollection = ancestorPath == catalog.path
        ? catalog
        : _read(await repository.getCollectionByPath(ancestorPath));
    if (parentCollection != null &&
        (parentCollection.path != ancestorPath ||
            !_collectionAvailable(
              parentCollection,
              includeHidden: includeHidden,
            ))) {
      return null;
    }
    if (ancestorPath == 'library') break;
    parentPath = parent!.parentPath;
  }

  // Preserve the viewer's existing collection/split-spread/history contract
  // when it falls back to this item outside the current library filter.
  if (item.collection.isAttached && !item.collection.isLoaded) {
    await item.collection.load();
  }
  final linkedCollection = item.collection.value;
  if (linkedCollection != null) {
    if (!_collectionAvailable(linkedCollection, includeHidden: includeHidden)) {
      return null;
    }
    if (linkedCollection.tags.isAttached && !linkedCollection.tags.isLoaded) {
      await linkedCollection.tags.load();
    }
  }

  return CatalogResumeTarget(item: item, lastViewedAt: catalog.lastViewedAt);
}

T _read<T>(Result<T, AppError> result) =>
    result.when(success: (value) => value, failure: (error) => throw error);

bool _itemAvailable(MediaItem item, {required bool includeHidden}) =>
    item.sourceType == MediaSourceType.localCopy &&
    !item.isImportPreview &&
    !item.isMissing &&
    !item.isArchived &&
    !item.isTrashed &&
    (includeHidden || !item.isHidden);

bool _collectionAvailable(
  MediaCollection collection, {
  required bool includeHidden,
}) =>
    collection.type != CollectionType.externalFolder &&
    !collection.isArchived &&
    !collection.isTrashed &&
    (includeHidden || !collection.isHidden);

final catalogResumeTargetProvider = StreamProvider.autoDispose
    .family<CatalogResumeTarget?, CatalogResumeRequest>((ref, request) {
      final mode = ref.watch(appModeProvider);
      final secret = ref.watch(secretModeProvider);
      final repositoryFuture = ref.watch(mediaRepositoryProvider.future);
      if (mode != AppMode.internal || secret.isLoading || secret.hasError) {
        return Stream.value(null);
      }
      final includeHidden = secret.value;
      if (includeHidden == null) return Stream.value(null);

      final controller = StreamController<CatalogResumeTarget?>();
      var active = true;
      var watchFailed = false;
      StreamSubscription<void>? subscription;
      ref.onDispose(() {
        active = false;
        unawaited(subscription?.cancel());
        unawaited(controller.close());
      });

      unawaited(() async {
        try {
          final repository = await repositoryFuture;
          if (!active) return;
          subscription = repository
              .watchLibraryChanges(
                filter: const MediaFilter(isHidden: null, isArchived: null),
              )
              .listen(
                (_) {
                  if (active && !watchFailed) ref.invalidateSelf();
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!active || watchFailed) return;
                  watchFailed = true;
                  // Keep late watch failures visible after the first read.
                  controller.addError(error, stackTrace);
                },
              );
          final target = await resolveCatalogResumeTarget(
            repository,
            request,
            includeHidden: includeHidden,
          );
          // A watch failure wins over any in-flight result or later error.
          if (active && !watchFailed) controller.add(target);
        } catch (error, stackTrace) {
          if (active && !watchFailed) controller.addError(error, stackTrace);
        }
      }());
      return controller.stream;
    });
