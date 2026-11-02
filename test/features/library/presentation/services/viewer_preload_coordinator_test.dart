import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_preload_coordinator.dart';

void main() {
  group('viewer preload order', () {
    test(
      'forward paging prioritizes the next page without reloading current',
      () {
        expect(
          buildViewerPreloadIndexes(
            currentIndex: 5,
            previousIndex: 4,
            itemCount: 10,
          ),
          [6, 4, 7],
        );
      },
    );

    test(
      'reverse paging mirrors priority and removes out-of-range indexes',
      () {
        expect(
          buildViewerPreloadIndexes(
            currentIndex: 1,
            previousIndex: 2,
            itemCount: 4,
          ),
          [0, 2],
        );
        expect(
          buildViewerPreloadIndexes(
            currentIndex: 0,
            previousIndex: null,
            itemCount: 3,
          ),
          [1, 2],
        );
      },
    );
  });

  test('同時実行数を制限し、古い未実行キューを破棄する', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    addTearDown(coordinator.dispose);
    final firstCompleter = Completer<void>();
    final executed = <String>[];

    coordinator.replacePending([
      ViewerPreloadRequest(
        key: 'first',
        priority: 0,
        run: () async {
          executed.add('first');
          await firstCompleter.future;
        },
      ),
      ViewerPreloadRequest(
        key: 'stale',
        priority: 1,
        run: () async => executed.add('stale'),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(executed, ['first']);
    expect(coordinator.activeCount, 1);
    expect(coordinator.queuedCount, 1);

    coordinator.replacePending([
      ViewerPreloadRequest(
        key: 'latest',
        priority: 0,
        run: () async => executed.add('latest'),
      ),
    ]);
    firstCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(executed, ['first', 'latest']);
    expect(coordinator.activeCount, 0);
    expect(coordinator.queuedCount, 0);
  });

  test('同一キーの完了済み処理を再実行しない', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 2);
    addTearDown(coordinator.dispose);
    var executions = 0;
    final request = ViewerPreloadRequest(
      key: 'same-file',
      priority: 0,
      run: () async => executions++,
    );

    coordinator.replacePending([request, request]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);

    expect(executions, 1);
  });

  test('外部キャッシュ依存の完了は保持せず、追い出し後に再実行できる', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    addTearDown(coordinator.dispose);
    var executions = 0;
    final request = ViewerPreloadRequest(
      key: 'evictable-image',
      priority: 0,
      retainCompletion: false,
      run: () async => executions++,
    );

    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);

    expect(executions, 2);
    expect(coordinator.retainedCompletionCount, 0);
  });

  test('完了履歴をLRU上限内に保ち、古い処理だけを再実行する', () async {
    final coordinator = ViewerPreloadCoordinator(
      maxConcurrent: 1,
      maxRetainedCompletions: 2,
    );
    addTearDown(coordinator.dispose);
    final executions = <String, int>{};

    ViewerPreloadRequest request(String key) => ViewerPreloadRequest(
      key: key,
      priority: 0,
      run: () async =>
          executions.update(key, (count) => count + 1, ifAbsent: () => 1),
    );

    for (final key in ['first', 'second']) {
      coordinator.replacePending([request(key)]);
      await Future<void>.delayed(Duration.zero);
    }
    // Refresh first, making second the least-recently-used entry.
    coordinator.replacePending([request('first')]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request('third')]);
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.retainedCompletionCount, 2);
    expect(executions, {'first': 1, 'second': 1, 'third': 1});

    coordinator.replacePending([request('first')]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request('second')]);
    await Future<void>.delayed(Duration.zero);

    expect(executions['first'], 1);
    expect(executions['second'], 2);
    expect(coordinator.retainedCompletionCount, 2);
  });

  test('失敗した処理は完了扱いにせず次の近傍更新で再試行する', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    addTearDown(coordinator.dispose);
    var executions = 0;
    final request = ViewerPreloadRequest(
      key: 'temporarily-unavailable',
      priority: 0,
      run: () async {
        executions++;
        if (executions == 1) throw StateError('temporary failure');
      },
    );

    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([request]);
    await Future<void>.delayed(Duration.zero);

    expect(executions, 2);
    expect(coordinator.retainedCompletionCount, 1);
  });

  test('破棄後に実行中処理が完了しても履歴を復活させない', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    final completer = Completer<void>();

    coordinator.replacePending([
      ViewerPreloadRequest(
        key: 'finishes-after-dispose',
        priority: 0,
        run: () => completer.future,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    coordinator.dispose();
    completer.complete();
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.activeCount, 0);
    expect(coordinator.queuedCount, 0);
    expect(coordinator.retainedCompletionCount, 0);
  });

  test('スクロール開始時の取消で実行中だけを残し、待機中を開始しない', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    addTearDown(coordinator.dispose);
    final activeCompleter = Completer<void>();
    final executed = <String>[];

    coordinator.replacePending([
      ViewerPreloadRequest(
        key: 'active',
        priority: 0,
        run: () async {
          executed.add('active');
          await activeCompleter.future;
        },
      ),
      ViewerPreloadRequest(
        key: 'must-not-start',
        priority: 1,
        run: () async => executed.add('must-not-start'),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    coordinator.cancelPending();
    activeCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(executed, ['active']);
    expect(coordinator.activeCount, 0);
    expect(coordinator.queuedCount, 0);
  });

  test('取消済みの待機処理は同じページの確定後に再登録できる', () async {
    final coordinator = ViewerPreloadCoordinator(maxConcurrent: 1);
    addTearDown(coordinator.dispose);
    final activeCompleter = Completer<void>();
    final executed = <String>[];
    final retryable = ViewerPreloadRequest(
      key: 'neighbor-image',
      priority: 1,
      retainCompletion: false,
      run: () async => executed.add('neighbor-image'),
    );

    coordinator.replacePending([
      ViewerPreloadRequest(
        key: 'active',
        priority: 0,
        run: () async {
          executed.add('active');
          await activeCompleter.future;
        },
      ),
      retryable,
    ]);
    await Future<void>.delayed(Duration.zero);

    coordinator.cancelPending();
    activeCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    coordinator.replacePending([retryable]);
    await Future<void>.delayed(Duration.zero);

    expect(executed, ['active', 'neighbor-image']);
    expect(coordinator.activeCount, 0);
    expect(coordinator.queuedCount, 0);
  });
}
