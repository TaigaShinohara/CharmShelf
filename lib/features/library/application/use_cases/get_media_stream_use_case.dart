// Application layer: coordinates domain contracts with repository providers.
import 'dart:async';
import 'package:private_shelf/core/performance/interaction_trace.dart';
import 'package:collection/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_items_snapshot.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';

part 'get_media_stream_use_case.g.dart';

@Riverpod(keepAlive: true)
GetMediaStreamUseCase getMediaStreamUseCase(Ref ref) {
  return GetMediaStreamUseCase(ref.read(mediaRepositoryProvider.future));
}

class GetMediaStreamUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;

  GetMediaStreamUseCase(this._mediaRepositoryFuture);

  /// Append only the requested page. A DB mutation invalidates the snapshot and
  /// rebuilds the visible window atomically, never mixing old/new page offsets.
  Stream<List<MediaItem>> invokePaged(
    MediaFilter filter,
    Stream<int> limits,
  ) async* {
    final repo = await _mediaRepositoryFuture;
    yield* Stream<List<MediaItem>>.multi((output) {
      var items = <MediaItem>[];
      var target = filter.limit ?? 80;
      var revision = 0;
      var reset = true;
      var running = false;
      var pending = false;
      var disposed = false;
      List<Object?>? previousSnapshot;
      var requestedCompletion = true;

      void emitIfChanged() {
        final snapshot = InteractionTrace.sync(
          'library.visible_snapshot',
          () => mediaItemsSnapshot(items),
        );
        if (requestedCompletion ||
            !const DeepCollectionEquality().equals(
              previousSnapshot,
              snapshot,
            )) {
          previousSnapshot = snapshot;
          requestedCompletion = false;
          output.add(items);
        }
      }

      void reportError(Object error, StackTrace stack) {
        previousSnapshot = null;
        output.addError(error, stack);
      }

      Future<void> drain() async {
        if (running || disposed) return;
        running = true;
        try {
          while (pending && !disposed) {
            pending = false;
            final version = revision;
            final requested = target;
            final offset = reset ? 0 : items.length;
            if (requested <= offset) {
              emitIfChanged();
              continue;
            }
            try {
              final result = await InteractionTrace.async(
                'library.page_read',
                () => repo.getPage(
                  filter: filter.copyWith(limit: null),
                  offset: offset,
                  limit: requested - offset,
                ),
              );
              if (disposed) return;
              if (version != revision) {
                pending = true;
                continue;
              }
              if (result.isFailure) throw result.errorOrNull!;
              final page = result.dataOrNull!;
              if (offset > 0) {
                final existingIds = items.map((item) => item.id).toSet();
                if (page.any((item) => existingIds.contains(item.id))) {
                  // A commit may precede delivery of its watch notification.
                  // Never expose a duplicate boundary while waiting for it.
                  reset = true;
                  pending = true;
                  continue;
                }
              }
              items = offset == 0 ? page : [...items, ...page];
              reset = false;
              emitIfChanged();
            } catch (error, stack) {
              if (!disposed && version == revision) {
                reportError(error, stack);
              }
            }
          }
        } finally {
          running = false;
        }
      }

      void schedule() {
        pending = true;
        unawaited(drain());
      }

      final changes = repo.watchLibraryChanges(filter: filter).listen((_) {
        revision++;
        reset = true;
        schedule();
      }, onError: reportError);
      final requests = limits.listen((limit) {
        target = limit;
        // Even an empty final page must settle loadMore and its loading state.
        requestedCompletion = true;
        schedule();
      }, onError: reportError);
      schedule();
      output.onCancel = () async {
        disposed = true;
        await requests.cancel();
        await changes.cancel();
      };
    });
  }

  /// 検索条件に応じたメディアのストリームを取得
  Stream<List<MediaItem>> invoke(MediaFilter filter) async* {
    final repo = await _mediaRepositoryFuture;

    // Isarのwatchを組み込む
    yield* repo.watchAll(filter: filter).asyncMap((items) async {
      // IsarLinksは個別にロードが必要（Repository側で対応済みだが、一応ここでも安全策として残すか検討）
      // 現在のIsarMediaRepository実装では _applySortAndExecute 内で load() されている。
      return items;
    });
  }
}
