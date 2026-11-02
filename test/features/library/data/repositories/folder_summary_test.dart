import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';

void main() {
  late Isar isar;
  late IsarMediaRepository repository;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('folder_summary_test_');
    isar = await Isar.open([
      MediaItemSchema,
      MediaCollectionSchema,
      TagSchema,
      TagFacetSchema,
      StorageRefSchema,
    ], directory: tempDir.path);
    repository = IsarMediaRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('getFolderSummary は空フォルダに対して正しい初期値を返す', () async {
    final result = await repository.getFolderSummary('empty_folder');
    expect(result.isSuccess, isTrue);
    final summary = result.dataOrNull!;
    expect(summary.totalCount, 0);
    expect(summary.folderCount, 0);
    expect(summary.fileCount, 0);
    expect(summary.isEmpty, isTrue);
  });

  test('getFolderSummary はフォルダとファイルの件数、画像を正しく集計する', () async {
    final folder1 = MediaItem()
      ..path = 'root/sub1'
      ..parentPath = 'root'
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final img1 = MediaItem()
      ..path = 'root/photo.jpg'
      ..parentPath = 'root'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy
      ..thumbnailPath = '.thumbnails/photo_thumb.jpg'
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final doc1 = MediaItem()
      ..path = 'root/memo.txt'
      ..parentPath = 'root'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final trashedItem = MediaItem()
      ..path = 'root/trashed.jpg'
      ..parentPath = 'root'
      ..type = MediaType.file
      ..isTrashed = true
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await repository.saveAll([folder1, img1, doc1, trashedItem]);

    final allItems = await repository.getAll();
    expect(allItems.dataOrNull?.length, 3);

    final result = await repository.getFolderSummary('root');
    expect(result.isSuccess, isTrue);
    final summary = result.dataOrNull!;
    expect(summary.totalCount, 3); // ゴミ箱除外
    expect(summary.folderCount, 1);
    expect(summary.fileCount, 2);
    expect(summary.imageCount, 1);
    expect(summary.documentCount, 1);
    expect(summary.firstThumbnailPath, '.thumbnails/photo_thumb.jpg');
    expect(summary.firstImagePath, 'root/photo.jpg');
  });

  test('getFolderSummary は直下の登録済みカタログだけを数える', () async {
    final now = DateTime.now();
    MediaItem folder(String path, String parentPath, {bool isHidden = false}) =>
        MediaItem()
          ..path = path
          ..parentPath = parentPath
          ..type = MediaType.folder
          ..isHidden = isHidden
          ..sourceType = MediaSourceType.localCopy
          ..addedAt = now
          ..updatedAt = now;

    final items = [
      folder('root/catalog', 'root'),
      folder('root/ordinary', 'root'),
      folder('root/hidden', 'root', isHidden: true),
      folder('root/ordinary/nested', 'root/ordinary'),
    ];
    await repository.saveAll(items);

    final catalogs = [
      MediaCollection()
        ..uid = 'folder_summary-1'
        ..path = 'root/catalog'
        ..isCatalog = true,
      MediaCollection()
        ..uid = 'folder_summary-2'
        ..path = 'root/ordinary'
        ..isCatalog = false,
      MediaCollection()
        ..uid = 'folder_summary-3'
        ..path = 'root/hidden'
        ..isCatalog = true,
      MediaCollection()
        ..uid = 'folder_summary-4'
        ..path = 'root/ordinary/nested'
        ..isCatalog = true,
    ];
    await isar.writeTxn(() async {
      await isar.mediaCollections.putAll(catalogs);
      expect(await isar.mediaCollections.count(), catalogs.length);
    });

    final visible = (await repository.getFolderSummary(
      'root',
      isHidden: false,
    )).dataOrNull!;
    expect(visible.folderCount, 2);
    expect(visible.catalogCount, 1);

    final all = (await repository.getFolderSummary('root')).dataOrNull!;
    expect(all.folderCount, 3);
    expect(all.catalogCount, 2);
  });

  test('hasAnyItems はアイテムの存在状態を正しく判定する', () async {
    final initialHas = await repository.hasAnyItems();
    expect(initialHas.dataOrNull, isFalse);

    final item = MediaItem()
      ..path = 'test.jpg'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.mediaItems.put(item);
    });

    final afterHas = await repository.hasAnyItems();
    expect(afterHas.dataOrNull, isTrue);
  });
}
