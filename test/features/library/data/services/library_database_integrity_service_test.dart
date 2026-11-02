import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';
import 'package:private_shelf/features/library/data/services/library_database_integrity_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/library_integrity_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _MigrationPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar isar;
  late LibraryDatabaseIntegrityService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('library_integrity_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'integrity_${DateTime.now().microsecondsSinceEpoch}',
    );
    service = LibraryDatabaseIntegrityService(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('正常なDBを読み取り専用で検査できる', () async {
    final facet = TagFacet()
      ..name = '種類'
      ..createdAt = DateTime(2026);
    final tag = Tag()
      ..key = '種類::画像'
      ..name = '画像'
      ..level = 100
      ..usageCount = 1
      ..createdAt = DateTime(2026);
    final item = MediaItem()
      ..uid = 'item-1'
      ..path = 'library/image.jpg';
    final collection = MediaCollection()
      ..uid = 'collection-1'
      ..path = 'library/image.jpg'
      ..title = 'image';

    await isar.writeTxn(() async {
      await isar.tagFacets.put(facet);
      tag.facetId = facet.id;
      await isar.tags.put(tag);
      await isar.mediaItems.put(item);
      collection.lastViewedItemId = item.id;
      await isar.mediaCollections.put(collection);
      collection.items.add(item);
      collection.tags.add(tag);
      await collection.items.save();
      await collection.tags.save();
    });

    final result = await service.audit();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.isHealthy, isTrue);
    expect((await isar.tags.get(tag.id))!.usageCount, 1);
    expect(
      (await isar.mediaCollections.get(collection.id))!.uid,
      'collection-1',
    );
  });

  test('安全に判断できる不整合だけを修復する', () async {
    final facet = TagFacet()
      ..name = '種類'
      ..createdAt = DateTime(2026);
    final tag = Tag()
      ..key = '種類::画像'
      ..name = '画像'
      ..level = 7
      ..ancestorIds = [999]
      ..usageCount = 8
      ..createdAt = DateTime(2026);
    final item = MediaItem()..path = 'library/image.jpg';
    final collection = MediaCollection()
      ..path = 'library/image.jpg'
      ..title = 'image'
      ..lastViewedItemId = 999;

    await isar.writeTxn(() async {
      await isar.tagFacets.put(facet);
      tag.facetId = facet.id;
      await isar.tags.put(tag);
      await isar.mediaItems.put(item);
      await isar.mediaCollections.put(collection);
      collection.items.add(item);
      collection.tags.add(tag);
      await collection.items.save();
      await collection.tags.save();

      await isar.storageRefs.put(
        StorageRef()
          ..uid = 'orphan-ref'
          ..ownerUid = 'missing-owner'
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.local
          ..locator = 'missing'
          ..createdAt = DateTime(2026)
          ..updatedAt = DateTime(2026),
      );
      await isar.storageRefs.putAll([
        StorageRef()
          ..uid = 'older-ref'
          ..ownerUid = 'owner-1'
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.local
          ..locator = 'old'
          ..createdAt = DateTime(2026)
          ..updatedAt = DateTime(2026, 1, 1),
        StorageRef()
          ..uid = 'newer-ref'
          ..ownerUid = 'owner-1'
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.local
          ..locator = 'new'
          ..createdAt = DateTime(2026)
          ..updatedAt = DateTime(2026, 1, 2),
      ]);
      item.uid = 'owner-1';
      await isar.mediaItems.put(item);
    });

    final result = await service.repairSafeIssues();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.changedRecordCount, greaterThan(0));
    final repairedTag = (await isar.tags.get(tag.id))!;
    expect(repairedTag.level, 7);
    expect(repairedTag.ancestorIds, isEmpty);
    expect(repairedTag.usageCount, 1);
    final repairedCollection = (await isar.mediaCollections.get(
      collection.id,
    ))!;
    expect(repairedCollection.uid, isNotEmpty);
    expect(repairedCollection.lastViewedItemId, isNull);
    expect(
      await isar.storageRefs.filter().uidEqualTo('orphan-ref').findFirst(),
      isNull,
    );
    expect(
      (await isar.storageRefs.filter().uidEqualTo('older-ref').findFirst())!
          .isPrimary,
      isFalse,
    );
    expect(result.dataOrNull!.after.isHealthy, isTrue);
  });

  test('判断が必要な不整合は検出するが変更しない', () async {
    final facet = TagFacet()
      ..name = '種類'
      ..createdAt = DateTime(2026);
    final first = Tag()
      ..key = '種類::A'
      ..name = 'A'
      ..level = 101
      ..createdAt = DateTime(2026);
    final second = Tag()
      ..key = '種類::B'
      ..name = 'B'
      ..level = 101
      ..createdAt = DateTime(2026);
    final item = MediaItem()
      ..uid = 'shared-item'
      ..path = 'library/shared.jpg';
    final firstCollection = MediaCollection()
      ..uid = 'collection-a'
      ..path = 'library/a'
      ..title = 'A';
    final secondCollection = MediaCollection()
      ..uid = 'collection-b'
      ..path = 'library/b'
      ..title = 'B';

    await isar.writeTxn(() async {
      await isar.tagFacets.put(facet);
      first.facetId = facet.id;
      second.facetId = facet.id;
      await isar.tags.putAll([first, second]);
      first.parentId = second.id;
      second.parentId = first.id;
      await isar.tags.putAll([first, second]);
      await isar.mediaItems.put(item);
      await isar.mediaCollections.putAll([firstCollection, secondCollection]);
      firstCollection.items.add(item);
      secondCollection.items.add(item);
      await firstCollection.items.save();
      await secondCollection.items.save();
      await isar.storageRefs.putAll([
        StorageRef()
          ..uid = 'same-time-a'
          ..ownerUid = item.uid!
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.local
          ..locator = 'a'
          ..createdAt = DateTime(2026)
          ..updatedAt = DateTime(2026),
        StorageRef()
          ..uid = 'same-time-b'
          ..ownerUid = item.uid!
          ..ownerType = StorageOwnerType.item
          ..sourceType = StorageSourceType.local
          ..locator = 'b'
          ..createdAt = DateTime(2026)
          ..updatedAt = DateTime(2026),
      ]);
    });

    final repairResult = await service.repairSafeIssues();

    expect(repairResult.isSuccess, isTrue);
    final after = repairResult.dataOrNull!.after;
    expect(after.countByType(LibraryIntegrityIssueType.tagCycle), 2);
    expect(
      after.countByType(LibraryIntegrityIssueType.multiplyOwnedMediaItem),
      1,
    );
    expect(
      after.countByType(LibraryIntegrityIssueType.duplicatePrimaryStorageRef),
      1,
    );
    expect(
      (await isar.storageRefs.filter().uidEqualTo('same-time-a').findFirst())!
          .isPrimary,
      isTrue,
    );
    expect(
      (await isar.storageRefs.filter().uidEqualTo('same-time-b').findFirst())!
          .isPrimary,
      isTrue,
    );
    expect((await isar.tags.get(first.id))!.parentId, second.id);
    expect((await isar.tags.get(second.id))!.parentId, first.id);
  });

  test('安全修復は冪等である', () async {
    final item = MediaItem()..path = 'library/no-uid.jpg';
    await isar.writeTxn(() async {
      await isar.mediaItems.put(item);
    });

    final first = await service.repairSafeIssues();
    final second = await service.repairSafeIssues();

    expect(first.isSuccess, isTrue);
    expect(first.dataOrNull!.changedRecordCount, 1);
    expect(second.isSuccess, isTrue);
    expect(second.dataOrNull!.changedRecordCount, 0);
    expect(second.dataOrNull!.after.isHealthy, isTrue);
  });

  test('関連のない既存ファイルだけをパスから安全に関連付ける', () async {
    final item = MediaItem()
      ..uid = 'missing-link-item'
      ..path = 'library/photo.jpg';
    final collection = MediaCollection()
      ..uid = 'missing-link-collection'
      ..path = item.path
      ..type = CollectionType.file
      ..notes = 'keep this note'
      ..isFavorite = true;
    await isar.writeTxn(() async {
      await isar.mediaItems.put(item);
      await isar.mediaCollections.put(collection);
    });

    final audit = await service.audit();
    expect(
      audit.dataOrNull!.countByType(
        LibraryIntegrityIssueType.missingMediaItemCollectionLink,
      ),
      1,
    );
    final repaired = await service.repairSafeIssues();
    expect(repaired.isSuccess, isTrue);
    expect(repaired.dataOrNull!.after.isHealthy, isTrue);
    final saved = (await isar.mediaItems.get(item.id))!;
    await saved.collection.load();
    expect(saved.collection.value!.id, collection.id);
    expect(saved.collection.value!.notes, 'keep this note');
    expect(saved.collection.value!.isFavorite, isTrue);
    expect(
      (await service.repairSafeIssues()).dataOrNull!.changedRecordCount,
      0,
    );
  });

  test('同じパスの個別情報を親フォルダ所属より優先し、独自の所属は保護する', () async {
    final parent = MediaCollection()
      ..uid = 'parent-folder'
      ..path = 'library/trip';
    final own = MediaCollection()
      ..uid = 'own-file'
      ..path = 'library/trip/photo.jpg'
      ..type = CollectionType.file;
    final custom = MediaCollection()
      ..uid = 'custom-owner'
      ..path = 'library/custom';
    final protectedOwn = MediaCollection()
      ..uid = 'protected-own-file'
      ..path = 'library/protected.jpg'
      ..type = CollectionType.file;
    final item = MediaItem()
      ..uid = 'parent-linked-item'
      ..path = own.path
      ..parentPath = parent.path;
    final protected = MediaItem()
      ..uid = 'custom-linked-item'
      ..path = protectedOwn.path;
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([item, protected]);
      await isar.mediaCollections.putAll([parent, own, custom, protectedOwn]);
      parent.items.add(item);
      custom.items.add(protected);
      await parent.items.save();
      await custom.items.save();
    });

    final repaired = await service.repairSafeIssues();
    expect(repaired.isSuccess, isTrue);
    final saved = (await isar.mediaItems.get(item.id))!;
    final protectedSaved = (await isar.mediaItems.get(protected.id))!;
    await saved.collection.load();
    await protectedSaved.collection.load();
    expect(saved.collection.value!.id, own.id);
    expect(protectedSaved.collection.value!.id, custom.id);
    expect(repaired.dataOrNull!.after.isHealthy, isTrue);
    expect(
      (await service.repairSafeIssues()).dataOrNull!.changedRecordCount,
      0,
    );
  });

  test('完了済みの関連修復ではDB全体を再読み込みしない', () async {
    final preferences = _MigrationPreferences();
    when(() => preferences.getBool(any())).thenReturn(false);
    when(() => preferences.setBool(any(), true)).thenAnswer((_) async => true);
    final links = CollectionItemLinkService(isar);
    expect(await links.migrateOnce(preferences), 0);
    verify(() => preferences.setBool(any(), true)).called(1);
    when(() => preferences.getBool(any())).thenReturn(true);
    // A read of this closed database would fail. Completed migrations must
    // only inspect their version flag, not hydrate every collection again.
    await isar.close();
    expect(await links.migrateOnce(preferences), 0);
    verifyNever(() => preferences.setBool(any(), true));
  });

  test('修復完了フラグの保存失敗は表面化し再試行できる', () async {
    final preferences = _MigrationPreferences();
    when(() => preferences.getBool(any())).thenReturn(null);
    when(() => preferences.setBool(any(), true)).thenAnswer((_) async => false);
    when(() => preferences.reload()).thenAnswer((_) async {});
    final links = CollectionItemLinkService(isar);
    await expectLater(links.migrateOnce(preferences), throwsStateError);
    verify(() => preferences.reload()).called(1);
    when(() => preferences.setBool(any(), true)).thenAnswer((_) async => true);
    expect(await links.migrateOnce(preferences), 0);
    verify(() => preferences.setBool(any(), true)).called(2);
  });
}
