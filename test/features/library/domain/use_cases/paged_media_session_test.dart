import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/use_cases/get_media_stream_use_case.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class _Repository extends Mock implements MediaRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const MediaFilter()));

  test('同じ表示結果は再通知せず、内容変更・末尾取得・エラー復帰は通知する', () async {
    final repository = _Repository();
    final changes = StreamController<void>();
    final limits = StreamController<int>();
    final item = MediaItem()
      ..id = 1
      ..path = 'library/one.jpg';
    final events = <List<String>>[];
    final errors = <Object>[];
    var fail = false;
    var calls = 0;
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => changes.stream);
    when(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      calls++;
      if (fail) return Result.failure(AppError.database('fixture failure'));
      final offset = invocation.namedArguments[#offset] as int;
      return Result.success(offset == 0 ? [item] : <MediaItem>[]);
    });
    final subscription = GetMediaStreamUseCase(Future.value(repository))
        .invokePaged(const MediaFilter(limit: 1), limits.stream)
        .listen(
          (items) => events.add(items.map((i) => i.path).toList()),
          onError: errors.add,
        );
    addTearDown(() async {
      await subscription.cancel();
      await limits.close();
      await changes.close();
    });
    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    await settle();
    expect(events, hasLength(1));
    changes.add(null);
    await settle();
    expect(calls, 2);
    expect(events, hasLength(1));

    // The same mutable Isar instance must not hide a real change.
    item.path = 'library/renamed.jpg';
    changes.add(null);
    await settle();
    expect(events.last, ['library/renamed.jpg']);
    expect(events, hasLength(2));

    // Empty final pages still settle the caller's loadMore spinner.
    limits.add(3);
    await settle();
    expect(events, hasLength(3));
    fail = true;
    changes.add(null);
    await settle();
    expect(errors, hasLength(1));
    fail = false;
    changes.add(null);
    await settle();
    expect(events, hasLength(4));
    expect(events.last, ['library/renamed.jpg']);
    changes.addError(StateError('watch temporarily unavailable'));
    await settle();
    expect(errors, hasLength(2));
    changes.add(null);
    await settle();
    expect(events, hasLength(5));
  });

  test('追加読込中の更新では古いページを捨て、表示窓を一括更新する', () async {
    final repository = _Repository();
    final changes = StreamController<void>();
    final limits = StreamController<int>();
    final oldPage = Completer<Result<List<MediaItem>, AppError>>();
    final appendStarted = Completer<void>();
    final refreshed = Completer<void>();
    final events = <List<int>>[];
    var calls = 0;
    MediaItem item(int id) => MediaItem()..id = id;
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => changes.stream);
    when(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      calls++;
      if (calls == 1) return Result.success([item(1), item(2)]);
      if (calls == 2) {
        appendStarted.complete();
        return oldPage.future;
      }
      expect(invocation.namedArguments[#offset], 0);
      expect(invocation.namedArguments[#limit], 4);
      return Result.success([item(5), item(1), item(2), item(3)]);
    });
    final initial = Completer<void>();
    final subscription = GetMediaStreamUseCase(Future.value(repository))
        .invokePaged(const MediaFilter(limit: 2), limits.stream)
        .listen((items) {
          events.add(items.map((i) => i.id).toList());
          if (events.length == 1) initial.complete();
          if (events.length == 2) refreshed.complete();
        });
    await initial.future;
    limits.add(4);
    await appendStarted.future;
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    oldPage.complete(Result.success([item(3), item(4)]));
    await refreshed.future.timeout(const Duration(seconds: 2));
    expect(events, [
      [1, 2],
      [5, 1, 2, 3],
    ]);
    await subscription.cancel();
    await limits.close();
    await changes.close();
  });
}
