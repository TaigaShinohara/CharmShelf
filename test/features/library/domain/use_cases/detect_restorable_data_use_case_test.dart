import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/application/use_cases/detect_restorable_data_use_case.dart';

class _TestLocalStorageManager extends LocalStorageManager {
  final Directory _mockRootDir;
  _TestLocalStorageManager(this._mockRootDir);

  @override
  Future<Directory> getRootDirectory({
    bool forceRefresh = false,
    bool allowPublic = true,
  }) async => _mockRootDir;

  @override
  Future<Directory> getPrivateRootDirectory() async => _mockRootDir;

  @override
  Future<Directory> getMetadataDirectory() async {
    final metaDir = Directory(
      p.join(_mockRootDir.path, LocalStorageManager.sidecarMetaDirName),
    );
    if (!metaDir.existsSync()) {
      metaDir.createSync(recursive: true);
    }
    return metaDir;
  }

  @override
  Future<File> getMetadataFile() async {
    final metaDir = await getMetadataDirectory();
    return File(p.join(metaDir.path, LocalStorageManager.metadataFileName));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;
  late _TestLocalStorageManager storageManager;
  late DetectRestorableDataUseCase useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('detect_restore_test_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDir.path,
      name: 'detect_restore_test_${DateTime.now().microsecondsSinceEpoch}',
    );

    storageManager = _TestLocalStorageManager(tempDir);
    useCase = DetectRestorableDataUseCase(isar, storageManager);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DetectRestorableDataUseCase', () {
    test('データが存在しない空の状態では hasRestorableData: false を返す', () async {
      final result = await useCase.call();
      expect(result.isSuccess, isTrue);
      final summary = result.dataOrNull!;
      expect(summary.hasRestorableData, isFalse);
    });

    test('metadata.json が存在する場合、タグやコレクション数を正しく検出する', () async {
      final metaFile = await storageManager.getMetadataFile();
      final metaData = {
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'tags': [
          {'key': 'tag1', 'name': 'お気に入り'},
          {'key': 'tag2', 'name': '漫画'},
        ],
        'collections': [
          {'relativePath': 'library/MyManga', 'title': 'MyManga'},
        ],
        'mediaItems': [
          {'relativePath': 'library/MyManga/page1.jpg'},
        ],
      };
      await metaFile.writeAsString(jsonEncode(metaData));

      final result = await useCase.call();
      expect(result.isSuccess, isTrue);
      final summary = result.dataOrNull!;
      expect(summary.hasRestorableData, isTrue);
      expect(summary.hasMetadataFile, isTrue);
      expect(summary.tagCount, equals(2));
      expect(summary.collectionCount, equals(1));
      expect(summary.mediaItemCount, equals(1));
    });

    test('実体ファイル・フォルダが存在する場合に正しく検出する', () async {
      final folder = Directory(p.join(tempDir.path, 'library/Photos'))
        ..createSync(recursive: true);
      File(p.join(folder.path, 'photo1.jpg')).writeAsBytesSync([1, 2, 3]);
      File(p.join(folder.path, 'photo2.png')).writeAsBytesSync([1, 2, 3]);

      final result = await useCase.call();
      expect(result.isSuccess, isTrue);
      final summary = result.dataOrNull!;
      expect(summary.hasRestorableData, isTrue);
      expect(summary.collectionCount, equals(1));
      expect(summary.mediaItemCount, equals(2));
    });

    test('管理領域外のルート直下フォルダは復元候補に数えない', () async {
      final legacySmoke = Directory(
        p.join(tempDir.path, 'legacy_migration_smoke'),
      )..createSync(recursive: true);
      File(p.join(legacySmoke.path, 'photo.jpg')).writeAsBytesSync([1, 2, 3]);

      final result = await useCase.call();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.hasRestorableData, isFalse);
    });

    test('DB に既にユーザーコレクションが存在する場合は検出をスキップ（hasRestorableData: false）', () async {
      // DB にユーザーコレクションを追加
      await isar.writeTxn(() async {
        final col = MediaCollection()
          ..path = 'library/ExistingCol'
          ..title = 'Existing'
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isar.mediaCollections.put(col);
      });

      // ディスク上にもデータを用意
      final folder = Directory(p.join(tempDir.path, 'library/Photos'))
        ..createSync(recursive: true);
      File(p.join(folder.path, 'photo1.jpg')).writeAsBytesSync([1, 2, 3]);

      final result = await useCase.call();
      expect(result.isSuccess, isTrue);
      final summary = result.dataOrNull!;
      expect(summary.hasRestorableData, isFalse);
    });

    test('空の私有メタデータがあってもAndroid旧公開メタデータだけの復元候補を検出する', () async {
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final androidStorage = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      final privateMetadata = await androidStorage.getMetadataFile();
      await privateMetadata.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': <Object>[],
          'collections': <Object>[],
          'mediaItems': <Object>[],
        }),
      );
      await androidStorage.getRootDirectory();
      final legacyMetadata = File(
        p.join(
          publicRoot.path,
          LocalStorageManager.sidecarMetaDirName,
          LocalStorageManager.metadataFileName,
        ),
      );
      await legacyMetadata.parent.create(recursive: true);
      await legacyMetadata.writeAsString(
        jsonEncode({
          'version': 2,
          'exportedAt': '2026-08-30T00:00:00.000Z',
          'tags': [
            {'key': 'legacy::only', 'name': 'Legacy only'},
          ],
          'collections': <Object>[],
          'mediaItems': <Object>[],
        }),
      );

      final result = await DetectRestorableDataUseCase(
        isar,
        androidStorage,
      ).call();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.hasRestorableData, isTrue);
      expect(result.dataOrNull?.hasMetadataFile, isTrue);
      expect(result.dataOrNull?.tagCount, 1);
    });
  });
}
