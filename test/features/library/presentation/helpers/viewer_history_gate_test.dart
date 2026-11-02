import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/helpers/viewer_history_gate.dart';

MediaItem item(int id) => MediaItem()
  ..id = id
  ..uid = 'item-$id'
  ..path = 'library/$id.jpg';

void main() {
  late List<(int, DateTime)> recorded;
  late ViewerHistoryGate gate;
  final time = DateTime(2026, 9, 23, 12);

  setUp(() {
    recorded = [];
    gate = ViewerHistoryGate((item, at) => recorded.add((item.id, at)));
    gate.beginSession(1);
  });

  test('後読みでページ番号が変わっても同じ閲覧を重複記録しない', () {
    final current = item(2);
    gate.settle(current, visit: 'seed:0', at: time);
    gate.loaded(current, generation: 1);
    gate.beginSession(2, preserveCurrent: current);
    gate.settle(
      current,
      visit: 'full:1',
      at: time.add(const Duration(seconds: 1)),
    );
    gate.loaded(current, generation: 2);
    expect(recorded, [(2, time)]);
    gate.settle(item(3), visit: 'full:2', at: time);
    gate.loaded(item(3), generation: 2);
    gate.settle(current, visit: 'return:1', at: time);
    expect(recorded.map((e) => e.$1), [2, 3, 2]);
  });

  test('preloaded neighbor is not recorded until it is the settled page', () {
    final first = item(1);
    final neighbor = item(2);
    gate.loaded(neighbor, generation: 1);
    gate.settle(first, visit: 'first', at: time);
    expect(recorded, isEmpty);
    gate.loaded(first, generation: 1);
    expect(recorded.map((entry) => entry.$1), [1]);
    gate.beginTransition();
    gate.settle(
      neighbor,
      visit: 'next',
      at: time.add(const Duration(seconds: 1)),
    );
    expect(recorded.map((entry) => entry.$1), [1, 2]);
  });

  test('failed or unresolved content never produces a history record', () {
    gate.settle(item(1), visit: 'first', at: time);
    gate.beginTransition();
    gate.settle(item(2), visit: 'next', at: time);
    expect(recorded, isEmpty);
  });

  test(
    'late loading uses the original settlement time and deduplicates frames',
    () {
      final first = item(1);
      gate.settle(first, visit: 'first', at: time);
      gate.loaded(first, generation: 1);
      gate.loaded(first, generation: 1);
      gate.settle(
        first,
        visit: 'first',
        at: time.add(const Duration(minutes: 1)),
      );
      expect(recorded, [(1, time)]);
    },
  );

  test('content loaded during a drag waits for actual settlement', () {
    final first = item(1);
    gate.settle(first, visit: 'first', at: time);
    gate.beginTransition();
    gate.loaded(first, generation: 1);
    expect(recorded, isEmpty);
    gate.settle(
      first,
      visit: 'first',
      at: time.add(const Duration(seconds: 1)),
    );
    expect(recorded, [(1, time)]);
  });

  test('old session callbacks cannot record even when ids and paths match', () {
    final first = item(1);
    gate.settle(first, visit: 'old', at: time);
    gate.beginSession(2);
    gate.settle(first, visit: 'new', at: time);
    gate.loaded(first, generation: 1);
    expect(recorded, isEmpty);
    gate.loaded(first, generation: 2);
    expect(recorded, [(1, time)]);
  });

  test('returning to a successfully loaded file is a new visit', () {
    final first = item(1);
    gate.loaded(first, generation: 1);
    gate.settle(first, visit: 'first', at: time);
    gate.beginTransition();
    gate.settle(item(2), visit: 'second', at: time);
    gate.beginTransition();
    final later = time.add(const Duration(minutes: 1));
    gate.settle(first, visit: 'third', at: later);
    expect(recorded, [(1, time), (1, later)]);
  });

  test('unregistered, missing and folder items do not become recent files', () {
    for (final entry in [
      item(0),
      item(1)..isMissing = true,
      item(2)..type = MediaType.folder,
    ]) {
      gate.loaded(entry, generation: 1);
      gate.settle(entry, visit: 'visit-${entry.id}', at: time);
    }
    expect(recorded, isEmpty);
  });

  test(
    'a confirmed write can finish after the viewer session changes',
    () async {
      final databaseReady = Completer<void>();
      final writes = <Future<void>>[];
      gate = ViewerHistoryGate((entry, at) {
        writes.add(
          databaseReady.future.then((_) => recorded.add((entry.id, at))),
        );
      });
      gate.beginSession(1);
      gate.loaded(item(1), generation: 1);
      gate.settle(item(1), visit: 'first', at: time);
      gate.beginSession(2);
      databaseReady.complete();
      await Future.wait(writes);
      expect(recorded, [(1, time)]);
    },
  );
}
