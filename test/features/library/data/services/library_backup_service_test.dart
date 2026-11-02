import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/features/library/data/services/library_backup_archive.dart';
import 'package:private_shelf/features/library/data/services/library_backup_service.dart';
import 'package:private_shelf/features/library/data/services/library_backup_destination.dart';
import 'package:private_shelf/features/library/data/services/library_backup_workspace.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/library_backup.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory workspace;
  late Directory sourceRoot;
  late Directory targetRoot;
  late Isar source;
  late Isar target;
  late LibraryBackupService exporter;
  late LibraryBackupService importer;
  final date = DateTime.utc(2026, 10, 2, 11);

  Future<Isar> open(Directory root) => Isar.open(
    [
      MediaItemSchema,
      MediaCollectionSchema,
      TagSchema,
      TagFacetSchema,
      StorageRefSchema,
      ViewingHistorySchema,
    ],
    directory: root.path,
    name: 'backup-${DateTime.now().microsecondsSinceEpoch}',
  );

  Future<void> content(Directory root, String path, String text) async {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<void> seed() async {
    await content(sourceRoot, 'library/photo.txt', 'my private photo');
    await content(sourceRoot, '.thumbnails/photo.png', 'thumbnail');
    await content(sourceRoot, 'covers/custom.png', 'custom cover');
    await content(sourceRoot, '.trash/op/deleted.txt', 'recoverable trash');
    await Directory(p.join(sourceRoot.path, 'library/empty')).create();
    final facet = TagFacet()
      ..name = 'Travel'
      ..colorValue = 0xffaabbcc
      ..sortOrder = 7
      ..createdAt = date;
    await source.writeTxn(() async {
      await source.tagFacets.put(facet);
      final parent = Tag()
        ..name = 'Family'
        ..facetId = facet.id
        ..key = Tag.buildKey(facet.id, 'Family')
        ..colorValue = 0xff123456
        ..createdAt = date;
      await source.tags.put(parent);
      final child = Tag()
        ..name = 'summer2026'
        ..facetId = facet.id
        ..key = Tag.buildKey(facet.id, 'summer2026')
        ..parentId = parent.id
        ..ancestorIds = [parent.id]
        ..level = 101
        ..isHidden = true
        ..createdAt = date;
      await source.tags.put(child);
      final item = MediaItem()
        ..uid = 'photo-uid'
        ..path = 'library/photo.txt'
        ..isFavorite = true
        ..isHidden = true
        ..isArchived = true
        ..thumbnailPath = '.thumbnails/photo.png'
        ..addedAt = date
        ..updatedAt = date;
      await source.mediaItems.put(item);
      final empty = MediaItem()
        ..uid = 'empty-uid'
        ..path = 'library/empty'
        ..type = MediaType.folder
        ..addedAt = date
        ..updatedAt = date;
      await source.mediaItems.put(empty);
      final trash = MediaItem()
        ..uid = 'trash-uid'
        ..path = 'library/deleted.txt'
        ..isTrashed = true
        ..isTrashRoot = true
        ..trashRootPath = 'library/deleted.txt'
        ..trashPath = '.trash/op/deleted.txt'
        ..trashedAt = date
        ..addedAt = date
        ..updatedAt = date;
      await source.mediaItems.put(trash);
      final shelf = MediaCollection()
        ..uid = 'shelf-uid'
        ..path = item.path
        ..title = 'photo.txt'
        ..alias = 'Morning lake'
        ..type = CollectionType.file
        ..isCatalog = true
        ..notes = 'morning lake with family'
        ..isFavorite = true
        ..isPinned = true
        ..isHidden = true
        ..isArchived = true
        ..tier = 5
        ..coverImagePath = 'covers/custom.png'
        ..lastViewedAt = date
        ..lastViewedItemId = item.id
        ..createdAt = date
        ..updatedAt = date;
      await source.mediaCollections.put(shelf);
      shelf.items.add(item);
      shelf.tags.add(child);
      await shelf.items.save();
      await shelf.tags.save();
      await source.viewingHistorys.put(
        ViewingHistory()
          ..itemUid = item.uid!
          ..openedAt = date,
      );
    });
  }

  Future<void> seedExisting() async {
    await content(targetRoot, 'library/keep.txt', 'keep forever');
    await target.writeTxn(() async {
      final item = MediaItem()
        ..uid = 'existing-uid'
        ..path = 'library/keep.txt'
        ..addedAt = date
        ..updatedAt = date;
      await target.mediaItems.put(item);
      await target.mediaCollections.put(
        MediaCollection()
          ..uid = 'existing-shelf'
          ..path = item.path
          ..title = 'My existing file'
          ..notes = 'do not replace',
      );
    });
  }

  Future<List<String>> libraryFiles() async => [
    await for (final entity in targetRoot.list(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File &&
          !p
              .relative(entity.path, from: targetRoot.path)
              .startsWith('.backup-work') &&
          !p.basename(entity.path).contains('.isar'))
        p.relative(entity.path, from: targetRoot.path),
  ]..sort();

  Future<void> expectExistingUnchanged() async {
    expect(
      await File(p.join(targetRoot.path, 'library/keep.txt')).readAsString(),
      'keep forever',
    );
    expect(
      (await target.mediaCollections
              .filter()
              .uidEqualTo('existing-shelf')
              .findFirst())!
          .notes,
      'do not replace',
    );
    expect(await target.mediaItems.count(), 1);
    expect(await target.mediaCollections.count(), 1);
    expect(await target.tags.count(), 0);
    expect(await libraryFiles(), ['library/keep.txt']);
  }

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('portable_backup_');
    sourceRoot = await Directory(p.join(workspace.path, 'source')).create();
    targetRoot = await Directory(p.join(workspace.path, 'target')).create();
    source = await open(sourceRoot);
    target = await open(targetRoot);
    exporter = LibraryBackupService(source, sourceRoot);
    importer = LibraryBackupService(target, targetRoot);
    await seed();
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await workspace.delete(recursive: true);
  });

  test(
    'cleanup failure cannot turn committed restoration into failure',
    () async {
      final archive = await exporter.createBackup();
      for (var attempt = 0; attempt < 2; attempt++) {
        final original = await importer.prepareRestore(archive);
        final prepared = PreparedLibraryBackup(
          directory: original.directory,
          document: original.document,
          createdAt: original.createdAt,
          fileCount: original.fileCount,
          totalBytes: original.totalBytes,
          disposeStaging: () async =>
              throw const FileSystemException('cleanup unavailable'),
        );
        final result = await importer.restore(prepared);
        expect(result.cleanupIncomplete, isTrue);
        expect(result.addedItems, attempt == 0 ? 3 : 0);
        expect(result.skippedItems, attempt == 0 ? 0 : 3);
        final photo = (await target.mediaItems
            .filter()
            .uidEqualTo('photo-uid')
            .findFirst())!;
        expect(
          await target.mediaItems.filter().uidEqualTo('photo-uid').count(),
          1,
        );
        expect(
          await File(p.join(targetRoot.path, photo.path)).readAsString(),
          'my private photo',
        );
        await original.dispose();
      }
    },
  );

  test(
    'roundtrip preserves content, organization, hierarchy, trash and history; repeat is idempotent',
    () async {
      final archive = await exporter.createBackup();
      final prepared = await importer.prepareRestore(archive);
      expect(await target.mediaItems.count(), 0); // preview is read-only
      expect(prepared.itemCount, 3);
      expect(prepared.fileCount, 2); // cache and cover files are not user media
      final result = await importer.restore(
        prepared,
        folderName: '復元 2026年10月2日',
      );
      expect(result.addedItems, 3);
      final photo = (await target.mediaItems
          .filter()
          .uidEqualTo('photo-uid')
          .findFirst())!;
      expect(
        await File(p.join(targetRoot.path, photo.path)).readAsString(),
        'my private photo',
      );
      expect(photo.isFavorite && photo.isHidden && photo.isArchived, isTrue);
      expect(
        await File(
          p.join(targetRoot.path, photo.thumbnailPath!),
        ).readAsString(),
        'thumbnail',
      );
      expect(photo.parentPath, isNotNull);
      await photo.collection.load();
      final shelf = photo.collection.value!;
      expect(shelf.alias, 'Morning lake');
      expect(shelf.notes, 'morning lake with family');
      expect(
        shelf.isPinned &&
            shelf.isFavorite &&
            shelf.isHidden &&
            shelf.isArchived,
        isTrue,
      );
      expect(shelf.lastViewedItemId, photo.id);
      expect(
        shelf.lastViewedAt!.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      expect(shelf.tier, 5);
      expect(
        await File(
          p.join(targetRoot.path, shelf.coverImagePath!),
        ).readAsString(),
        'custom cover',
      );
      await shelf.tags.load();
      final child = shelf.tags.single;
      final parent = await target.tags.get(child.parentId!);
      expect(parent!.name, 'Family');
      expect(child.name, 'summer2026');
      expect(child.ancestorIds, [parent.id]);
      expect(child.usageCount, 1);
      expect(child.isHidden, isTrue);
      final facet = await target.tagFacets.get(child.facetId!);
      expect(facet!.name, 'Travel');
      expect(facet.sortOrder, 7);
      expect(facet.colorValue, 0xffaabbcc);
      final empty = (await target.mediaItems
          .filter()
          .uidEqualTo('empty-uid')
          .findFirst())!;
      expect(
        await Directory(p.join(targetRoot.path, empty.path)).exists(),
        isTrue,
      );
      final trash = (await target.mediaItems
          .filter()
          .uidEqualTo('trash-uid')
          .findFirst())!;
      expect(trash.isTrashed && trash.isTrashRoot, isTrue);
      expect(
        await File(p.join(targetRoot.path, trash.trashPath!)).readAsString(),
        'recoverable trash',
      );
      expect(
        (await target.viewingHistorys.where().findFirst())!.itemUid,
        photo.uid,
      );
      final beforeFiles = await libraryFiles();
      final beforeCount = await target.mediaItems.count();
      // The current user edit must win over an older backup.
      shelf.notes = 'my newer edit';
      await target.writeTxn(() async {
        await target.mediaCollections.put(shelf);
      });
      final again = await importer.restore(
        await importer.prepareRestore(archive),
      );
      expect(again.addedItems, 0);
      expect(again.skippedItems, 3);
      expect(await target.mediaItems.count(), beforeCount);
      expect(await libraryFiles(), beforeFiles);
      expect(
        (await target.mediaCollections.get(shelf.id))!.notes,
        'my newer edit',
      );
      await exporter.disposeExport(archive);
    },
  );

  test(
    'canceling preview and operation leaves existing data unchanged',
    () async {
      await seedExisting();
      final archive = await exporter.createBackup();
      final prepared = await importer.prepareRestore(archive);
      await expectExistingUnchanged();
      await prepared.dispose();
      final cancellation = LibraryBackupCancellation()..isCancelled = true;
      await expectLater(
        importer.prepareRestore(archive, cancellation: cancellation),
        throwsA(isA<LibraryBackupCancelled>()),
      );
      await expectExistingUnchanged();
    },
  );

  test(
    'transaction failure removes only staged files; retry succeeds',
    () async {
      await seedExisting();
      final archive = await exporter.createBackup();
      final failing = LibraryBackupService(
        target,
        targetRoot,
        beforeRestoreCommit: () async {
          throw StateError('injected database failure');
        },
      );
      await expectLater(
        failing.restore(await failing.prepareRestore(archive)),
        throwsStateError,
      );
      await expectExistingUnchanged();
      expect(
        (await importer.restore(
          await importer.prepareRestore(archive),
        )).addedItems,
        3,
      );
      expect(
        await File(p.join(targetRoot.path, 'library/keep.txt')).readAsString(),
        'keep forever',
      );
    },
  );

  test(
    'tampered/truncated bytes and changed prepared files do not mutate library',
    () async {
      await seedExisting();
      final archive = await exporter.createBackup();
      final bytes = await archive.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      final damaged = File(p.join(workspace.path, 'damaged.tagshelf'));
      await damaged.writeAsBytes(bytes);
      await expectLater(
        importer.prepareRestore(damaged),
        throwsFormatException,
      );
      await damaged.writeAsBytes(bytes.sublist(0, bytes.length - 3));
      await expectLater(
        importer.prepareRestore(damaged),
        throwsFormatException,
      );
      final prepared = await importer.prepareRestore(archive);
      await File(
        p.join(prepared.directory.path, 'library/photo.txt'),
      ).writeAsString('changed');
      await expectLater(importer.restore(prepared), throwsFormatException);
      await prepared.dispose();
      await expectExistingUnchanged();
    },
  );

  test(
    'path traversal and malicious hierarchy are rejected before file publication',
    () async {
      await seedExisting();
      final archive = await exporter.createBackup();
      final original = await LibraryBackupArchive.verify(archive);
      final document = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      (document['files'] as List).first['path'] = 'library/../../outside.txt';
      final malformed = File(p.join(workspace.path, 'malformed.tagshelf'));
      final manifest = utf8.encode(jsonEncode(document));
      final length = ByteData(4)..setUint32(0, manifest.length);
      await malformed.writeAsBytes([
        ...utf8.encode('TSHELF1\n'),
        ...length.buffer.asUint8List(),
        ...sha256.convert(manifest).bytes,
        ...manifest,
      ]);
      await expectLater(
        importer.prepareRestore(malformed),
        throwsFormatException,
      );
      final cycle = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      final empty = (cycle['items'] as List).firstWhere(
        (item) => item['type'] == 'folder',
      );
      empty['parentPath'] = empty['path'];
      expect(
        () => LibraryBackupArchive.validateDocument(cycle),
        throwsFormatException,
      );
      final duplicate =
          jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      final tags = duplicate['tags'] as List;
      tags[1]['name'] = tags[0]['name'];
      expect(
        () => LibraryBackupArchive.validateDocument(duplicate),
        throwsFormatException,
      );
      await expectExistingUnchanged();
      expect(
        await File(p.join(workspace.path, 'outside.txt')).exists(),
        isFalse,
      );
    },
  );

  test(
    'legacy external references cannot produce a silently incomplete backup',
    () async {
      await source.writeTxn(() async {
        await source.mediaItems.put(
          MediaItem()
            ..uid = 'external'
            ..path = 'content://private/photo.jpg'
            ..sourceType = MediaSourceType.externalReference,
        );
      });
      await expectLater(exporter.createBackup(), throwsFormatException);
    },
  );

  test('committed empty shelf survives crash journal recovery', () async {
    await source.writeTxn(() async {
      await source.mediaItems.clear();
      await source.mediaCollections.clear();
      await source.viewingHistorys.clear();
      await source.mediaCollections.put(
        MediaCollection()
          ..uid = 'empty-shelf'
          ..path = 'library/empty'
          ..title = 'Empty shelf'
          ..type = CollectionType.folder
          ..coverImagePath = 'covers/custom.png',
      );
    });
    final archive = await exporter.createBackup();
    await importer.restore(await importer.prepareRestore(archive));
    final shelf = (await target.mediaCollections
        .filter()
        .uidEqualTo('empty-shelf')
        .findFirst())!;
    final namespace = shelf.path.split('/')[1];
    final journal = File(
      p.join(targetRoot.path, '.backup-work', '$namespace.json'),
    );
    await journal.writeAsString(jsonEncode({'namespace': namespace}));
    final newArchive = await importer
        .createBackup(); // recovery must preserve committed content
    expect(
      await Directory(p.join(targetRoot.path, shelf.path)).exists(),
      isTrue,
    );
    expect(
      await File(p.join(targetRoot.path, shelf.coverImagePath!)).readAsString(),
      'custom cover',
    );
    expect(await journal.exists(), isFalse);
    await importer.disposeExport(newArchive);
  });

  test('empty trash folder remains recoverable after restore', () async {
    await Directory(
      p.join(sourceRoot.path, '.trash/empty-op/data'),
    ).create(recursive: true);
    await source.writeTxn(() async {
      await source.mediaItems.put(
        MediaItem()
          ..uid = 'empty-trash-folder'
          ..path = 'library/deleted-empty'
          ..type = MediaType.folder
          ..isTrashed = true
          ..isTrashRoot = true
          ..trashRootPath = 'library/deleted-empty'
          ..trashPath = '.trash/empty-op/data'
          ..trashedAt = date
          ..addedAt = date
          ..updatedAt = date,
      );
    });
    final archive = await exporter.createBackup();
    await importer.restore(await importer.prepareRestore(archive));
    final folder = (await target.mediaItems
        .filter()
        .uidEqualTo('empty-trash-folder')
        .findFirst())!;
    final physicalTrash = Directory(p.join(targetRoot.path, folder.trashPath!));
    expect(await physicalTrash.exists(), isTrue);
    final destination = Directory(p.join(targetRoot.path, folder.path));
    await destination.parent.create(recursive: true);
    await physicalTrash.rename(
      destination.path,
    ); // same primitive used by Undo Trash
    expect(await destination.exists(), isTrue);
  });

  test(
    'new shelf cover on an existing file survives post-commit journal recovery',
    () async {
      await content(targetRoot, 'library/current.txt', 'current file');
      await target.writeTxn(() async {
        await target.mediaItems.put(
          MediaItem()
            ..uid = 'photo-uid'
            ..path = 'library/current.txt'
            ..addedAt = date
            ..updatedAt = date,
        );
      });
      final archive = await exporter.createBackup();
      await importer.restore(await importer.prepareRestore(archive));
      final shelf = (await target.mediaCollections
          .filter()
          .uidEqualTo('shelf-uid')
          .findFirst())!;
      expect(shelf.path, 'library/current.txt');
      final namespace = shelf.coverImagePath!.split('/')[1];
      final journal = File(
        p.join(targetRoot.path, '.backup-work', '$namespace.json'),
      );
      await journal.writeAsString(jsonEncode({'namespace': namespace}));
      final again = await importer.createBackup();
      expect(
        await File(
          p.join(targetRoot.path, shelf.coverImagePath!),
        ).readAsString(),
        'custom cover',
      );
      expect(
        await File(p.join(targetRoot.path, shelf.path)).readAsString(),
        'current file',
      );
      expect(await journal.exists(), isFalse);
      await importer.disposeExport(again);
    },
  );

  test('new tags inherit the preserved local parent hierarchy', () async {
    final initial = await exporter.createBackup();
    await importer.restore(await importer.prepareRestore(initial));
    final family = (await target.tags
        .filter()
        .nameEqualTo('Family')
        .findFirst())!;
    final personal = Tag()
      ..name = 'Personal'
      ..facetId = family.facetId
      ..key = Tag.buildKey(family.facetId!, 'Personal')
      ..createdAt = date;
    await target.writeTxn(() async {
      await target.tags.put(personal);
      family
        ..parentId = personal.id
        ..ancestorIds = [personal.id]
        ..level = 101;
      await target.tags.put(family);
    });
    final sourceFamily = (await source.tags
        .filter()
        .nameEqualTo('Family')
        .findFirst())!;
    await content(sourceRoot, 'library/autumn.txt', 'new trip');
    await source.writeTxn(() async {
      final autumn = Tag()
        ..name = 'Autumn'
        ..facetId = sourceFamily.facetId
        ..key = Tag.buildKey(sourceFamily.facetId!, 'Autumn')
        ..parentId = sourceFamily.id
        ..ancestorIds = [sourceFamily.id]
        ..level = 101
        ..createdAt = date;
      await source.tags.put(autumn);
      final file = MediaItem()
        ..uid = 'autumn-file'
        ..path = 'library/autumn.txt'
        ..addedAt = date
        ..updatedAt = date;
      await source.mediaItems.put(file);
      final shelf = MediaCollection()
        ..uid = 'autumn-shelf'
        ..path = file.path
        ..title = 'Autumn'
        ..type = CollectionType.file;
      await source.mediaCollections.put(shelf);
      shelf.items.add(file);
      shelf.tags.add(autumn);
      await shelf.items.save();
      await shelf.tags.save();
    });
    final newer = await exporter.createBackup();
    await importer.restore(await importer.prepareRestore(newer));
    final autumn = (await target.tags
        .filter()
        .nameEqualTo('Autumn')
        .findFirst())!;
    expect(autumn.parentId, family.id);
    expect(autumn.ancestorIds, [personal.id, family.id]);
    expect(autumn.level, 102);
    expect((await target.tags.get(family.id))!.parentId, personal.id);
  });

  test(
    'backup publication preserves existing files and removes failed owned partials',
    () async {
      final destination = await Directory(
        p.join(workspace.path, 'chosen-folder'),
      ).create();
      final archive = await exporter.createBackup();
      await content(destination, 'existing.tagshelf', 'do not overwrite');
      await expectLater(
        LibraryBackupDestination.save(
          archive: archive,
          folder: Uri.directory(destination.path),
          fileName: 'existing.tagshelf',
          isAndroid: false,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(
          p.join(destination.path, 'existing.tagshelf'),
        ).readAsString(),
        'do not overwrite',
      );
      await LibraryBackupDestination.save(
        archive: archive,
        folder: Uri.directory(destination.path),
        fileName: 'completed.tagshelf',
        isAndroid: false,
      );
      expect(
        await LibraryBackupArchive.verify(
          File(p.join(destination.path, 'completed.tagshelf')),
        ),
        isA<Map<String, dynamic>>(),
      );
      await expectLater(
        LibraryBackupDestination.save(
          archive: File(p.join(workspace.path, 'missing-source')),
          folder: Uri.directory(destination.path),
          fileName: 'failed.tagshelf',
          isAndroid: false,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(p.join(destination.path, 'failed.tagshelf')).exists(),
        isFalse,
      );
      expect(
        await destination
            .list()
            .where((entity) => entity.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'recursive cleanup rejects user folders and symbolic link destinations',
    () async {
      final user = await Directory(
        p.join(targetRoot.path, 'library/my-folder'),
      ).create(recursive: true);
      await content(targetRoot, 'library/my-folder/file.txt', 'keep');
      await expectLater(
        LibraryBackupWorkspace.removeStaging(targetRoot, user),
        throwsA(isA<FileSystemException>()),
      );
      final work = await Directory(
        p.join(targetRoot.path, '.backup-work'),
      ).create();
      final link = Link(p.join(work.path, 'work-malicious'));
      await link.create(user.path);
      await expectLater(
        LibraryBackupWorkspace.removeStaging(targetRoot, Directory(link.path)),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(p.join(user.path, 'file.txt')).readAsString(), 'keep');
    },
  );
}
