import 'dart:async';
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
    tempDirectory = await Directory.systemTemp.createTemp(
      'media_thumbnail_repo_',
    );
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'media_thumbnail_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = IsarMediaRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('生成サムネイルの保存は他の項目を保持し一覧監視を起こさない', () async {
    final item = MediaItem()
      ..path = 'library/photo.jpg'
      ..isHidden = true;
    expect((await repository.save(item)).isSuccess, isTrue);

    var notifications = 0;
    final normalWriteNotified = Completer<void>();
    final subscription = isar.mediaItems
        .watchLazy(fireImmediately: false)
        .listen((_) {
          notifications++;
          if (!normalWriteNotified.isCompleted) normalWriteNotified.complete();
        });
    addTearDown(subscription.cancel);

    final result = await repository.saveGeneratedThumbnailPath(
      item.id,
      item.path,
      '.thumbnails/photo.jpg',
    );
    expect(result.isSuccess, isTrue);
    expect(
      (await isar.mediaItems.get(item.id))?.thumbnailPath,
      '.thumbnails/photo.jpg',
    );
    expect((await isar.mediaItems.get(item.id))?.isHidden, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(notifications, 0);

    final stored = (await isar.mediaItems.get(item.id))!..isHidden = false;
    expect((await repository.save(stored)).isSuccess, isTrue);
    await normalWriteNotified.future.timeout(const Duration(seconds: 1));
    expect(notifications, 1);
  });

  test('古いパスと既存のサムネイルは上書きしない', () async {
    final item = MediaItem()
      ..path = 'library/photo.jpg'
      ..thumbnailPath = '.thumbnails/existing.jpg';
    expect((await repository.save(item)).isSuccess, isTrue);

    expect(
      (await repository.saveGeneratedThumbnailPath(
        item.id,
        'library/old.jpg',
        '.thumbnails/stale.jpg',
      )).isSuccess,
      isTrue,
    );
    expect(
      (await repository.saveGeneratedThumbnailPath(
        item.id,
        item.path,
        '.thumbnails/new.jpg',
      )).isSuccess,
      isTrue,
    );
    expect(
      (await isar.mediaItems.get(item.id))?.thumbnailPath,
      '.thumbnails/existing.jpg',
    );
  });
}
