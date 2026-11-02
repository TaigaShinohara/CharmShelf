import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/data/repositories/viewing_history_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late Isar isar;
  late ViewingHistoryRepository repository;
  late String databaseName;
  final oldSchemas = [
    MediaCollectionSchema,
    MediaItemSchema,
    TagSchema,
    TagFacetSchema,
    StorageRefSchema,
  ];
  final baseTime = DateTime.utc(2026, 9, 23);

  Future<void> save(MediaItem item) => isar.writeTxn(() async {
    await isar.mediaItems.put(item);
  });

  MediaItem file(String uid, {String? path, String? parentPath}) => MediaItem()
    ..uid = uid
    ..path = path ?? 'library/$uid.txt'
    ..parentPath = parentPath
    ..type = MediaType.file
    ..sourceType = MediaSourceType.localCopy;

  Future<MediaItem?> latest({bool includeHidden = false}) => repository.latest(
    sourceType: MediaSourceType.localCopy,
    includeHidden: includeHidden,
  );

  // External histories are fixtures from the retired version, never new writes.
  Future<void> recordFixtureHistory(
    MediaItem item, {
    DateTime? openedAt,
  }) async {
    if (item.sourceType == MediaSourceType.externalReference) {
      await isar.writeTxn(() async {
        await isar.viewingHistorys.put(
          ViewingHistory()
            ..itemUid = item.uid!
            ..openedAt = openedAt ?? DateTime.now(),
        );
      });
    } else {
      await repository.record(item, openedAt: openedAt);
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('viewing_history_');
    databaseName = 'history_${DateTime.now().microsecondsSinceEpoch}';
    isar = await Isar.open(
      [...oldSchemas, ViewingHistorySchema],
      directory: directory.path,
      name: databaseName,
    );
    repository = ViewingHistoryRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'recent returns up to three eligible files in unique viewing order',
    () async {
      Future<List<String?>> uids({bool hidden = false}) async =>
          (await repository.recent(
            sourceType: MediaSourceType.localCopy,
            includeHidden: hidden,
          )).map((entry) => entry.item.uid).toList();
      expect(await uids(), isEmpty);
      final items = [for (var i = 0; i < 5; i++) file('recent-$i')];
      for (var i = 0; i < items.length; i++) {
        await save(items[i]);
        await recordFixtureHistory(
          items[i],
          openedAt: baseTime.add(Duration(seconds: i)),
        );
        expect((await uids()).length, i < 3 ? i + 1 : 3);
      }
      expect(await uids(), ['recent-4', 'recent-3', 'recent-2']);
      items[4].isHidden = true;
      await save(items[4]);
      items[3].isMissing = true;
      await save(items[3]);
      expect(await uids(), ['recent-2', 'recent-1', 'recent-0']);
      expect(await uids(hidden: true), ['recent-4', 'recent-2', 'recent-1']);
      await recordFixtureHistory(
        items[0],
        openedAt: baseTime.add(const Duration(days: 1)),
      );
      expect(await uids(), ['recent-0', 'recent-2', 'recent-1']);
    },
  );

  test(
    'recent resolves linked catalogs, nearest ancestors and external logical parents',
    () async {
      final linked = file('linked');
      final nested = file('nested', path: 'library/outer/inner/nested.txt');
      final external = file(
        'external',
        path: 'content://provider/document/child',
        parentPath: 'content://provider/tree/root',
      )..sourceType = MediaSourceType.externalReference;
      final catalogs = [
        MediaCollection()
          ..path = 'library/elsewhere'
          ..title = 'Linked'
          ..alias = 'Alias'
          ..isCatalog = true,
        MediaCollection()
          ..path = 'library/outer'
          ..title = 'Outer'
          ..isCatalog = true,
        MediaCollection()
          ..path = 'library/outer/inner'
          ..title = 'Inner'
          ..isCatalog = true,
        MediaCollection()
          ..path = external.parentPath!
          ..title = 'External'
          ..isCatalog = true
          ..type = CollectionType.externalFolder,
      ];
      for (var i = 0; i < catalogs.length; i++) {
        catalogs[i].uid = 'catalog-$i';
      }
      await isar.writeTxn(() async {
        await isar.mediaItems.putAll([linked, nested, external]);
        await isar.mediaCollections.putAll(catalogs);
        catalogs.first.items.add(linked);
        await catalogs.first.items.save();
      });
      final viewedItems = [linked, nested, external];
      for (var i = 0; i < viewedItems.length; i++) {
        await recordFixtureHistory(
          viewedItems[i],
          openedAt: baseTime.add(Duration(seconds: i)),
        );
      }
      final local = await repository.recent(
        sourceType: MediaSourceType.localCopy,
        includeHidden: false,
      );
      expect(local.first.catalog?.title, 'Inner');
      expect(local.last.catalog?.alias, 'Alias');
      final remote = await repository.recent(
        sourceType: MediaSourceType.externalReference,
        includeHidden: false,
      );
      expect(remote.single.catalog?.title, 'External');
      catalogs[2].isCatalog = false;
      await isar.writeTxn(() async => isar.mediaCollections.put(catalogs[2]));
      expect(
        (await repository.recent(
          sourceType: MediaSourceType.localCopy,
          includeHidden: false,
        )).first.catalog?.title,
        'Outer',
      );
    },
  );

  test('watchRecent refreshes catalog names and catalog removal', () async {
    final item = file('child', path: 'library/catalog/child.txt');
    final catalog = MediaCollection()
      ..path = 'library/catalog'
      ..title = 'Original'
      ..isCatalog = true;
    await save(item);
    await isar.writeTxn(() async => isar.mediaCollections.put(catalog));
    await recordFixtureHistory(item);
    final iterator = StreamIterator(
      repository.watchRecent(
        sourceType: MediaSourceType.localCopy,
        includeHidden: false,
      ),
    );
    addTearDown(iterator.cancel);
    Future<void> nextName(String? name) async {
      await (() async {
        while (await iterator.moveNext()) {
          if (iterator.current.single.catalog?.alias == name) return;
        }
        fail('History stream ended before catalog update');
      })().timeout(const Duration(seconds: 5));
    }

    await nextName(null);
    catalog.alias = 'Renamed';
    await isar.writeTxn(() async => isar.mediaCollections.put(catalog));
    await nextName('Renamed');
    catalog.isCatalog = false;
    await isar.writeTxn(() async => isar.mediaCollections.put(catalog));
    await nextName(null);
    expect(iterator.current.single.catalog, isNull);
  });

  test(
    'ordinary files get a persistent UID and reopen without a catalog',
    () async {
      final item = file('temporary')..uid = null;
      await save(item);
      await recordFixtureHistory(item, openedAt: baseTime);

      final stored = (await isar.mediaItems.get(item.id))!;
      expect(stored.uid, isNotEmpty);
      expect(await isar.mediaCollections.count(), 0);
      final entry = (await isar.viewingHistorys.where().findAll()).single;
      expect(entry.itemUid, stored.uid);
      expect(entry.openedAt.toUtc(), baseTime);

      await isar.close();
      isar = await Isar.open(
        [...oldSchemas, ViewingHistorySchema],
        directory: directory.path,
        name: databaseName,
      );
      repository = ViewingHistoryRepository(isar);
      expect((await latest())?.uid, stored.uid);
      expect((await latest())?.path, item.path);
    },
  );

  test(
    'recording again upserts and only the 50 most recent files remain',
    () async {
      final items = [for (var i = 0; i < 52; i++) file('item-$i')];
      await isar.writeTxn(() async => isar.mediaItems.putAll(items));
      for (var i = 0; i < items.length; i++) {
        await recordFixtureHistory(
          items[i],
          openedAt: baseTime.add(Duration(seconds: i)),
        );
      }
      expect(await isar.viewingHistorys.count(), 50);
      expect(
        await isar.viewingHistorys
            .filter()
            .itemUidEqualTo('item-0')
            .findFirst(),
        isNull,
      );
      expect(
        await isar.viewingHistorys
            .filter()
            .itemUidEqualTo('item-1')
            .findFirst(),
        isNull,
      );

      final previous = (await isar.viewingHistorys
          .filter()
          .itemUidEqualTo('item-2')
          .findFirst())!;
      await recordFixtureHistory(
        items[2],
        openedAt: baseTime.add(const Duration(days: 1)),
      );
      final updated = (await isar.viewingHistorys
          .filter()
          .itemUidEqualTo('item-2')
          .findFirst())!;
      expect(updated.id, previous.id);
      expect(updated.openedAt.toUtc(), baseTime.add(const Duration(days: 1)));
      expect(await isar.viewingHistorys.count(), 50);
      expect((await latest())?.uid, 'item-2');
    },
  );

  final inaccessible = <String, void Function(MediaItem)>{
    'hidden': (item) => item.isHidden = true,
    'archived': (item) => item.isArchived = true,
    'trashed': (item) => item.isTrashed = true,
    'missing': (item) => item.isMissing = true,
  };
  for (final state in inaccessible.entries) {
    test(
      'latest skips a ${state.key} entry and returns the next eligible file',
      () async {
        final older = file('older');
        final newer = file('newer');
        await save(older);
        await save(newer);
        await recordFixtureHistory(older, openedAt: baseTime);
        await recordFixtureHistory(
          newer,
          openedAt: baseTime.add(const Duration(seconds: 1)),
        );
        state.value(newer);
        await save(newer);
        expect((await latest())?.uid, older.uid);
        expect(
          (await latest(includeHidden: true))?.uid,
          state.key == 'hidden' ? newer.uid : older.uid,
        );
      },
    );
  }

  test(
    'a hidden catalog blocks linked items even outside its path hierarchy',
    () async {
      final item = file('linked');
      final collection = MediaCollection()
        ..uid = 'catalog'
        ..path = 'library/unrelated'
        ..isHidden = true;
      await isar.writeTxn(() async {
        await isar.mediaItems.put(item);
        await isar.mediaCollections.put(collection);
        collection.items.add(item);
        await collection.items.save();
      });
      await recordFixtureHistory(item, openedAt: baseTime);
      expect(await latest(), isNull);
      expect((await latest(includeHidden: true))?.uid, item.uid);
    },
  );

  test('an unlinked parent catalog controls descendant visibility', () async {
    final item = file('child', path: 'library/parent/sub/child.txt');
    final collection = MediaCollection()
      ..uid = 'ancestor'
      ..path = 'library/parent'
      ..isHidden = true;
    await save(item);
    await isar.writeTxn(() async => isar.mediaCollections.put(collection));
    await recordFixtureHistory(item);
    expect(await latest(), isNull);
    expect((await latest(includeHidden: true))?.uid, item.uid);
    collection
      ..isHidden = false
      ..isArchived = true;
    await isar.writeTxn(() async => isar.mediaCollections.put(collection));
    expect(await latest(includeHidden: true), isNull);
    collection
      ..isArchived = false
      ..isTrashed = true;
    await isar.writeTxn(() async => isar.mediaCollections.put(collection));
    expect(await latest(includeHidden: true), isNull);
  });

  test('a hidden parent folder hides ordinary descendants', () async {
    final parent = file('parent', path: 'library/parent')
      ..type = MediaType.folder
      ..isHidden = true;
    final child = file(
      'child',
      path: 'library/parent/child.txt',
      parentPath: parent.path,
    );
    await save(parent);
    await save(child);
    await recordFixtureHistory(child);
    expect(await latest(), isNull);
    expect((await latest(includeHidden: true))?.uid, child.uid);
  });

  test(
    'external logical parent chains are followed beyond the immediate parent',
    () async {
      final ancestor =
          file('ancestor', path: 'content://provider/document/root')
            ..type = MediaType.folder
            ..sourceType = MediaSourceType.externalReference
            ..isHidden = true;
      final parent =
          file(
              'parent',
              path: 'content://provider/document/child',
              parentPath: ancestor.path,
            )
            ..type = MediaType.folder
            ..sourceType = MediaSourceType.externalReference;
      final child = file(
        'child',
        path: 'content://provider/document/file',
        parentPath: parent.path,
      )..sourceType = MediaSourceType.externalReference;
      await isar.writeTxn(
        () async => isar.mediaItems.putAll([ancestor, parent, child]),
      );
      await recordFixtureHistory(child);
      expect(
        await repository.latest(
          sourceType: MediaSourceType.externalReference,
          includeHidden: false,
        ),
        isNull,
      );
      expect(
        (await repository.latest(
          sourceType: MediaSourceType.externalReference,
          includeHidden: true,
        ))?.uid,
        child.uid,
      );
    },
  );

  test(
    'source type is checked and a vanished UID never resolves to a reused path',
    () async {
      final local = file('local');
      final external = file('external')
        ..sourceType = MediaSourceType.externalReference;
      await save(local);
      await save(external);
      await recordFixtureHistory(local, openedAt: baseTime);
      await recordFixtureHistory(
        external,
        openedAt: baseTime.add(const Duration(seconds: 1)),
      );
      expect((await latest())?.uid, local.uid);
      expect(
        (await repository.latest(
          sourceType: MediaSourceType.externalReference,
          includeHidden: false,
        ))?.uid,
        external.uid,
      );
      await isar.writeTxn(() async {
        await isar.mediaItems.delete(external.id);
        await isar.mediaItems.put(
          file('replacement', path: external.path)
            ..sourceType = MediaSourceType.externalReference,
        );
      });
      expect(
        await repository.latest(
          sourceType: MediaSourceType.externalReference,
          includeHidden: false,
        ),
        isNull,
      );
      expect((await latest())?.uid, local.uid);
    },
  );

  test(
    'delayed record cannot attach to a different UID reusing the same id and path',
    () async {
      final old = file('old');
      await save(old);
      await isar.writeTxn(() async => isar.clear());
      final replacement = file('new', path: old.path)..id = old.id;
      await save(replacement);
      await recordFixtureHistory(old, openedAt: baseTime);
      expect(await isar.viewingHistorys.count(), 0);
      expect(await latest(), isNull);
      await recordFixtureHistory(
        replacement,
        openedAt: baseTime.add(const Duration(seconds: 1)),
      );
      expect((await latest())?.uid, 'new');
    },
  );

  test(
    'a delayed older record never moves an existing history timestamp backwards',
    () async {
      final item = file('delayed');
      await save(item);
      final newer = baseTime.add(const Duration(minutes: 1));
      await recordFixtureHistory(item, openedAt: newer);
      await recordFixtureHistory(item, openedAt: baseTime);
      final entry = (await isar.viewingHistorys.where().findAll()).single;
      expect(entry.openedAt.toUtc(), newer);
    },
  );

  test(
    'moving a file preserves its history UID and resolves its new path',
    () async {
      final item = file('moved');
      await save(item);
      await recordFixtureHistory(item, openedAt: baseTime);
      item
        ..path = 'library/destination/moved.txt'
        ..parentPath = 'library/destination';
      await save(item);
      expect((await latest())?.uid, item.uid);
      expect((await latest())?.path, 'library/destination/moved.txt');
    },
  );

  test(
    'folders, deleted items and stale item paths are not recorded',
    () async {
      final folder = file('folder')..type = MediaType.folder;
      await save(folder);
      await recordFixtureHistory(folder);
      final item = file('changed');
      await save(item);
      final stale = file('changed', path: 'library/old.txt')..id = item.id;
      await recordFixtureHistory(stale);
      await isar.writeTxn(() async => isar.mediaItems.delete(item.id));
      await recordFixtureHistory(item);
      expect(await isar.viewingHistorys.count(), 0);
    },
  );

  test(
    'watchLatest refreshes after item, parent catalog and history changes',
    () async {
      final older = file('older');
      final newer = file('newer', path: 'library/catalog/newer.txt');
      final collection = MediaCollection()
        ..uid = 'catalog'
        ..path = 'library/catalog';
      await save(older);
      await save(newer);
      await isar.writeTxn(() async => isar.mediaCollections.put(collection));
      await recordFixtureHistory(older, openedAt: baseTime);
      final iterator = StreamIterator(
        repository.watchLatest(
          sourceType: MediaSourceType.localCopy,
          includeHidden: false,
        ),
      );
      addTearDown(iterator.cancel);
      Future<void> nextUid(String? uid) async {
        await (() async {
          while (await iterator.moveNext()) {
            if (iterator.current?.uid == uid) return;
          }
          fail('History stream ended before $uid');
        })().timeout(const Duration(seconds: 5));
      }

      await nextUid(older.uid);
      await recordFixtureHistory(
        newer,
        openedAt: baseTime.add(const Duration(seconds: 1)),
      );
      await nextUid(newer.uid);
      newer.isHidden = true;
      await save(newer);
      await nextUid(older.uid);
      newer.isHidden = false;
      await save(newer);
      await nextUid(newer.uid);
      collection.isHidden = true;
      await isar.writeTxn(() async => isar.mediaCollections.put(collection));
      await nextUid(older.uid);
    },
  );

  test(
    'adding the history schema to an existing database preserves user data',
    () async {
      await isar.close(deleteFromDisk: true);
      isar = await Isar.open(
        oldSchemas,
        directory: directory.path,
        name: databaseName,
      );
      final item = file('existing')..isFavorite = true;
      final tag = Tag()
        ..name = 'My tag'
        ..key = 'test:my-tag';
      final catalog = MediaCollection()
        ..uid = 'existing-catalog'
        ..path = 'library/existing-catalog'
        ..alias = 'My custom name'
        ..notes = 'My notes'
        ..isFavorite = true;
      await isar.writeTxn(() async {
        await isar.mediaItems.put(item);
        await isar.tags.put(tag);
        await isar.mediaCollections.put(catalog);
        catalog.items.add(item);
        await catalog.items.save();
        catalog.tags.add(tag);
        await catalog.tags.save();
      });
      await isar.close();
      isar = await Isar.open(
        [...oldSchemas, ViewingHistorySchema],
        directory: directory.path,
        name: databaseName,
      );
      repository = ViewingHistoryRepository(isar);

      final restored = (await isar.mediaCollections.get(catalog.id))!;
      await restored.items.load();
      await restored.tags.load();
      expect(restored.alias, 'My custom name');
      expect(restored.notes, 'My notes');
      expect(restored.isFavorite, isTrue);
      expect(restored.items.single.uid, item.uid);
      expect(restored.tags.single.key, tag.key);
      expect((await isar.mediaItems.get(item.id))!.isFavorite, isTrue);
      expect(await isar.viewingHistorys.count(), 0);
      await recordFixtureHistory(item, openedAt: baseTime);
      expect((await latest())?.uid, item.uid);
    },
  );
}
