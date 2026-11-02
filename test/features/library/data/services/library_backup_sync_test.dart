import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/services/folder_sync_service.dart';
import 'package:private_shelf/features/library/data/services/library_backup_service.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';

class _Permissions extends Mock implements PermissionRepository {}

class _Storage extends LocalStorageManager {
  _Storage(this.directory);
  final Directory directory;

  @override
  Future<Directory> getRootDirectory({
    bool forceRefresh = false,
    bool allowPublic = true,
  }) async => directory;

  @override
  Future<Directory> getPrivateRootDirectory() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory workspace;
  late Directory sourceRoot;
  late Directory targetRoot;
  late Isar source;
  late Isar target;

  Future<Isar> openDatabase(Directory root, String name) => Isar.open(
    [
      MediaItemSchema,
      MediaCollectionSchema,
      TagSchema,
      TagFacetSchema,
      StorageRefSchema,
      ViewingHistorySchema,
    ],
    directory: root.path,
    name: '$name-${DateTime.now().microsecondsSinceEpoch}',
  );

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('backup_sync_');
    sourceRoot = await Directory(p.join(workspace.path, 'source')).create();
    targetRoot = await Directory(p.join(workspace.path, 'target')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return targetRoot.path;
          }
          return null;
        });
    source = await openDatabase(sourceRoot, 'backup-source');
    target = await openDatabase(targetRoot, 'backup-target');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (source.isOpen) await source.close();
    if (target.isOpen) await target.close();
    await workspace.delete(recursive: true);
  });

  test('復元後の最適化と再同期で階層・検索・閲覧履歴を変えない', () async {
    final sourceRepository = IsarMediaRepository(source);
    final facet = TagFacet()
      ..name = '旅行'
      ..createdAt = DateTime(2026, 10, 2);
    final tag = Tag()
      ..name = 'summer2026'
      ..createdAt = DateTime(2026, 10, 2);
    await source.writeTxn(() async {
      await source.tagFacets.put(facet);
      tag
        ..facetId = facet.id
        ..key = Tag.buildKey(facet.id, tag.name);
      await source.tags.put(tag);
    });
    final definitions = <String, (MediaType, String?)>{
      'library/photo.jpg': (MediaType.file, null),
      'library/trip': (MediaType.folder, null),
      'library/trip/inside.jpg': (MediaType.file, 'library/trip'),
      'library/empty': (MediaType.folder, null),
      'folders/legacy.txt': (MediaType.file, null),
    };
    final items = <String, MediaItem>{};
    for (final entry in definitions.entries) {
      final physical = p.join(sourceRoot.path, entry.key);
      if (entry.value.$1 == MediaType.folder) {
        await Directory(physical).create(recursive: true);
      } else {
        final file = File(physical);
        await file.parent.create(recursive: true);
        await file.writeAsBytes([1, 2, 3, entry.key.length]);
      }
      final item = MediaItem()
        ..uid = 'item-${entry.key}'
        ..path = entry.key
        ..type = entry.value.$1
        ..parentPath = entry.value.$2
        ..addedAt = DateTime(2026, 10, 2)
        ..updatedAt = DateTime(2026, 10, 2);
      expect((await sourceRepository.save(item)).isSuccess, isTrue);
      items[entry.key] = item;
    }
    for (final path in [
      'library/photo.jpg',
      'library/trip',
      'library/empty',
      'folders/legacy.txt',
    ]) {
      final collection = MediaCollection()
        ..uid = 'collection-$path'
        ..path = path
        ..type = items[path]!.type == MediaType.folder
            ? CollectionType.folder
            : CollectionType.file
        ..title = '元の名前 ${p.basename(path)}'
        ..alias = '私の旅行 ${p.basename(path)}'
        ..notes = 'morning lake'
        ..isCatalog = true
        ..isFavorite = true
        ..createdAt = DateTime(2026, 10, 2)
        ..updatedAt = DateTime(2026, 10, 2);
      expect(
        (await sourceRepository.saveCollection(collection)).isSuccess,
        isTrue,
      );
      expect(
        (await sourceRepository.syncTagsOnCollection(collection, [
          tag,
        ])).isSuccess,
        isTrue,
      );
    }
    final openedAt = DateTime(2026, 10, 2, 12);
    final opened = items['library/photo.jpg']!;
    expect(
      (await sourceRepository.updateCollectionLastViewed(
        opened.path,
        itemId: opened.id,
        viewedAt: openedAt,
      )).isSuccess,
      isTrue,
    );
    await source.writeTxn(
      () => source.viewingHistorys.put(
        ViewingHistory()
          ..itemUid = opened.uid!
          ..openedAt = openedAt,
      ),
    );

    final sourceBackup = LibraryBackupService(source, sourceRoot);
    final targetBackup = LibraryBackupService(target, targetRoot);
    final archive = await sourceBackup.createBackup();
    final prepared = await targetBackup.prepareRestore(archive);
    expect(await target.mediaItems.count(), 0);
    await targetBackup.restore(prepared);
    await sourceBackup.disposeExport(archive);

    final restored = await target.mediaItems.where().findAll();
    final parentBefore = {
      for (final item in restored) item.uid: item.parentPath,
    };
    final pathBefore = {for (final item in restored) item.uid: item.path};
    final collectionsBefore = await target.mediaCollections.where().findAll();
    final metadataBefore = {
      for (final collection in collectionsBefore)
        collection.uid: (
          collection.title,
          collection.alias,
          collection.notes,
          collection.lastViewedAt,
          collection.lastViewedItemId,
        ),
    };
    final repository = IsarMediaRepository(target);
    final searchBefore = (await repository.getAll(
      filter: const MediaFilter(searchQuery: 'summer2026'),
    )).dataOrNull!.map((item) => item.uid).toSet();
    expect(searchBefore, contains(opened.uid));
    expect(searchBefore, contains(items['library/trip']!.uid));
    expect(
      (await repository.getRecentMedia()).dataOrNull!.single.uid,
      opened.uid,
    );

    final storage = _Storage(targetRoot);
    final sync = FolderSyncService(
      target,
      storage,
      SidecarMetadataService(target, storage),
      _Permissions(),
    );
    for (var pass = 0; pass < 2; pass++) {
      final result = await sync.syncAll();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.added, 0);
      expect(result.dataOrNull!.missing, 0);
      final after = await target.mediaItems.where().findAll();
      expect({
        for (final item in after) item.uid: item.parentPath,
      }, parentBefore);
      expect({for (final item in after) item.uid: item.path}, pathBefore);
      final collections = await target.mediaCollections.where().findAll();
      expect({
        for (final collection in collections)
          collection.uid: (
            collection.title,
            collection.alias,
            collection.notes,
            collection.lastViewedAt,
            collection.lastViewedItemId,
          ),
      }, metadataBefore);
      expect(
        (await repository.getAll(
          filter: const MediaFilter(searchQuery: 'summer2026'),
        )).dataOrNull!.map((item) => item.uid).toSet(),
        searchBefore,
      );
      expect(
        (await repository.getRecentMedia()).dataOrNull!.single.uid,
        opened.uid,
      );
      final history = await target.viewingHistorys.where().findAll();
      expect(history.single.itemUid, opened.uid);
      expect(history.single.openedAt, openedAt);
    }
  });

  test('部分重複の復元は現在の編集を守り、同期と再復元で旧ファイルを増やさない', () async {
    Future<void> seedFolder(
      Isar database,
      Directory root,
      String path,
      String alias,
      String notes,
      Map<String, (String, String)> files,
    ) async {
      await Directory(p.join(root.path, path)).create(recursive: true);
      final repository = IsarMediaRepository(database);
      expect(
        (await repository.save(
          MediaItem()
            ..uid = 'shared-folder'
            ..path = path
            ..type = MediaType.folder,
        )).isSuccess,
        isTrue,
      );
      final shelf = MediaCollection()
        ..uid = 'shared-shelf'
        ..path = path
        ..title = 'Folder title'
        ..alias = alias
        ..notes = notes
        ..type = CollectionType.folder
        ..isCatalog = true;
      expect((await repository.saveCollection(shelf)).isSuccess, isTrue);
      for (final entry in files.entries) {
        final file = File(p.join(root.path, path, entry.key));
        await file.writeAsString(entry.value.$2);
        expect(
          (await repository.save(
            MediaItem()
              ..uid = entry.value.$1
              ..path = '$path/${entry.key}'
              ..parentPath = path,
          )).isSuccess,
          isTrue,
        );
      }
    }

    await seedFolder(
      source,
      sourceRoot,
      'library/trip',
      'Backup display name',
      'Backup memo',
      {
        'old.txt': ('shared-old-file', 'older archived contents'),
        'new.txt': ('new-child-file', 'new restored contents'),
      },
    );
    await seedFolder(
      target,
      targetRoot,
      'library/current',
      'Current display name',
      'Current memo',
      {'edited-old.txt': ('shared-old-file', 'current edited contents')},
    );
    final sourceShelf = await source.mediaCollections
        .filter()
        .uidEqualTo('shared-shelf')
        .findFirst();
    final facet = TagFacet()
      ..name = '旅行'
      ..createdAt = DateTime(2026, 10, 2);
    final tag = Tag()
      ..name = 'newtrip2026'
      ..createdAt = DateTime(2026, 10, 2);
    await source.writeTxn(() async {
      await source.tagFacets.put(facet);
      tag
        ..facetId = facet.id
        ..key = Tag.buildKey(facet.id, tag.name);
      await source.tags.put(tag);
    });
    expect(
      (await IsarMediaRepository(
        source,
      ).syncTagsOnCollection(sourceShelf!, [tag])).isSuccess,
      isTrue,
    );

    final sourceBackup = LibraryBackupService(source, sourceRoot);
    final targetBackup = LibraryBackupService(target, targetRoot);
    final archive = await sourceBackup.createBackup();
    final prepared = await targetBackup.prepareRestore(archive);
    final result = await targetBackup.restore(prepared);
    expect(result.addedItems, 1);
    final restoredChild = (await target.mediaItems
        .filter()
        .uidEqualTo('new-child-file')
        .findFirst())!;
    final context = (await target.mediaCollections
        .filter()
        .pathEqualTo(restoredChild.parentPath!)
        .findFirst())!;
    expect(context.uid, isNot('shared-shelf'));
    expect(context.alias, 'Backup display name');
    expect(context.notes, 'Backup memo');
    final restoredParent = restoredChild.parentPath;
    final restoredPath = restoredChild.path;
    final initialCount = await target.mediaItems.count();
    final storage = _Storage(targetRoot);
    final sync = FolderSyncService(
      target,
      storage,
      SidecarMetadataService(target, storage),
      _Permissions(),
    );
    final repository = IsarMediaRepository(target);
    for (var pass = 0; pass < 2; pass++) {
      final synchronized = await sync.syncAll();
      expect(synchronized.isSuccess, isTrue);
      expect(synchronized.dataOrNull!.added, 0);
      expect(synchronized.dataOrNull!.missing, 0);
      expect(await target.mediaItems.count(), initialCount);
      final child = (await repository.getByUid('new-child-file')).dataOrNull!;
      expect(child.path, restoredPath);
      expect(child.parentPath, restoredParent);
      final current = (await repository.getCollectionByUid(
        'shared-shelf',
      )).dataOrNull!;
      expect(current.path, 'library/current');
      expect(current.alias, 'Current display name');
      expect(current.notes, 'Current memo');
      await current.items.load();
      expect(current.items.map((item) => item.uid).toSet(), {
        'shared-folder',
        'shared-old-file',
      });
      final old = (await repository.getByUid('shared-old-file')).dataOrNull!;
      expect(old.path, 'library/current/edited-old.txt');
      expect(
        await File(p.join(targetRoot.path, old.path)).readAsString(),
        'current edited contents',
      );
      final physicalTextFiles = [
        await for (final entity in targetRoot.list(recursive: true))
          if (entity is File && p.extension(entity.path) == '.txt') entity,
      ];
      expect(physicalTextFiles, hasLength(2));
      final found = (await repository.getAll(
        filter: const MediaFilter(searchQuery: 'newtrip2026'),
      )).dataOrNull!.map((item) => item.uid).toSet();
      expect(found, contains('new-child-file'));
      expect(found, isNot(contains('shared-old-file')));
      final savedContext = (await repository.getCollectionByUid(
        context.uid!,
      )).dataOrNull!;
      expect(savedContext.path, restoredParent);
      expect(savedContext.alias, 'Backup display name');
      expect(savedContext.notes, 'Backup memo');
    }
    final repeated = await targetBackup.restore(
      await targetBackup.prepareRestore(archive),
    );
    expect(repeated.addedItems, 0);
    expect((await sync.syncAll()).dataOrNull!.added, 0);
    expect(await target.mediaItems.count(), initialCount);
    await sourceBackup.disposeExport(archive);
  });
}
