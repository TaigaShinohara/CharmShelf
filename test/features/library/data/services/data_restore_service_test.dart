import 'dart:convert';
import 'dart:io';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'legacy_migration_service_test.dart' show MemoryLegacyStorage;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/services/data_restore_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/services/folder_sync_service.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';

class _MockExternalStorage extends Mock implements ExternalStorageService {}

class _MockPermissionRepository extends Mock implements PermissionRepository {}

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
  late SidecarMetadataService sidecarService;
  late FolderSyncService folderSyncService;
  late _MockPermissionRepository permissionRepo;
  late DataRestoreService dataRestoreService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'data_restore_service_test_',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );

    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDir.path,
      name:
          'data_restore_service_test_${DateTime.now().microsecondsSinceEpoch}',
    );

    storageManager = _TestLocalStorageManager(tempDir);
    sidecarService = SidecarMetadataService(isar, storageManager);
    permissionRepo = _MockPermissionRepository();
    when(
      () => permissionRepo.getManageStoragePermissionStatus(),
    ).thenAnswer((_) async => PermissionResult.granted);

    folderSyncService = FolderSyncService(
      isar,
      storageManager,
      sidecarService,
      permissionRepo,
    );

    dataRestoreService = DataRestoreService(sidecarService, folderSyncService);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DataRestoreService', () {
    test('初回移行は現在のファイル・チャームを保持し旧カタログを復元してから元を削除する', () async {
      final old = MemoryLegacyStorage();
      old.files['library/album/photo.jpg'] = [1, 2, 3];
      old.files['library/single.txt'] = utf8.encode('single-file catalog');
      old.files['.tagshelf/metadata.json'] = utf8.encode(
        jsonEncode({
          'version': 2,
          'tags': [
            {'key': 'common', 'name': 'Old name'},
            {'key': 'old-only', 'name': 'Old only'},
          ],
          'collections': [
            {
              'relativePath': 'library/single.txt',
              'type': 'file',
              'isCatalog': true,
              'isFavorite': true,
              'tagKeys': ['old-only'],
            },
            {
              'uid': 'same-uid',
              'relativePath': 'library/album',
              'title': 'Old album',
              'isCatalog': true,
              'isFavorite': true,
              'tagKeys': ['common', 'old-only'],
            },
          ],
          'mediaItems': [
            {'relativePath': 'library/album/photo.jpg', 'isHidden': true},
            {'relativePath': 'library/album', 'isHidden': true},
          ],
        }),
      );
      final current = File(p.join(tempDir.path, 'library/album/photo.jpg'));
      await current.parent.create(recursive: true);
      await current.writeAsBytes([9, 8, 7]);
      final tag = Tag()
        ..key = 'common'
        ..name = 'Current name';
      final catalog = MediaCollection()
        ..uid = 'same-uid'
        ..path = 'library/album'
        ..title = 'Current album'
        ..isCatalog = true;
      await isar.writeTxn(() async {
        await isar.tags.put(tag);
        await isar.mediaCollections.put(catalog);
      });
      final migration = LegacyMigrationService(
        root: tempDir,
        storage: old,
        checkReferences: (_) async {},
        restorePrepared: (prepared) async {
          final result = await dataRestoreService.restore(
            preparedSource: prepared,
            preserveExistingTags: true,
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: result.errorOrNull?.toString(),
          );
        },
      );
      final record = await migration.inspect(
        Uri.parse(
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
        ),
      );
      await migration.execute(restore: true);
      expect(old.files, isEmpty);
      expect(await current.readAsBytes(), [9, 8, 7]);
      expect(
        (await isar.tags.where().keyEqualTo('common').findFirst())!.name,
        'Current name',
      );
      expect(
        (await isar.mediaCollections
                .where()
                .pathEqualTo('library/album')
                .findFirst())!
            .title,
        'Current album',
      );
      final restored = await isar.mediaCollections
          .where()
          .pathEqualTo('library/Restored-${record.id}/library/album')
          .findFirst();
      expect(restored, isNotNull);
      expect(restored!.isCatalog, isTrue);
      expect(restored.isFavorite, isTrue);
      await restored.tags.load();
      expect(
        restored.tags.map((t) => t.key),
        containsAll(['common', 'old-only']),
      );
      final media = await isar.mediaItems
          .where()
          .pathEqualTo('library/Restored-${record.id}/library/album/photo.jpg')
          .findFirst();
      expect(media!.isHidden, isTrue);
      final single = await isar.mediaCollections
          .where()
          .pathEqualTo('library/Restored-${record.id}/library/single.txt')
          .findFirst();
      expect(single!.type, CollectionType.file);
      expect(single.isCatalog, isTrue);
      expect(single.isFavorite, isTrue);
      final folder = await isar.mediaItems
          .where()
          .pathEqualTo('library/Restored-${record.id}/library/album')
          .findFirst();
      expect(folder!.isHidden, isTrue);
    });

    for (final conflict in [false, true]) {
      test('SAF復元は権限不要で元データと既存ファイルを保護する conflict=$conflict', () async {
        final staging = await Directory.systemTemp.createTemp(
          'saf_restore_test_',
        );
        final media = File(p.join(staging.path, 'library/photo.jpg'));
        await media.parent.create(recursive: true);
        await media.writeAsBytes([1, 2, 3]);
        final metadata = File(
          p.join(staging.path, '.tagshelf/metadata.json.bak'),
        );
        await metadata.parent.create(recursive: true);
        await metadata.writeAsString(
          jsonEncode({
            'version': 2,
            'tags': [],
            'collections': [],
            'mediaItems': [
              {
                'relativePath': 'library/photo.jpg',
                'isHidden': true,
                'isArchived': true,
              },
            ],
          }),
        );
        final destination = File(p.join(tempDir.path, 'library/photo.jpg'));
        if (conflict) {
          await destination.parent.create(recursive: true);
          await destination.writeAsBytes([9, 8, 7]);
        }
        final external = _MockExternalStorage();
        final uri = Uri.parse('content://test/tree/CharmShelf');
        when(
          () => external.stageRecoveryFolder(uri),
        ).thenAnswer((_) async => staging);
        final service = DataRestoreService(
          sidecarService,
          folderSyncService,
          externalStorage: external,
        );
        final result = await service.restore(sourceUri: uri);
        expect(result.isSuccess, !conflict);
        expect(
          await destination.readAsBytes(),
          conflict ? [9, 8, 7] : [1, 2, 3],
        );
        verifyNever(() => permissionRepo.getManageStoragePermissionStatus());
        expect(await staging.exists(), isFalse);
        if (!conflict) {
          final item = await isar.mediaItems
              .where()
              .pathEqualTo('library/photo.jpg')
              .findFirst();
          expect(item?.isHidden, isTrue);
          expect(item?.isArchived, isTrue);
        }
      });
    }

    test('メタデータとファイル実体の両方がDBに復元される', () async {
      // 1. メタデータファイルの配置
      final metaFile = await storageManager.getMetadataFile();
      final metaData = {
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'tags': [
          {'key': 'fav_tag', 'name': 'お気に入り'},
        ],
        'collections': [
          {
            'relativePath': 'library/Comics',
            'title': 'Comics',
            'tagKeys': ['fav_tag'],
          },
        ],
        'mediaItems': [],
      };
      await metaFile.writeAsString(jsonEncode(metaData));

      // 2. 実体フォルダとファイルの配置
      final comicsDir = Directory(p.join(tempDir.path, 'library/Comics'))
        ..createSync(recursive: true);
      File(p.join(comicsDir.path, 'vol1.jpg')).writeAsBytesSync([1, 2, 3]);

      // 3. 復元実行
      final result = await dataRestoreService.restore();
      expect(result.isSuccess, isTrue);

      // 4. DB検証
      final restoredTags = await isar.tags.where().findAll();
      expect(restoredTags.length, equals(1));
      expect(restoredTags.first.key, equals('fav_tag'));

      final restoredCols = await isar.mediaCollections.where().findAll();
      expect(restoredCols.any((c) => c.path == 'library/Comics'), isTrue);
      final comicCol = restoredCols.firstWhere(
        (c) => c.path == 'library/Comics',
      );
      await comicCol.tags.load();
      expect(comicCol.tags.map((t) => t.key).contains('fav_tag'), isTrue);

      final restoredItems = await isar.mediaItems.where().findAll();
      expect(
        restoredItems.any((i) => i.path == 'library/Comics/vol1.jpg'),
        isTrue,
      );
    });

    test('メタデータが存在しない場合は実体ファイルだけを復元できる', () async {
      final imageDir = Directory(p.join(tempDir.path, 'library/Images'))
        ..createSync(recursive: true);
      File(p.join(imageDir.path, 'photo.jpg')).writeAsBytesSync([1, 2, 3]);

      final result = await dataRestoreService.restore();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.restoredTagsAndCols, 0);
      final restoredItems = await isar.mediaItems.where().findAll();
      expect(
        restoredItems.any((item) => item.path.endsWith('photo.jpg')),
        isTrue,
      );
    });

    test('ファイルDB作成後に非表示メタデータを取りこぼさず復元する', () async {
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': <Object>[],
          'collections': <Object>[],
          'mediaItems': [
            {
              'relativePath': 'library/hidden.jpg',
              'isArchived': true,
              'isHidden': true,
            },
          ],
        }),
      );
      final source = File(p.join(tempDir.path, 'library', 'hidden.jpg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1, 2, 3]);

      final result = await dataRestoreService.restore();

      expect(result.isSuccess, isTrue);
      final restored = await isar.mediaItems
          .where()
          .pathEqualTo('library/hidden.jpg')
          .findFirst();
      expect(restored?.isHidden, isTrue);
      expect(restored?.isArchived, isTrue);
    });

    test('Android旧公開メタデータのアイテム状態を私有コピー作成後に復元する', () async {
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicFile = File(
        p.join(publicRoot.path, 'library', 'legacy-hidden.jpg'),
      );
      await publicFile.parent.create(recursive: true);
      await publicFile.writeAsBytes([1, 2, 3]);
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
          'tags': <Object>[],
          'collections': <Object>[],
          'mediaItems': [
            {
              'relativePath': 'library/legacy-hidden.jpg',
              'isArchived': true,
              'isHidden': true,
            },
          ],
        }),
      );
      final androidStorage = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      final androidSidecar = SidecarMetadataService(isar, androidStorage);
      final androidRestore = DataRestoreService(
        androidSidecar,
        FolderSyncService(isar, androidStorage, androidSidecar, permissionRepo),
      );

      final result = await androidRestore.restore();

      expect(result.isSuccess, isTrue);
      final restored = await isar.mediaItems
          .where()
          .pathEqualTo('library/legacy-hidden.jpg')
          .findFirst();
      expect(restored?.isHidden, isTrue);
      expect(restored?.isArchived, isTrue);
      expect(
        await File(
          p.join(privateRoot.path, 'library', 'legacy-hidden.jpg'),
        ).readAsBytes(),
        [1, 2, 3],
      );
      expect(await legacyMetadata.exists(), isFalse);
    });

    test('メタデータ本体とバックアップが破損している場合は成功扱いにしない', () async {
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.writeAsString('{broken');
      await File('${metaFile.path}.bak').writeAsString('{also-broken');
      final imageDir = Directory(p.join(tempDir.path, 'library/Images'))
        ..createSync(recursive: true);
      File(p.join(imageDir.path, 'photo.jpg')).writeAsBytesSync([1, 2, 3]);

      final result = await dataRestoreService.restore();

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, contains('メタデータファイルが破損'));
      // 破損メタデータはファイルDBへ変更を加える前に拒否する。
      expect(await isar.mediaItems.where().count(), 0);
    });
  });
}
