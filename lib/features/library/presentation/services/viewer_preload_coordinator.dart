import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef ViewerPreloadTask = Future<void> Function();

/// Returns the bounded page-preparation order for the current navigation
/// direction. The visible page is deliberately excluded because its image is
/// already resolving through the widget tree.
List<int> buildViewerPreloadIndexes({
  required int currentIndex,
  required int? previousIndex,
  required int itemCount,
}) {
  if (itemCount <= 0 || currentIndex < 0 || currentIndex >= itemCount) {
    return const [];
  }

  final delta = previousIndex == null ? 1 : currentIndex - previousIndex;
  final direction = delta == 0 ? 1 : delta.sign;
  final indexes = <int>[];
  final seen = <int>{};
  for (final index in <int>[
    currentIndex + direction,
    currentIndex - direction,
    currentIndex + (direction * 2),
  ]) {
    if (index >= 0 && index < itemCount && seen.add(index)) {
      indexes.add(index);
    }
  }
  return indexes;
}

@immutable
class ViewerPreloadRequest {
  const ViewerPreloadRequest({
    required this.key,
    required this.priority,
    required this.run,
    this.retainCompletion = true,
  });

  final String key;
  final int priority;
  final ViewerPreloadTask run;

  /// Whether a successful run can be treated as prepared for later
  /// neighborhoods in this viewer session.
  ///
  /// Keep this disabled for work backed by an independently evictable cache,
  /// such as Flutter's [ImageCache]. Re-submitting that work is cheap on a
  /// cache hit and allows it to recover after the cache evicts the image.
  final bool retainCompletion;
}

/// Keeps viewer preparation work bounded and discards queued work that no
/// longer belongs to the current page neighborhood.
class ViewerPreloadCoordinator {
  ViewerPreloadCoordinator({
    this.maxConcurrent = 2,
    this.maxRetainedCompletions = 32,
  }) : assert(maxConcurrent > 0),
       assert(maxRetainedCompletions >= 0);

  final int maxConcurrent;
  final int maxRetainedCompletions;

  final List<_QueuedPreload> _queue = [];
  final Set<String> _activeKeys = {};
  final LinkedHashSet<String> _completedKeys = LinkedHashSet<String>();
  var _generation = 0;
  var _activeCount = 0;
  var _disposed = false;

  @visibleForTesting
  int get activeCount => _activeCount;

  @visibleForTesting
  int get queuedCount => _queue.length;

  @visibleForTesting
  int get retainedCompletionCount => _completedKeys.length;

  /// Replaces pending work with the priorities for the latest focused page.
  /// Already running work cannot be cancelled safely, but it stays bounded by
  /// [maxConcurrent].
  void replacePending(Iterable<ViewerPreloadRequest> requests) {
    if (_disposed) return;

    final generation = ++_generation;
    _queue.clear();
    final queuedKeys = <String>{};
    for (final request in requests) {
      if (_activeKeys.contains(request.key) ||
          _shouldSkipCompleted(request) ||
          !queuedKeys.add(request.key)) {
        continue;
      }
      _queue.add(_QueuedPreload(request, generation));
    }
    _queue.sort(
      (left, right) => left.request.priority.compareTo(right.request.priority),
    );
    _pump();
  }

  /// Prevents queued preparation from starting after a new interaction.
  /// Work that has already entered an image codec cannot be cancelled safely,
  /// so it is allowed to finish while the queue is discarded.
  void cancelPending() {
    if (_disposed) return;
    _generation++;
    _queue.clear();
  }

  void _pump() {
    if (_disposed) return;
    _queue.removeWhere((job) => job.generation != _generation);

    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      final key = job.request.key;
      if (_activeKeys.contains(key) || _shouldSkipCompleted(job.request)) {
        continue;
      }

      _activeCount++;
      _activeKeys.add(key);
      unawaited(_run(job));
    }
  }

  Future<void> _run(_QueuedPreload job) async {
    var completed = false;
    try {
      await job.request.run();
      completed = true;
    } catch (_) {
      // Preparation is best-effort. A failed item remains retryable when it
      // enters a later neighborhood.
    } finally {
      _activeCount--;
      _activeKeys.remove(job.request.key);
      if (!_disposed && completed && job.request.retainCompletion) {
        _rememberCompletion(job.request.key);
      }
      _pump();
    }
  }

  bool _shouldSkipCompleted(ViewerPreloadRequest request) {
    if (!request.retainCompletion) {
      // A previously retained request may later opt into cache-backed retry.
      _completedKeys.remove(request.key);
      return false;
    }
    if (!_completedKeys.remove(request.key)) return false;

    // A cache hit also refreshes recency so frequently revisited work stays in
    // the bounded completion window.
    _completedKeys.add(request.key);
    return true;
  }

  void _rememberCompletion(String key) {
    if (maxRetainedCompletions == 0) return;
    _completedKeys.remove(key);
    _completedKeys.add(key);
    while (_completedKeys.length > maxRetainedCompletions) {
      _completedKeys.remove(_completedKeys.first);
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _queue.clear();
    _completedKeys.clear();
  }
}

class _QueuedPreload {
  const _QueuedPreload(this.request, this.generation);

  final ViewerPreloadRequest request;
  final int generation;
}
