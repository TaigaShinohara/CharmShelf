import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_cover_revision_provider.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar isar;
  late IsarMediaRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('media_paging_repo_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'media_paging_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = IsarMediaRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('表紙の監視は別フォルダ更新を無視し、直下ファイル変更を通知する', () async {
    final container = ProviderContainer(
      overrides: [isarProvider.overrideWith((ref) async => isar)],
    );
    try {
      final changed = Completer<void>();
      container.listen(collectionCoverRevisionProvider('catalog'), (_, next) {
        if (next.hasValue && !changed.isCompleted) changed.complete();
      });
      await container.pump();
      final other = MediaItem()
        ..uid = 'other'
        ..path = 'other/a.jpg'
        ..parentPath = 'other';
      await isar.writeTxn(() => isar.mediaItems.put(other));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(changed.isCompleted, isFalse);
      final child = MediaItem()
        ..uid = 'child'
        ..path = 'catalog/a.jpg'
        ..parentPath = 'catalog';
      await isar.writeTxn(() => isar.mediaItems.put(child));
      await changed.future.timeout(const Duration(seconds: 2));
    } finally {
      container.dispose();
    }
  });

  test('混在分類と同日時の境界で差分ページが全件取得と一致する', () async {
    final items = List.generate(
      120,
      (i) => MediaItem()
        ..uid = 'mixed-$i'
        ..path = 'library/$i.jpg'
        ..type = i % 3 == 0 ? MediaType.folder : MediaType.file
        ..addedAt = DateTime(2026).add(Duration(seconds: i ~/ 2)),
    );
    final catalogs = [
      for (var i = 1; i < 120; i += 3)
        MediaCollection()
          ..uid = 'catalog-$i'
          ..path = items[i].path
          ..isCatalog = true,
    ];
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll(items);
      await isar.mediaCollections.putAll(catalogs);
    });
    for (final pinned in [false, true]) {
      catalogs.last.isPinned = pinned;
      await isar.writeTxn(() => isar.mediaCollections.put(catalogs.last));
      for (final order in SortOrder.values) {
        final filter = MediaFilter(rootOnly: true, sortOrder: order);
        final all = (await repository.getAll(filter: filter)).dataOrNull!;
        final paged = <MediaItem>[];
        for (var offset = 0; offset < 126; offset += 7) {
          final result = await repository.getPage(
            filter: filter,
            offset: offset,
            limit: 7,
          );
          expect(result.isSuccess, isTrue);
          paged.addAll(result.dataOrNull!);
        }
        expect(
          paged.map((i) => i.id),
          all.map((i) => i.id),
          reason: '$order pinned=$pinned',
        );
      }
    }
  });

  test('10000件の通常一覧から80件を取得する計測', () async {
    final items = List.generate(
      10000,
      (i) => MediaItem()
        ..uid = 'perf-$i'
        ..path = 'library/perf-$i.jpg'
        ..addedAt = DateTime(2026).add(Duration(seconds: i)),
    );
    await isar.writeTxn(() => isar.mediaItems.putAll(items));
    final durations = <int>[];
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      final result = await repository.getAll(
        filter: const MediaFilter(rootOnly: true, limit: 80),
      );
      watch.stop();
      durations.add(watch.elapsedMilliseconds);
      expect(result.dataOrNull, hasLength(80));
      expect(result.dataOrNull!.first.uid, 'perf-9999');
    }
    // Diagnostic only: host timings are not a device frame-rate assertion.
    // ignore: avoid_print
    print('PERF 10000 items / first 80, ms: $durations');
  });

  test('大量データでも追加日時順のlimitを正確に適用する', () async {
    final base = DateTime(2026);
    final items = List.generate(2000, (index) {
      return MediaItem()
        ..uid = 'item-$index'
        ..path = 'library/item-${index.toString().padLeft(4, '0')}.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = base.add(Duration(seconds: index))
        ..updatedAt = base.add(Duration(seconds: index));
    });
    await isar.writeTxn(() => isar.mediaItems.putAll(items));

    final result = await repository.getAll(
      filter: const MediaFilter(limit: 25, sortOrder: SortOrder.addedDesc),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, hasLength(25));
    expect(result.dataOrNull!.first.uid, 'item-1999');
    expect(result.dataOrNull!.last.uid, 'item-1975');
  });

  test('ピン留めがある場合はlimitより前に優先順位を確定する', () async {
    final base = DateTime(2026);
    final items = List.generate(20, (index) {
      return MediaItem()
        ..uid = 'item-$index'
        ..path = 'library/item-${index.toString().padLeft(2, '0')}.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = base.add(Duration(seconds: index))
        ..updatedAt = base.add(Duration(seconds: index));
    });
    final pinned = MediaCollection()
      ..uid = 'pinned-oldest'
      ..path = items.first.path
      ..title = 'Pinned oldest'
      ..type = CollectionType.file
      ..isPinned = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll(items);
      await isar.mediaCollections.put(pinned);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(limit: 3, sortOrder: SortOrder.addedDesc),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((item) => item.uid), [
      'item-0',
      'item-19',
      'item-18',
    ]);
  });

  test('別フォルダのピン留めは現在の一覧の件数制限を妨げない', () async {
    final items = List.generate(1000, (index) {
      return MediaItem()
        ..uid = 'root-$index'
        ..path = 'library/root-$index.jpg'
        ..addedAt = DateTime(2026).add(Duration(seconds: index));
    });
    final elsewhere = MediaItem()
      ..uid = 'elsewhere'
      ..path = 'library/other/pinned.jpg'
      ..parentPath = 'library/other'
      ..addedAt = DateTime(2026);
    final pinned = MediaCollection()
      ..uid = 'isar_media_repository_paging-1'
      ..path = elsewhere.path
      ..type = CollectionType.file
      ..isPinned = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([...items, elsewhere]);
      await isar.mediaCollections.put(pinned);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(rootOnly: true, limit: 25),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, hasLength(25));
    expect(result.dataOrNull!.first.uid, 'root-999');
    expect(result.dataOrNull!.last.uid, 'root-975');
  });

  test('複数のピン留めから現在のフォルダにある項目を優先する', () async {
    final oldItem = MediaItem()
      ..uid = 'folder-old'
      ..path = 'library/folder/old.jpg'
      ..parentPath = 'library/folder'
      ..addedAt = DateTime(2026);
    final newItem = MediaItem()
      ..uid = 'folder-new'
      ..path = 'library/folder/new.jpg'
      ..parentPath = 'library/folder'
      ..addedAt = DateTime(2026, 1, 2);
    final unrelated = MediaCollection()
      ..uid = 'isar_media_repository_paging-2'
      ..path = 'library/elsewhere/pinned.jpg'
      ..type = CollectionType.file
      ..isPinned = true;
    final pinned = MediaCollection()
      ..uid = 'isar_media_repository_paging-3'
      ..path = oldItem.path
      ..type = CollectionType.file
      ..isPinned = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([oldItem, newItem]);
      await isar.mediaCollections.putAll([unrelated, pinned]);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(parentPath: 'library/folder', limit: 1),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.single.uid, 'folder-old');
  });

  test('パスと異なるコレクションへの関連でもピン留め順を維持する', () async {
    final oldItem = MediaItem()
      ..uid = 'linked-old'
      ..path = 'library/linked-old.jpg'
      ..addedAt = DateTime(2026);
    final newItem = MediaItem()
      ..uid = 'new'
      ..path = 'library/new.jpg'
      ..addedAt = DateTime(2026, 1, 2);
    final pinned = MediaCollection()
      ..uid = 'isar_media_repository_paging-4'
      ..path = 'library/different-path'
      ..type = CollectionType.file
      ..isPinned = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([oldItem, newItem]);
      await isar.mediaCollections.put(pinned);
      pinned.items.add(oldItem);
      await pinned.items.save();
    });

    final result = await repository.getAll(
      filter: const MediaFilter(rootOnly: true, limit: 1),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.single.uid, 'linked-old');
  });

  test('他フォルダのピン留めが多くても、現在のフォルダの古い関連を維持する', () async {
    final oldItem = MediaItem()
      ..uid = 'linked-folder-old'
      ..path = 'library/album/old.jpg'
      ..parentPath = 'library/album'
      ..addedAt = DateTime(2026);
    final newItem = MediaItem()
      ..uid = 'folder-new'
      ..path = 'library/album/new.jpg'
      ..parentPath = 'library/album'
      ..addedAt = DateTime(2026, 1, 2);
    final unrelated = List.generate(
      9,
      (index) => MediaCollection()
        ..uid = 'isar_media_repository_paging-5'
        ..path = 'library/other/pinned-$index.jpg'
        ..type = CollectionType.file
        ..isPinned = true,
    );
    final linkedPinned = MediaCollection()
      ..uid = 'isar_media_repository_paging-6'
      ..path = 'library/legacy-link'
      ..type = CollectionType.file
      ..isPinned = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([oldItem, newItem]);
      await isar.mediaCollections.putAll([...unrelated, linkedPinned]);
      linkedPinned.items.add(oldItem);
      await linkedPinned.items.save();
    });

    final result = await repository.getAll(
      filter: const MediaFilter(
        parentPath: 'library/album',
        sourceType: MediaSourceType.localCopy,
        limit: 1,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.single.uid, 'linked-folder-old');
  });

  test('タグとティアの絞り込み後に追加日時順のlimitを適用する', () async {
    final tag = Tag()
      ..key = 'facet:filtered'
      ..name = '対象';
    final items = List.generate(4, (index) {
      return MediaItem()
        ..uid = 'filtered-$index'
        ..path = 'library/filtered-$index.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = DateTime(2026).add(Duration(days: index));
    });
    final collections = List.generate(3, (index) {
      return MediaCollection()
        ..uid = 'collection-$index'
        ..path = items[index].path
        ..type = CollectionType.file
        ..tier = 2;
    });

    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      await isar.mediaItems.putAll(items);
      await isar.mediaCollections.putAll(collections);
      for (var index = 0; index < collections.length; index++) {
        collections[index].tags.add(tag);
        await collections[index].tags.save();
        collections[index].items.add(items[index]);
        await collections[index].items.save();
      }
    });

    final unpaged = await repository.getAll(
      filter: MediaFilter(tagIds: [tag.id], tiers: const [2]),
    );
    expect(unpaged.dataOrNull?.map((item) => item.uid), [
      'filtered-2',
      'filtered-1',
      'filtered-0',
    ]);

    final result = await repository.getAll(
      filter: MediaFilter(tagIds: [tag.id], tiers: const [2], limit: 2),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((item) => item.uid), [
      'filtered-2',
      'filtered-1',
    ]);
  });

  test('カタログ一覧は並び順とピン留めを保って件数を制限する', () async {
    final items = List.generate(4, (index) {
      return MediaItem()
        ..uid = 'catalog-item-$index'
        ..path = 'library/catalog-$index'
        ..type = MediaType.folder
        ..addedAt = DateTime(2026).add(Duration(days: index));
    });
    final collections = List.generate(4, (index) {
      return MediaCollection()
        ..uid = 'catalog-$index'
        ..path = items[index].path
        ..title = 'カタログ$index'
        ..isCatalog = true;
    });
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll(items);
      await isar.mediaCollections.putAll(collections);
    });

    const filter = MediaFilter(onlyCatalogs: true, limit: 2);
    final unpinned = await repository.getAll(filter: filter);
    expect(unpinned.isSuccess, isTrue);
    expect(unpinned.dataOrNull!.map((item) => item.uid), [
      'catalog-item-3',
      'catalog-item-2',
    ]);

    collections.first.isPinned = true;
    await isar.writeTxn(() => isar.mediaCollections.put(collections.first));
    final pinned = await repository.getAll(filter: filter);
    expect(pinned.isSuccess, isTrue);
    expect(pinned.dataOrNull!.map((item) => item.uid), [
      'catalog-item-0',
      'catalog-item-3',
    ]);
  });

  test('親フォルダの索引検索でも状態フィルタと検索範囲を保つ', () async {
    final child = MediaItem()
      ..uid = 'child'
      ..path = 'library/album/child.jpg'
      ..parentPath = 'library/album';
    final archived = MediaItem()
      ..uid = 'archived'
      ..path = 'library/album/archived.jpg'
      ..parentPath = 'library/album'
      ..isArchived = true;
    final trashed = MediaItem()
      ..uid = 'trashed'
      ..path = 'library/album/trashed.jpg'
      ..parentPath = 'library/album'
      ..isTrashed = true;
    final outside = MediaItem()
      ..uid = 'outside'
      ..path = 'library/other/outside.jpg'
      ..parentPath = 'library/other';
    await isar.writeTxn(
      () => isar.mediaItems.putAll([child, archived, trashed, outside]),
    );

    final children = await repository.getByParentPath('library/album');
    expect(children.isSuccess, isTrue);
    expect(children.dataOrNull!.map((item) => item.uid), ['child']);

    final paged = await repository.getAll(
      filter: const MediaFilter(
        parentPath: 'library/album',
        rootOnly: true,
        isArchived: false,
        limit: 1,
      ),
    );
    expect(paged.isSuccess, isTrue);
    expect(paged.dataOrNull!.map((item) => item.uid), ['child']);

    final search = await repository.getAll(
      filter: const MediaFilter(
        parentPath: 'library/album',
        searchQuery: 'outside',
      ),
    );
    expect(search.isSuccess, isTrue);
    expect(search.dataOrNull!.map((item) => item.uid), ['outside']);
  });

  test('通常一覧は無関係なカタログ更新を無視し、表示中の変更とピン留めを反映する', () async {
    final recent = MediaItem()
      ..uid = 'recent'
      ..path = 'library/recent.jpg'
      ..addedAt = DateTime(2026, 1, 2);
    final older = MediaItem()
      ..uid = 'older'
      ..path = 'library/older.jpg'
      ..addedAt = DateTime(2026);
    final visibleCollection = MediaCollection()
      ..uid = 'isar_media_repository_paging-7'
      ..path = recent.path
      ..title = 'Recent';
    final offscreenCollection = MediaCollection()
      ..uid = 'isar_media_repository_paging-8'
      ..path = older.path
      ..title = 'Older';
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([recent, older]);
      await isar.mediaCollections.putAll([
        visibleCollection,
        offscreenCollection,
      ]);
    });

    final iterator = StreamIterator(
      repository.watchAll(filter: const MediaFilter(rootOnly: true, limit: 1)),
    );
    addTearDown(iterator.cancel);
    expect(
      await iterator.moveNext().timeout(const Duration(seconds: 2)),
      isTrue,
    );
    expect(iterator.current.single.uid, 'recent');

    var received = false;
    final next = iterator.moveNext().then((value) {
      received = true;
      return value;
    });
    offscreenCollection.title = 'Changed elsewhere';
    await isar.writeTxn(() => isar.mediaCollections.put(offscreenCollection));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(received, isFalse);

    visibleCollection.title = 'Changed here';
    await isar.writeTxn(() => isar.mediaCollections.put(visibleCollection));
    expect(await next.timeout(const Duration(seconds: 2)), isTrue);
    expect(iterator.current.single.collection.value?.title, 'Changed here');

    offscreenCollection.isPinned = true;
    await isar.writeTxn(() => isar.mediaCollections.put(offscreenCollection));
    expect(
      await iterator.moveNext().timeout(const Duration(seconds: 2)),
      isTrue,
    );
    expect(iterator.current.single.uid, 'older');
  });
  test('既定順は分類とピン留めをlimit前に適用し、日時順とは区別する', () async {
    final folder = MediaItem()
      ..uid = 'folder'
      ..path = 'library/folder'
      ..type = MediaType.folder
      ..addedAt = DateTime(2020);
    final catalogItem = MediaItem()
      ..uid = 'catalog'
      ..path = 'library/catalog'
      ..addedAt = DateTime(2021);
    final file = MediaItem()
      ..uid = 'file'
      ..path = 'library/new.jpg'
      ..addedAt = DateTime(2026);
    final catalog = MediaCollection()
      ..uid = 'catalog-meta'
      ..path = catalogItem.path
      ..isCatalog = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([file, catalogItem, folder]);
      await isar.mediaCollections.put(catalog);
    });
    Future<List<String?>> ids(SortOrder order, int limit) async =>
        (await repository.getAll(
          filter: MediaFilter(rootOnly: true, sortOrder: order, limit: limit),
        )).dataOrNull!.map((item) => item.uid).toList();
    expect(await ids(SortOrder.addedDesc, 2), ['folder', 'catalog']);
    expect(await ids(SortOrder.dateDesc, 2), ['file', 'catalog']);
    catalog.isPinned = true;
    await isar.writeTxn(() => isar.mediaCollections.put(catalog));
    expect(await ids(SortOrder.addedDesc, 1), ['catalog']);
  });

  test('画面外のカタログ化と表示中の属性・非表示・アーカイブ変更を取りこぼさない', () async {
    final recent = MediaItem()
      ..uid = 'recent'
      ..path = 'library/recent.jpg'
      ..addedAt = DateTime(2026);
    final older = MediaItem()
      ..uid = 'older'
      ..path = 'library/older.jpg'
      ..addedAt = DateTime(2020);
    final collection = MediaCollection()
      ..uid = 'older-catalog'
      ..path = older.path;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([recent, older]);
      await isar.mediaCollections.put(collection);
    });
    final iterator = StreamIterator(
      repository.watchAll(filter: const MediaFilter(rootOnly: true, limit: 1)),
    );
    addTearDown(iterator.cancel);
    Future<MediaItem> next() async {
      expect(
        await iterator.moveNext().timeout(const Duration(seconds: 2)),
        isTrue,
      );
      return iterator.current.single;
    }

    expect((await next()).uid, 'recent');
    collection.isCatalog = true;
    await isar.writeTxn(() => isar.mediaCollections.put(collection));
    expect((await next()).uid, 'older');
    collection.alias = '新しい別名';
    collection.notes = '新しいメモ';
    collection.tier = 5;
    await isar.writeTxn(() => isar.mediaCollections.put(collection));
    final changed = (await next()).collection.value!;
    expect(changed.alias, '新しい別名');
    expect(changed.notes, '新しいメモ');
    expect(changed.tier, 5);
    older.isHidden = true;
    await isar.writeTxn(() => isar.mediaItems.put(older));
    expect((await next()).uid, 'recent');
    older.isHidden = false;
    await isar.writeTxn(() => isar.mediaItems.put(older));
    expect((await next()).uid, 'older');
    older.isArchived = true;
    await isar.writeTxn(() => isar.mediaItems.put(older));
    expect((await next()).uid, 'recent');
    older.isArchived = false;
    await isar.writeTxn(() => isar.mediaItems.put(older));
    expect((await next()).uid, 'older');
    older.isTrashed = true;
    await isar.writeTxn(() => isar.mediaItems.put(older));
    expect((await next()).uid, 'recent');
  });
  test('読込エラー後は表示内容が同じでも復旧結果を通知する', () async {
    final recent = MediaItem()
      ..uid = 'recent'
      ..path = 'library/recent.jpg'
      ..addedAt = DateTime(2026);
    final offscreen = MediaCollection()
      ..uid = 'offscreen'
      ..path = 'elsewhere';
    await isar.writeTxn(() async {
      await isar.mediaItems.put(recent);
      await isar.mediaCollections.put(offscreen);
    });
    final fault = _ReadFailureIsar(isar);
    final first = Completer<void>();
    final failed = Completer<void>();
    final recovered = Completer<void>();
    var emissions = 0;
    final subscription = IsarMediaRepository(fault)
        .watchAll(filter: const MediaFilter(rootOnly: true, limit: 1))
        .listen(
          (items) {
            expect(items.single.uid, 'recent');
            emissions++;
            if (!first.isCompleted) {
              first.complete();
            } else {
              recovered.complete();
            }
          },
          onError: (Object error) {
            expect(error, isStateError);
            failed.complete();
          },
        );
    addTearDown(subscription.cancel);
    await first.future.timeout(const Duration(seconds: 2));
    fault.failReads = true;
    offscreen.title = 'trigger failure';
    await isar.writeTxn(() => isar.mediaCollections.put(offscreen));
    await failed.future.timeout(const Duration(seconds: 2));
    fault.failReads = false;
    offscreen.title = 'trigger recovery';
    await isar.writeTxn(() => isar.mediaCollections.put(offscreen));
    await recovered.future.timeout(const Duration(seconds: 2));
    expect(emissions, 2);
  });
}

class _ReadFailureIsar extends Fake implements Isar {
  _ReadFailureIsar(this.delegate);
  final Isar delegate;
  bool failReads = false;

  @override
  IsarCollection<T> collection<T>() {
    if (failReads && T == MediaItem) throw StateError('temporary read failure');
    return delegate.collection<T>();
  }
}
