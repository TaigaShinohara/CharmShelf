import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('recent_media_repo_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'recent_media_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = IsarMediaRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('非表示項目をlimit前に除外して古い公開項目を補充する', () async {
    final now = DateTime.now();
    final items = <MediaItem>[];
    final collections = <MediaCollection>[];

    for (var index = 0; index < 25; index++) {
      final hidden = index < 15;
      final path = 'library/item-$index.jpg';
      final item = MediaItem()
        ..uid = 'item-$index'
        ..path = path
        ..sourceType = MediaSourceType.localCopy
        ..isHidden = hidden
        ..addedAt = now.subtract(Duration(minutes: index));
      final collection = MediaCollection()
        ..uid = 'collection-$index'
        ..path = path
        ..title = 'item-$index'
        ..type = CollectionType.file
        ..isHidden = hidden
        ..lastViewedAt = now.subtract(Duration(minutes: index));
      items.add(item);
      collections.add(collection);
    }

    await isar.writeTxn(() async {
      await isar.mediaItems.putAll(items);
      for (var index = 0; index < collections.length; index++) {
        collections[index].lastViewedItemId = items[index].id;
      }
      await isar.mediaCollections.putAll(collections);
      for (var index = 0; index < collections.length; index++) {
        collections[index].items.add(items[index]);
        await collections[index].items.save();
      }
    });

    final result = await repository.getRecentMedia(
      limit: 10,
      sourceType: MediaSourceType.localCopy,
      isHidden: false,
    );

    expect(result.isSuccess, isTrue);
    final recent = result.dataOrNull!;
    expect(recent, hasLength(10));
    expect(recent.every((item) => !item.isHidden), isTrue);
    expect(recent.first.path, 'library/item-15.jpg');
    expect(recent.last.path, 'library/item-24.jpg');
  });
}
