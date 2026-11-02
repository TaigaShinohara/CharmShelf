import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schemas = [
    MediaCollectionSchema,
    MediaItemSchema,
    ReferenceMigrationSchema,
    StorageRefSchema,
    TagSchema,
    TagFacetSchema,
    ViewingHistorySchema,
  ];

  test('analyzer port retains the seven pre-update collection identifiers', () {
    expect(
      {for (final schema in schemas) schema.name: schema.id},
      {
        'MediaCollection': 1870953031712495552,
        'MediaItem': 3893864289923902342,
        'ReferenceMigration': 8271158385351128976,
        'StorageRef': 2768276394694657656,
        'Tag': 4007045862261149568,
        'TagFacet': 6985959598902521147,
        'ViewingHistory': -1411224508816741929,
      },
    );
    expect(schemas.map((schema) => schema.version).toSet(), {'3.1.0+1'});
  });

  test(
    'synthetic data, indexes and links survive database close and reopen',
    () async {
      // This owned directory is the only disk location the test opens or removes.
      final directory = await Directory.systemTemp.createTemp('isar_codegen_');
      final name = 'compat_${DateTime.now().microsecondsSinceEpoch}';
      Isar? database;
      final timestamp = DateTime.utc(2026, 10, 22, 1, 2, 3, 456, 789);
      try {
        final initial = await Isar.open(
          schemas,
          directory: directory.path,
          name: name,
        );
        database = initial;
        final facet = TagFacet()
          ..name = 'synthetic facet'
          ..createdAt = timestamp;
        final tag = Tag()
          ..key = 'synthetic::tag'
          ..name = '日本語と emoji 📚'
          ..ancestorIds = [101, 202]
          ..colorValue = 0xFF123456
          ..isHidden = true
          ..createdAt = timestamp;
        final item = MediaItem()
          ..uid = 'synthetic-item'
          ..path = 'library/synthetic/file.txt'
          ..originalPath = '/synthetic/source.txt'
          ..sourceType = MediaSourceType.externalReference
          ..type = MediaType.file
          ..size = 123456789012
          ..addedAt = timestamp
          ..updatedAt = timestamp
          ..isHidden = true
          ..isTrashed = true
          ..trashedAt = timestamp
          ..trashRootPath = 'library/synthetic';
        final collection = MediaCollection()
          ..uid = 'synthetic-collection'
          ..path = 'library/synthetic'
          ..title = 'Synthetic catalog'
          ..alias = '別名'
          ..type = CollectionType.externalFolder
          ..defaultSortOrder = SortOrder.updatedAsc
          ..defaultViewMode = ViewMode.grid
          ..createdAt = timestamp
          ..updatedAt = timestamp
          ..lastViewedAt = timestamp
          ..notes = 'line 1\nline 2'
          ..tier = 4;
        final storage = StorageRef()
          ..uid = 'synthetic-storage'
          ..ownerUid = 'synthetic-item'
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.external
          ..locator = 'content://synthetic/document/42'
          ..normalizedLocator = null
          ..isPrimary = false
          ..createdAt = timestamp
          ..updatedAt = timestamp;
        final migration = ReferenceMigration()
          ..key = 'synthetic-migration'
          ..snapshot = '{"source":"synthetic"}'
          ..checkpoints = '{"copied":true}'
          ..committed = true
          ..cleanupPending = false;
        await initial.writeTxn(() async {
          await initial.tagFacets.put(facet);
          tag.facetId = facet.id;
          await initial.tags.put(tag);
          await initial.mediaItems.put(item);
          collection.lastViewedItemId = item.id;
          await initial.mediaCollections.put(collection);
          collection.items.add(item);
          collection.tags.add(tag);
          await collection.items.save();
          await collection.tags.save();
          await initial.storageRefs.put(storage);
          await initial.referenceMigrations.put(migration);
          await initial.viewingHistorys.put(
            ViewingHistory()
              ..itemUid = item.uid!
              ..openedAt = timestamp,
          );
        });
        await initial.close();
        final reopened = await Isar.open(
          schemas,
          directory: directory.path,
          name: name,
        );
        database = reopened;

        final savedItem = await reopened.mediaItems
            .filter()
            .uidEqualTo('synthetic-item')
            .findFirst();
        expect(savedItem, isNotNull);
        expect(savedItem!.id, item.id);
        expect(savedItem.sourceType, MediaSourceType.externalReference);
        expect(savedItem.size, 123456789012);
        expect(savedItem.trashedAt!.toUtc(), timestamp);
        expect(savedItem.isHidden, isTrue);
        expect(savedItem.isTrashed, isTrue);
        expect(savedItem.thumbnailPath, isNull);
        await savedItem.collection.load();
        expect(savedItem.collection.value?.id, collection.id);

        final savedCollection = await reopened.mediaCollections
            .filter()
            .pathEqualTo('library/synthetic')
            .findFirst();
        expect(savedCollection!.type, CollectionType.externalFolder);
        expect(savedCollection.defaultSortOrder, SortOrder.updatedAsc);
        expect(savedCollection.defaultViewMode, ViewMode.grid);
        expect(savedCollection.notes, 'line 1\nline 2');
        expect(savedCollection.lastViewedItemId, item.id);
        await savedCollection.items.load();
        await savedCollection.tags.load();
        expect(savedCollection.items.single.uid, 'synthetic-item');
        expect(savedCollection.tags.single.ancestorIds, [101, 202]);
        expect(savedCollection.tags.single.name, '日本語と emoji 📚');
        expect(savedCollection.tags.single.facetId, facet.id);
        expect((await reopened.tagFacets.get(facet.id))!.createdAt.toUtc(), timestamp);

        final savedStorage = await reopened.storageRefs.get(storage.id);
        expect(savedStorage!.ownerType, StorageOwnerType.item);
        expect(savedStorage.sourceType, StorageSourceType.external);
        expect(savedStorage.normalizedLocator, isNull);
        expect(savedStorage.isPrimary, isFalse);
        final savedMigration = await reopened.referenceMigrations.get(
          migration.id,
        );
        expect(savedMigration!.snapshot, '{"source":"synthetic"}');
        expect(savedMigration.committed, isTrue);
        expect(savedMigration.cleanupPending, isFalse);

        // The pre-existing unique/replace index must still replace this row.
        final later = timestamp.add(const Duration(minutes: 1));
        await reopened.writeTxn(() async {
          await reopened.viewingHistorys.put(
            ViewingHistory()
              ..itemUid = 'synthetic-item'
              ..openedAt = later,
          );
        });
        expect(await reopened.viewingHistorys.count(), 1);
        expect(
          (await reopened.viewingHistorys.where().findFirst())!.openedAt.toUtc(),
          later,
        );
      } finally {
        if (database?.isOpen == true) await database!.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
