import 'dart:async';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/application/use_cases/get_media_stream_use_case.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _Repository extends Mock implements MediaRepository {}

class _Filter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) =>
      const MediaFilter(rootOnly: true, sourceType: MediaSourceType.localCopy);
}

void main() {
  setUpAll(() => registerFallbackValue(const MediaFilter()));

  test('通常一覧は必要な件数から読み、末尾で追加読み込みできる', () async {
    final repository = _Repository();
    final items = List.generate(450, (index) {
      return MediaItem()
        ..id = index + 1
        ..path = 'library/item_$index.jpg';
    });
    final requestedLimits = <int?>[];
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final offset = invocation.namedArguments[#offset] as int;
      final limit = invocation.namedArguments[#limit] as int;
      final filter = (invocation.namedArguments[#filter] as MediaFilter)
          .copyWith(limit: offset + limit);
      requestedLimits.add(filter.limit);
      return Result.success(items.skip(offset).take(limit).toList());
    });
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
        mediaFilterNotifierProvider(AppMode.internal).overrideWith(_Filter.new),
        getMediaStreamUseCaseProvider.overrideWith(
          (ref) => GetMediaStreamUseCase(Future.value(repository)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(libraryViewModelProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    final initialNotifier = container.read(libraryViewModelProvider.notifier);

    await container.read(libraryViewModelProvider.notifier).loadMore();
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(280),
    );
    await container.read(libraryViewModelProvider.notifier).loadMore();
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(450),
    );
    await container.read(libraryViewModelProvider.notifier).loadMore();
    expect(requestedLimits, [80, 280, 480]);
    verify(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: 80,
        limit: 200,
      ),
    ).called(1);
    verify(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: 280,
        limit: 200,
      ),
    ).called(1);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchTarget(SearchTarget.filesIncluded);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(450),
    );

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchQuery('item');
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedLimits.last, 80);
    expect(
      container.read(libraryViewModelProvider.notifier),
      same(initialNotifier),
      reason: 'filter rebuilds preserve the notifier and its paging window',
    );

    await container.read(libraryViewModelProvider.notifier).loadMore();
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(280),
    );
    expect(requestedLimits.last, 280);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .endSearch();
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(450),
    );
    expect(requestedLimits.last, 480);
    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchQuery('item');
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateOnlyCatalogs(true);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedLimits.last, 80);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchTarget(SearchTarget.filesIncluded);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedLimits.last, 80);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateSearchQuery('');
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedLimits.last, 80);
  });

  for (final lateFailure in [false, true]) {
    test('追加取得中に検索を変えても古い完了が戻らない（error=$lateFailure）', () async {
      final repository = _Repository();
      final pending = Completer<Result<List<MediaItem>, AppError>>();
      final started = Completer<void>();
      final roots = List.generate(
        80,
        (index) => MediaItem()
          ..id = index + 1
          ..path = 'library/item_$index.jpg',
      );
      final searchItem = MediaItem()
        ..id = 900
        ..path = 'library/search.jpg';
      when(
        () => repository.watchLibraryChanges(filter: any(named: 'filter')),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => repository.getPage(
          filter: any(named: 'filter'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) {
        final filter = invocation.namedArguments[#filter] as MediaFilter;
        if (filter.searchQuery == 'search') {
          return Future.value(Result.success([searchItem]));
        }
        if (invocation.namedArguments[#offset] == 0) {
          return Future.value(Result.success(roots));
        }
        started.complete();
        return pending.future;
      });
      final container = ProviderContainer(
        overrides: [
          appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_Filter.new),
          getMediaStreamUseCaseProvider.overrideWith(
            (ref) => GetMediaStreamUseCase(Future.value(repository)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        libraryViewModelProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(libraryViewModelProvider.future);
      final loading = container
          .read(libraryViewModelProvider.notifier)
          .loadMore();
      await started.future;
      container
          .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
          .updateSearchQuery('search');
      expect(await container.read(libraryViewModelProvider.future), [
        searchItem,
      ]);
      await loading.timeout(const Duration(seconds: 2));
      pending.complete(
        lateFailure
            ? Result.failure(AppError.database('late previous query'))
            : Result.success([
                MediaItem()
                  ..id = 81
                  ..path = 'library/old.jpg',
              ]),
      );
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      final state = container.read(libraryViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
      expect(state.requireValue, [searchItem]);
    });
  }

  test('タグとティアの絞り込みでも件数を区切って追加読み込みする', () async {
    final repository = _Repository();
    final items = List.generate(450, (index) {
      return MediaItem()
        ..id = index + 1
        ..path = 'library/item_$index.jpg';
    });
    final requestedFilters = <MediaFilter>[];
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final offset = invocation.namedArguments[#offset] as int;
      final limit = invocation.namedArguments[#limit] as int;
      final filter = (invocation.namedArguments[#filter] as MediaFilter)
          .copyWith(limit: offset + limit);
      requestedFilters.add(filter);
      return Result.success(items.skip(offset).take(limit).toList());
    });
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
        mediaFilterNotifierProvider(AppMode.internal).overrideWith(_Filter.new),
        getMediaStreamUseCaseProvider.overrideWith(
          (ref) => GetMediaStreamUseCase(Future.value(repository)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(libraryViewModelProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(libraryViewModelProvider.future);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateTagIds([1]);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedFilters.last.tagIds, [1]);
    expect(requestedFilters.last.limit, 80);

    await container.read(libraryViewModelProvider.notifier).loadMore();
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(280),
    );
    expect(requestedFilters.last.limit, 280);

    container
        .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
        .updateTiers([2]);
    expect(
      await container.read(libraryViewModelProvider.future),
      hasLength(80),
    );
    expect(requestedFilters.last.tagIds, [1]);
    expect(requestedFilters.last.tiers, [2]);
    expect(requestedFilters.last.limit, 80);
  });
}
