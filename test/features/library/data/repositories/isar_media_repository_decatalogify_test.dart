import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _CommitFailureIsar extends Fake implements Isar {
  _CommitFailureIsar(this.delegate);
  final Isar delegate;
  bool failBeforeCommit = false;
  int writeCount = 0;
  Future<void> Function()? beforeCommit;

  @override
  IsarCollection<T> collection<T>() => delegate.collection<T>();

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) {
    writeCount++;
    return delegate.writeTxn(() async {
      final result = await callback();
      await beforeCommit?.call();
      if (failBeforeCommit) throw StateError('injected commit failure');
      return result;
    }, silent: silent);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File retainedFile;
  late Isar isar;
  late _CommitFailureIsar database;
  late IsarMediaRepository repository;
  late MediaCollection collection;
  late MediaItem item;
  late Tag sharedTag;
  late Tag zeroCountTag;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('decatalogify_repo_');
    retainedFile = File('${directory.path}/library/trip/photo.jpg');
    await retainedFile.parent.create(recursive: true);
    await retainedFile.writeAsString('retained file contents');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: directory.path,
      name: 'decatalogify_${DateTime.now().microsecondsSinceEpoch}',
    );
    database = _CommitFailureIsar(isar);
    repository = IsarMediaRepository(database);
    item = MediaItem()
      ..uid = 'retained-file'
      ..path = 'library/trip/photo.jpg'
      ..parentPath = 'library/trip';
    collection = MediaCollection()
      ..uid = 'trip'
      ..path = 'library/trip'
      ..title = 'trip'
      ..alias = 'Family trip'
      ..notes = 'A note to keep'
      ..isFavorite = true
      ..isCatalog = true
      ..isPinned = true
      ..tier = MediaTier.a.value
      ..coverImagePath = 'library/trip/photo.jpg'
      ..lastViewedAt = DateTime(2026)
      ..lastViewedItemId = null
      ..isHidden = true
      ..isArchived = true
      ..updatedAt = DateTime(2020);
    sharedTag = Tag()
      ..key = 'shared-trip'
      ..name = 'trip'
      ..usageCount = 2;
    zeroCountTag = Tag()
      ..key = 'zero-count'
      ..name = 'old tag'
      ..usageCount = 0;
    await isar.writeTxn(() async {
      await isar.mediaItems.put(item);
      collection.lastViewedItemId = item.id;
      await isar.mediaCollections.put(collection);
      collection.items.add(item);
      await collection.items.save();
      await isar.storageRefs.put(
        StorageRef()
          ..uid = 'retained-storage-ref'
          ..ownerUid = collection.uid!
          ..ownerType = StorageOwnerType.collection
          ..sourceType = StorageSourceType.local
          ..locator = collection.path
          ..normalizedLocator = collection.path
          ..createdAt = DateTime(2020)
          ..updatedAt = DateTime(2020),
      );
      await isar.tags.putAll([sharedTag, zeroCountTag]);
      final other = MediaCollection()
        ..uid = 'another-trip'
        ..path = 'library/another-trip'
        ..isCatalog = true;
      await isar.mediaCollections.put(other);
      other.tags.add(sharedTag);
      await other.tags.save();
    });
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> addTags() => isar.writeTxn(() async {
    collection.tags.addAll([sharedTag, zeroCountTag]);
    await collection.tags.save();
  });

  Future<MediaCollection> reload() async {
    final saved = (await isar.mediaCollections.get(collection.id))!;
    await saved.tags.load();
    await saved.items.load();
    return saved;
  }

  Future<void> expectRetainedContent(MediaCollection saved) async {
    expect(saved.uid, collection.uid);
    expect(saved.path, collection.path);
    expect(saved.title, collection.title);
    expect(saved.alias, 'Family trip');
    expect(saved.notes, 'A note to keep');
    expect(saved.isFavorite, isTrue);
    expect(saved.isHidden, isTrue);
    expect(saved.isArchived, isTrue);
    expect(saved.lastViewedAt, DateTime(2026));
    expect(saved.lastViewedItemId, item.id);
    expect(saved.items.map((item) => item.id), [item.id]);
    expect((await isar.mediaItems.get(item.id))?.uid, item.uid);
    final reference = (await isar.storageRefs
        .filter()
        .uidEqualTo('retained-storage-ref')
        .findFirst())!;
    expect(reference.ownerUid, collection.uid);
    expect(reference.locator, collection.path);
    expect(reference.updatedAt, DateTime(2020));
    expect(await retainedFile.readAsString(), 'retained file contents');
  }

  test(
    'tag removal, usage counts and registration change commit together',
    () async {
      await addTags();
      final result = await repository.decatalogifyCollection(collection.id);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isCatalog, isFalse);
      expect(result.dataOrNull?.tags, isEmpty);
      expect(database.writeCount, 1);
      final saved = await reload();
      expect(saved.isCatalog, isFalse);
      expect(saved.isPinned, isFalse);
      expect(saved.tier, MediaTier.none.value);
      expect(saved.coverImagePath, isNull);
      expect(saved.updatedAt.isAfter(DateTime(2020)), isTrue);
      expect(saved.tags, isEmpty);
      expect((await isar.tags.get(sharedTag.id))?.usageCount, 1);
      expect((await isar.tags.get(zeroCountTag.id))?.usageCount, 0);
      final other = (await isar.mediaCollections
          .filter()
          .uidEqualTo('another-trip')
          .findFirst())!;
      await other.tags.load();
      expect(other.tags.map((tag) => tag.id), [sharedTag.id]);
      await expectRetainedContent(saved);

      // Repeating a completed operation never decrements shared usage again.
      expect(
        (await repository.decatalogifyCollection(collection.id)).isSuccess,
        isTrue,
      );
      expect((await isar.tags.get(sharedTag.id))?.usageCount, 1);
    },
  );

  test('registration without tags still saves all intended flags', () async {
    expect(
      (await repository.decatalogifyCollection(collection.id)).isSuccess,
      isTrue,
    );
    final saved = await reload();
    expect(saved.isCatalog, isFalse);
    expect(saved.isPinned, isFalse);
    expect(saved.tier, MediaTier.none.value);
    expect(saved.coverImagePath, isNull);
    expect(saved.tags, isEmpty);
    await expectRetainedContent(saved);
  });

  for (final tagged in [true, false]) {
    test(
      'a commit failure ${tagged ? 'after clearing tags' : 'without tags'} restores every prior value and permits retry',
      () async {
        if (tagged) await addTags();
        database.failBeforeCommit = true;
        var sawUncommittedChange = false;
        database.beforeCommit = () async {
          final staged = await reload();
          sawUncommittedChange = !staged.isCatalog && staged.tags.isEmpty;
        };
        final result = await repository.decatalogifyCollection(collection.id);
        expect(result.isFailure, isTrue);
        expect(sawUncommittedChange, isTrue);
        expect(database.writeCount, 1);
        final unchanged = await reload();
        expect(unchanged.isCatalog, isTrue);
        expect(unchanged.isPinned, isTrue);
        expect(unchanged.tier, MediaTier.a.value);
        expect(unchanged.coverImagePath, 'library/trip/photo.jpg');
        expect(unchanged.updatedAt, DateTime(2020));
        expect(
          unchanged.tags.map((tag) => tag.id).toSet(),
          tagged ? {sharedTag.id, zeroCountTag.id} : isEmpty,
        );
        expect((await isar.tags.get(sharedTag.id))?.usageCount, 2);
        expect((await isar.tags.get(zeroCountTag.id))?.usageCount, 0);
        await expectRetainedContent(unchanged);

        database.failBeforeCommit = false;
        database.beforeCommit = null;
        expect(
          (await repository.decatalogifyCollection(collection.id)).isSuccess,
          isTrue,
        );
        final saved = await reload();
        expect(saved.isCatalog, isFalse);
        expect(saved.tags, isEmpty);
        expect((await isar.tags.get(sharedTag.id))?.usageCount, tagged ? 1 : 2);
        await expectRetainedContent(saved);
      },
    );
  }

  test(
    'a removed collection is not recreated by registration removal',
    () async {
      final result = await repository.decatalogifyCollection(
        collection.id + 100,
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
      expect(await isar.mediaCollections.count(), 2);
    },
  );
}
