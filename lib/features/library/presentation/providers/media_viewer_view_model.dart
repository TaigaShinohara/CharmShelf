import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';

part 'media_viewer_view_model.g.dart';

class MediaViewerState {
  final bool showControls;
  final int currentIndex;
  final MediaItem? currentItem;

  const MediaViewerState({
    this.showControls = true,
    this.currentIndex = 0,
    this.currentItem,
  });

  MediaViewerState copyWith({
    bool? showControls,
    int? currentIndex,
    MediaItem? currentItem,
  }) {
    return MediaViewerState(
      showControls: showControls ?? this.showControls,
      currentIndex: currentIndex ?? this.currentIndex,
      currentItem: currentItem ?? this.currentItem,
    );
  }
}

@riverpod
class MediaViewerViewModel extends _$MediaViewerViewModel {
  Timer? _debounceTimer;
  late final Future<MediaRepository> _repositoryFuture;
  MediaItem? _pendingLastViewedItem;
  bool _isSavingLastViewed = false;
  bool _hasPendingLastViewedSave = false;
  bool _disposed = false;

  @override
  MediaViewerState build() {
    _disposed = false;
    _repositoryFuture = ref.read(mediaRepositoryProvider.future);
    ref.onDispose(() {
      final shouldFlush = _hasPendingLastViewedSave;
      _disposed = true;
      _debounceTimer?.cancel();
      if (shouldFlush) {
        unawaited(_flushPendingLastViewedAt());
      }
    });
    return const MediaViewerState();
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void setControlsVisible(bool visible) {
    state = state.copyWith(showControls: visible);
  }

  void setCurrentPage(int index, MediaItem item) {
    state = state.copyWith(currentIndex: index, currentItem: item);
    updateLastViewedAt(item);
  }

  String? _resolveCollectionPath(MediaItem item) {
    final colPath = item.collection.value?.path;
    if (colPath != null && colPath.isNotEmpty && colPath != 'library') {
      return colPath;
    }
    if (item.parentPath != null &&
        item.parentPath!.isNotEmpty &&
        item.parentPath != 'library') {
      return item.parentPath;
    }
    if (item.path.isNotEmpty && item.path != 'library') {
      return item.path;
    }
    return null;
  }

  void updateLastViewedAt(MediaItem item) {
    final collectionPath = _resolveCollectionPath(item);
    if (collectionPath == null || collectionPath.isEmpty) {
      return;
    }
    _pendingLastViewedItem = item;
    _hasPendingLastViewedSave = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_flushPendingLastViewedAt());
    });
  }

  Future<void> _flushPendingLastViewedAt() async {
    if (_isSavingLastViewed) return;
    final pendingItem = _pendingLastViewedItem;
    if (pendingItem == null || !_hasPendingLastViewedSave) return;

    _isSavingLastViewed = true;
    _hasPendingLastViewedSave = false;
    try {
      await saveLastViewedAt(pendingItem);
    } finally {
      _isSavingLastViewed = false;
      if (_hasPendingLastViewedSave) {
        if (_disposed) {
          unawaited(_flushPendingLastViewedAt());
        } else {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            unawaited(_flushPendingLastViewedAt());
          });
        }
      }
    }
  }

  Future<void> saveLastViewedAt(MediaItem item) async {
    final collectionPath = _resolveCollectionPath(item);
    if (collectionPath == null || collectionPath.isEmpty) return;

    try {
      // keepAlive なRepositoryのFutureを構築時に取得しておき、ViewModel破棄後に
      // 保留書き込みをflushしても ref を参照しない。
      final repo = await _repositoryFuture;
      final result = await repo.updateCollectionLastViewed(
        collectionPath,
        itemId: item.id,
        viewedAt: DateTime.now(),
      );
      if (result.isFailure) {
        AppLogger.w(
          LogTag.ui,
          '[ResumeBanner] update failed: path=$collectionPath',
          result.errorOrNull,
        );
        return;
      }
      if (result.dataOrNull != true) {
        AppLogger.d(
          LogTag.ui,
          '[ResumeBanner] No collection found for path=$collectionPath',
        );
        return;
      }

      AppLogger.d(
        LogTag.ui,
        '[ResumeBanner] Saved: path=$collectionPath, lastViewedItemId=${item.id}',
      );
    } catch (e) {
      AppLogger.w(LogTag.ui, '[ResumeBanner] update FAILED: $e');
    }
  }

  Future<void> toggleFavorite(
    MediaCollection collection,
    MediaItem currentItem,
  ) async {
    await ref
        .read(collectionNotifierProvider(collection.path).notifier)
        .toggleFavorite();
    ref.invalidate(mediaItemProvider(currentItem.id));
  }

  Future<void> updateAlias(
    MediaCollection collection,
    MediaItem currentItem,
    String? alias,
  ) async {
    await ref
        .read(collectionNotifierProvider(collection.path).notifier)
        .updateAlias(alias);
    ref.invalidate(mediaItemProvider(currentItem.id));
  }

  Future<void> updateNotes(
    MediaCollection collection,
    MediaItem currentItem,
    String? notes,
  ) async {
    await ref
        .read(collectionNotifierProvider(collection.path).notifier)
        .updateNotes(notes);
    ref.invalidate(mediaItemProvider(currentItem.id));
  }

  Future<void> setAsFolderCover(MediaItem item) async {
    await ref.read(libraryViewModelProvider.notifier).setAsFolderCover(item);
  }
}
