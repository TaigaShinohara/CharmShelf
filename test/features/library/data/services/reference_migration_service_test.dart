import 'package:private_shelf/features/library/domain/models/legacy_import_labels.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/data/services/reference_migration_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/features/library/domain/models/import_preview_source.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory, original;
  late Isar isar;
  late MediaItem file, folder;
  late MediaCollection collection;
  late Tag tag;
  late ViewingHistory history;
  var sourceReads = 0;
  ReferenceMigrationService service({
    Future<void> Function(String)? checkpoint,
    Future<void> Function(Uri)? release,
  }) => ReferenceMigrationService(
    isar,
    Directory(p.join(directory.path, 'owned')),
    withSource: (locator, name, read) async {
      sourceReads++;
      await read(File(Uri.parse(locator).toFilePath()));
    },
    releaseAccess: release ?? (_) async {},
    checkpoint: checkpoint,
  );

  test('旧スキーマのデータベースに移行記録を追加しても既存行を保持する', () async {
    final oldRoot = await Directory.systemTemp.createTemp('old_schema_test_');
    final oldSchemas = [
      MediaItemSchema,
      MediaCollectionSchema,
      TagSchema,
      TagFacetSchema,
      StorageRefSchema,
      ViewingHistorySchema,
    ];
    var oldDb = await Isar.open(
      oldSchemas,
      directory: oldRoot.path,
      name: 'old-schema',
    );
    try {
      final legacy = MediaItem()
        ..path = 'content://legacy/file'
        ..uid = 'old-schema-item'
        ..sourceType = MediaSourceType.externalReference;
      await oldDb.writeTxn(() async {
        await oldDb.mediaItems.put(legacy);
      });
      await oldDb.close();
      oldDb = await Isar.open(
        [...oldSchemas, ReferenceMigrationSchema],
        directory: oldRoot.path,
        name: 'old-schema',
      );
      final restored = (await oldDb.mediaItems.get(legacy.id))!;
      expect(restored.uid, legacy.uid);
      expect(restored.path, legacy.path);
      expect(restored.sourceType, MediaSourceType.externalReference);
      expect(await oldDb.referenceMigrations.count(), 0);
    } finally {
      await oldDb.close(deleteFromDisk: true);
      await oldRoot.delete(recursive: true);
    }
  });

  setUp(() async {
    sourceReads = 0;
    directory = await Directory.systemTemp.createTemp('retirement_test_');
    original = await Directory(p.join(directory.path, 'original')).create();
    await Directory(p.join(directory.path, 'owned')).create();
    final bytes = File(p.join(original.path, 'test.txt'));
    await bytes.writeAsString('original content');
    isar = await Isar.open(
      [
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
        ViewingHistorySchema,
        ReferenceMigrationSchema,
      ],
      directory: directory.path,
      name: directory.path.hashCode.toString(),
    );
    folder = MediaItem()
      ..uid = 'folder-uid'
      ..path = original.uri.toString()
      ..sourceType = MediaSourceType.externalReference
      ..type = MediaType.folder;
    file = MediaItem()
      ..uid = 'file-uid'
      ..path = bytes.uri.toString()
      ..originalPath = 'test.txt'
      ..parentPath = folder.path
      ..sourceType = MediaSourceType.externalReference
      ..isFavorite = true
      ..isHidden = true;
    collection = MediaCollection()
      ..uid = 'catalog-uid'
      ..path = folder.path
      ..title = 'Original title'
      ..alias = 'Alias'
      ..notes = 'Important note'
      ..type = CollectionType.externalFolder
      ..isCatalog = true;
    tag = Tag()
      ..key = 'test'
      ..name = 'Keep me';
    history = ViewingHistory()..itemUid = file.uid!;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([folder, file]);
      await isar.tags.put(tag);
      await isar.mediaCollections.put(collection);
      collection.items.add(file);
      await collection.items.save();
      collection.tags.add(tag);
      await collection.tags.save();
      await isar.viewingHistorys.put(history);
    });
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  Future<void> verifyMigrated() async {
    final migrated = (await isar.mediaItems.get(file.id))!;
    expect(migrated.uid, file.uid);
    expect(migrated.sourceType, MediaSourceType.localCopy);
    expect(migrated.isFavorite, isTrue);
    expect(migrated.isHidden, isTrue);
    expect(
      await File(p.join(directory.path, 'owned', migrated.path)).readAsString(),
      'original content',
    );
    expect(
      await File(Uri.parse(file.path).toFilePath()).readAsString(),
      'original content',
    );
    final col = (await isar.mediaCollections.get(collection.id))!;
    expect(col.uid, collection.uid);
    expect(col.notes, collection.notes);
    expect(col.alias, collection.alias);
    expect(col.type, CollectionType.folder);
    await col.items.load();
    await col.tags.load();
    expect(col.items.single.id, file.id);
    expect(col.tags.single.id, tag.id);
    expect((await isar.viewingHistorys.get(history.id))!.itemUid, file.uid);
    expect(await isar.mediaItems.count(), 2);
  }

  test(
    'copies verified bytes, keeps IDs, metadata, links and original',
    () async {
      final s = service();
      final groups = await s.inventory();
      expect(groups.single.items.length, 2);
      await s.migrate(groups.single);
      await verifyMigrated();
      expect(await s.inventory(), isEmpty);
    },
  );

  for (final stage in [
    'planned',
    'verified',
    'materialized',
    'beforeCommit',
    'committed',
  ]) {
    test(
      'restart after $stage preserves data and does not duplicate',
      () async {
        final s = service(
          checkpoint: (at) async {
            if (at == stage) throw StateError('crash');
          },
        );
        await expectLater(
          s.migrate((await s.inventory()).single),
          throwsStateError,
        );
        final resumed = service();
        final groups = await resumed.inventory();
        if (groups.isNotEmpty) {
          await resumed.migrate(groups.single);
        } else {
          await resumed.cleanup();
        }
        await verifyMigrated();
        if (stage == 'materialized' ||
            stage == 'beforeCommit' ||
            stage == 'committed') {
          expect(sourceReads, 1);
        }
      },
    );
  }

  test(
    'source unavailable leaves reference and recovery snapshot intact',
    () async {
      final s = service();
      final group = (await s.inventory()).single;
      await File(
        Uri.parse(file.path).toFilePath(),
      ).rename(p.join(original.path, 'moved.txt'));
      await expectLater(s.migrate(group), throwsA(isA<FileSystemException>()));
      expect(
        (await isar.mediaItems.get(file.id))!.sourceType,
        MediaSourceType.externalReference,
      );
      expect(await isar.referenceMigrations.count(), 1);
      await s.reconnect(
        group,
        file,
        File(p.join(original.path, 'moved.txt')).uri,
      );
      await s.migrate(group);
      expect(
        (await isar.mediaItems.get(file.id))!.sourceType,
        MediaSourceType.localCopy,
      );
    },
  );

  test('metadata changes during copy abort publication', () async {
    final s = service(
      checkpoint: (stage) async {
        if (stage == 'beforeCommit') {
          await isar.writeTxn(() async {
            final changed = (await isar.mediaCollections.get(collection.id))!
              ..notes = 'New note';
            await isar.mediaCollections.put(changed);
          });
        }
      },
    );
    await expectLater(
      s.migrate((await s.inventory()).single),
      throwsStateError,
    );
    expect(
      (await isar.mediaItems.get(file.id))!.sourceType,
      MediaSourceType.externalReference,
    );
    expect((await isar.mediaCollections.get(collection.id))!.notes, 'New note');
    final resumed = service();
    await resumed.migrate((await resumed.inventory()).single);
    expect((await isar.mediaCollections.get(collection.id))!.notes, 'New note');
    expect(
      (await isar.mediaItems.get(file.id))!.sourceType,
      MediaSourceType.localCopy,
    );
    expect(await ReferenceMigrationService.reservedPaths(isar), isNotEmpty);
  });

  test('検証直後に中断したコピーは元ファイルがなくても確定して再開できる', () async {
    final interrupted = service(
      checkpoint: (stage) async {
        if (stage == 'verified') throw StateError('simulated exit');
      },
    );
    await expectLater(
      interrupted.migrate((await interrupted.inventory()).single),
      throwsStateError,
    );
    await File(Uri.parse(file.path).toFilePath()).delete();
    final resumed = service();
    await resumed.migrate((await resumed.inventory()).single);
    final migrated = (await isar.mediaItems.get(file.id))!;
    expect(migrated.sourceType, MediaSourceType.localCopy);
    expect(
      await File(p.join(directory.path, 'owned', migrated.path)).readAsString(),
      'original content',
    );
    expect(sourceReads, 1);
  });

  test('cleanup failure does not roll back copied files', () async {
    final s = service(release: (_) async => throw StateError('denied'));
    await expectLater(
      s.migrate((await s.inventory()).single),
      throwsStateError,
    );
    await verifyMigrated();
    expect(
      (await isar.referenceMigrations.where().findFirst())!.cleanupPending,
      isTrue,
    );
    await service().cleanup();
    expect(
      (await isar.referenceMigrations.where().findFirst())!.cleanupPending,
      isFalse,
    );
  });

  test('new references and transient previews cannot be persisted', () async {
    final repo = IsarMediaRepository(isar);
    final preview = ImportPreviewSource(
      uri: Uri.file('/source'),
      name: 'file',
    ).toViewerItem();
    expect(preview.sourceType, MediaSourceType.localCopy);
    expect(preview.requiresSourceAccess, isTrue);
    expect((await repo.save(preview)).isFailure, isTrue);
    expect(
      (await repo.save(
        MediaItem()
          ..path = 'content://new/item'
          ..sourceType = MediaSourceType.externalReference,
      )).isFailure,
      isTrue,
    );
  });
  test('trash stays restorable and never appears as a live file', () async {
    await isar.writeTxn(() async {
      for (final item in [folder, file]) {
        item
          ..isTrashed = true
          ..trashRootPath = folder.path;
      }
      folder.isTrashRoot = true;
      collection
        ..isTrashed = true
        ..trashRootPath = folder.path;
      await isar.mediaItems.putAll([folder, file]);
      await isar.mediaCollections.put(collection);
    });
    final s = service();
    await s.migrate((await s.inventory()).single);
    final migratedRoot = (await isar.mediaItems.get(folder.id))!;
    final migratedFile = (await isar.mediaItems.get(file.id))!;
    expect(migratedFile.isTrashed, isTrue);
    expect(migratedFile.trashRootPath, migratedRoot.path);
    expect(
      await File(
        p.join(
          directory.path,
          'owned',
          migratedRoot.trashPath!,
          p.basename(migratedFile.path),
        ),
      ).readAsString(),
      'original content',
    );
    expect(
      await File(p.join(directory.path, 'owned', migratedFile.path)).exists(),
      isFalse,
    );
    expect(
      await File(Uri.parse(file.path).toFilePath()).readAsString(),
      'original content',
    );
  });

  test('explicit removal keeps original and metadata snapshot', () async {
    final s = service();
    await s.removeReferences((await s.inventory()).single);
    expect(await s.inventory(), isEmpty);
    expect(await isar.mediaItems.count(), 0);
    expect(
      (await isar.referenceMigrations.where().findFirst())!.snapshot,
      contains('Important note'),
    );
    expect(
      await File(Uri.parse(file.path).toFilePath()).readAsString(),
      'original content',
    );
  });

  test(
    'legacy device labels are applied once in the item transaction',
    () async {
      final repo = IsarMediaRepository(
        isar,
        legacyLabels: (_) async => const LegacyImportLabels(
          tags: ['work'],
          catalog: 'Projects',
          favorite: true,
        ),
      );
      final imported = MediaItem()
        ..path = 'library/imported.txt'
        ..originalPath = '/original/file.txt';
      expect((await repo.save(imported)).isSuccess, isTrue);
      final col = (await isar.mediaCollections
          .filter()
          .pathEqualTo(imported.path)
          .findFirst())!;
      await col.tags.load();
      await col.items.load();
      expect(col.alias, 'Projects');
      expect(col.tags.single.name, 'work');
      expect(col.items.single.id, imported.id);
      expect(imported.isFavorite, isTrue);
      imported.isFavorite = false;
      expect((await repo.save(imported)).isSuccess, isTrue);
      expect((await isar.mediaItems.get(imported.id))!.isFavorite, isFalse);
      expect(await isar.tags.filter().nameEqualTo('work').count(), 1);
    },
  );
  test(
    'uncommitted destinations are reserved from reconciliation after restart',
    () async {
      final s = service(
        checkpoint: (stage) async {
          if (stage == 'materialized') throw StateError('crash');
        },
      );
      await expectLater(
        s.migrate((await s.inventory()).single),
        throwsStateError,
      );
      expect(await ReferenceMigrationService.reservedPaths(isar), isNotEmpty);
      final resumed = service();
      await resumed.migrate((await resumed.inventory()).single);
      expect(await ReferenceMigrationService.reservedPaths(isar), isEmpty);
    },
  );

  test('cancellation retains originals and can resume', () async {
    late ReferenceMigrationService s;
    s = service(
      checkpoint: (stage) async {
        if (stage == 'verified') s.cancel();
      },
    );
    await expectLater(
      s.migrate((await s.inventory()).single),
      throwsA(isA<MigrationInterrupted>()),
    );
    expect(
      (await isar.mediaItems.get(file.id))!.sourceType,
      MediaSourceType.externalReference,
    );
    final resumed = service();
    await resumed.migrate((await resumed.inventory()).single);
    await verifyMigrated();
  });
}
