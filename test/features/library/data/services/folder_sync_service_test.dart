import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/services/folder_sync_service.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/data/services/template_collection_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';

class _MockPermissionRepository extends Mock implements PermissionRepository {}

class _MockSidecarMetadataService extends Mock
    implements SidecarMetadataService {}

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;
  late _TestLocalStorageManager storageManager;
  late SidecarMetadataService sidecarService;
  late _MockPermissionRepository permissionRepo;
  late FolderSyncService folderSyncService;
  late FileService fileService;
  late TemplateCollectionService templateService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folder_sync_test_');

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
      name: 'folder_sync_test_${DateTime.now().microsecondsSinceEpoch}',
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

    fileService = FileService();
    templateService = TemplateCollectionService(isar, fileService);
  });

  test('未確定の移行コピーと子要素を通常の走査で登録しない', () async {
    final staged = Directory(p.join(tempDir.path, 'library', 'migration'));
    await staged.create(recursive: true);
    await File(p.join(staged.path, 'copy.txt')).writeAsString('pending');
    await File(
      p.join(tempDir.path, 'library', 'normal.txt'),
    ).writeAsString('normal');
    final sync = FolderSyncService(
      isar,
      storageManager,
      sidecarService,
      permissionRepo,
      reservedPaths: () async => {'library/migration'},
    );
    final result = await sync.syncAll(
      importMetadata: false,
      exportMetadata: false,
    );
    expect(result.isSuccess, isTrue);
    final items = await isar.mediaItems.where().findAll();
    expect(items.any((i) => i.path.contains('migration')), isFalse);
    expect(items.any((i) => i.path == 'library/normal.txt'), isTrue);
    expect(
      await File(p.join(staged.path, 'copy.txt')).readAsString(),
      'pending',
    );
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

  group('FolderSyncService & Root Library Exclusions', () {
    test('library フォルダ自身は MediaCollection として登録されず、配下のフォルダのみが登録される', () async {
      // フォルダ構造の準備:
      // tempDir/library (管理ルート)
      // tempDir/library/MyFolder (カタログフォルダ)
      // tempDir/library/MyFolder/sample.jpg (アイテム)
      // tempDir/library/root_item.jpg (ルート直下アイテム)
      final libraryDir = Directory(p.join(tempDir.path, 'library'))
        ..createSync(recursive: true);
      final catalogDir = Directory(p.join(libraryDir.path, 'MyFolder'))
        ..createSync(recursive: true);
      File(p.join(catalogDir.path, 'sample.jpg')).writeAsBytesSync([0, 1, 2]);
      File(
        p.join(libraryDir.path, 'root_item.jpg'),
      ).writeAsBytesSync([0, 1, 2]);

      final result = await folderSyncService.syncAll();
      expect(result.isSuccess, isTrue);

      final collections = await isar.mediaCollections.where().findAll();
      final collectionPaths = collections.map((c) => c.path).toList();

      // library 自身はコレクションに含まれない
      expect(collectionPaths.contains('library'), isFalse);
      // library/MyFolder はコレクションに含まれる
      expect(collectionPaths.contains('library/MyFolder'), isTrue);
      expect(
        collections.singleWhere((c) => c.path == 'library/MyFolder').isCatalog,
        false,
      );

      final items = await isar.mediaItems.where().findAll();
      final folderItem = items.singleWhere(
        (item) => item.path == 'library/MyFolder',
      );
      expect(folderItem.type, MediaType.folder);
      expect(folderItem.parentPath, isNull);
      expect(folderItem.isMissing, isFalse);
      expect(result.dataOrNull?.added, 3);
      await folderItem.collection.load();
      expect(folderItem.collection.value!.path, 'library/MyFolder');
      final child = items.singleWhere(
        (item) => item.path == 'library/MyFolder/sample.jpg',
      );
      await child.collection.load();
      expect(child.collection.value!.id, folderItem.collection.value!.id);
      expect((await folderSyncService.syncAll()).isSuccess, isTrue);
      final savedFolder = (await isar.mediaItems.get(folderItem.id))!;
      await savedFolder.collection.load();
      expect(savedFolder.collection.value!.id, folderItem.collection.value!.id);
    });

    test('カタログ解除したフォルダはメタデータ読込と再同期後も通常フォルダのまま', () async {
      Directory(
        p.join(tempDir.path, 'library', 'MyFolder'),
      ).createSync(recursive: true);
      const path = 'library/MyFolder';
      expect((await folderSyncService.syncAll()).isSuccess, isTrue);

      final collection = await isar.mediaCollections
          .filter()
          .pathEqualTo(path)
          .findFirst();
      collection!.isCatalog = true;
      await isar.writeTxn(() => isar.mediaCollections.put(collection));
      expect((await sidecarService.exportMetadata()).isSuccess, isTrue);

      collection.isCatalog = false;
      await isar.writeTxn(() => isar.mediaCollections.put(collection));
      expect((await folderSyncService.syncAll()).isSuccess, isTrue);
      expect((await folderSyncService.syncAll()).isSuccess, isTrue);

      final restored = await isar.mediaCollections
          .filter()
          .pathEqualTo(path)
          .findFirst();
      expect(restored?.isCatalog, false);
    });

    test('管理ルート直下のフォルダや対応ファイルは同期対象に含めない', () async {
      final unmanagedDir = Directory(p.join(tempDir.path, 'migration_check'))
        ..createSync(recursive: true);
      File(p.join(unmanagedDir.path, 'outside.jpg')).writeAsBytesSync([1]);
      final managedFile = File(p.join(tempDir.path, 'library', 'inside.jpg'));
      await managedFile.parent.create(recursive: true);
      await managedFile.writeAsBytes([2]);

      final result = await folderSyncService.syncAll();

      expect(result.isSuccess, isTrue);
      final items = await isar.mediaItems.where().findAll();
      expect(items.map((item) => item.path), ['library/inside.jpg']);
      expect(await isar.mediaCollections.count(), 0);
    });

    test('子孫のファイルをさらに上のカタログの表紙に設定しない', () async {
      final parentDir = Directory(p.join(tempDir.path, 'library', 'Parent'))
        ..createSync(recursive: true);
      final childDir = Directory(p.join(parentDir.path, 'Child'))
        ..createSync(recursive: true);
      File(p.join(childDir.path, 'cover.jpg')).writeAsBytesSync([0, 1, 2]);

      final result = await folderSyncService.syncAll();

      expect(result.isSuccess, isTrue);
      final parentCollection = await isar.mediaCollections
          .filter()
          .pathEqualTo('library/Parent')
          .findFirst();
      final childCollection = await isar.mediaCollections
          .filter()
          .pathEqualTo('library/Parent/Child')
          .findFirst();
      expect(parentCollection, isNotNull);
      expect(parentCollection!.coverImagePath, isNull);
      expect(childCollection, isNotNull);
      expect(childCollection!.coverImagePath, 'library/Parent/Child/cover.jpg');
    });

    test('既存のフォルダ項目は再スキャン後も未検出扱いにならない', () async {
      final folder = Directory(p.join(tempDir.path, 'library', 'Existing'))
        ..createSync(recursive: true);
      final item = MediaItem()
        ..uid = 'existing-folder'
        ..path = 'library/Existing'
        ..originalPath = folder.path
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder
        ..isMissing = false;
      await isar.writeTxn(() => isar.mediaItems.put(item));

      final result = await folderSyncService.syncAll();

      expect(result.isSuccess, isTrue);
      final stored = await isar.mediaItems
          .where()
          .uidEqualTo('existing-folder')
          .findFirst();
      expect(stored?.isMissing, isFalse);
      expect(result.dataOrNull?.missing, 0);
    });

    test('repairInvalidRootCollections により不正な library コレクションが削除される', () async {
      // 不正な library コレクションを手動で挿入
      final invalidCol = MediaCollection()
        ..uid = 'invalid-1'
        ..title = 'library'
        ..path = 'library'
        ..isCatalog = true
        ..type = CollectionType.folder;

      final validCol = MediaCollection()
        ..uid = 'valid-1'
        ..title = 'はじめてのCharmShelf'
        ..path = 'library/はじめてのCharmShelf'
        ..isCatalog = true
        ..type = CollectionType.folder;

      await isar.writeTxn(() async {
        await isar.mediaCollections.putAll([invalidCol, validCol]);
      });

      expect(await isar.mediaCollections.count(), equals(2));

      // 修復を実行
      await templateService.repairInvalidRootCollections();

      final remaining = await isar.mediaCollections.where().findAll();
      expect(remaining.length, equals(1));
      expect(remaining.first.path, equals('library/はじめてのCharmShelf'));
    });

    test(
      'crash_reports.json や .DS_Store などのシステムファイルは走査対象外となり、DBからも自動パージされる',
      () async {
        final libraryDir = Directory(p.join(tempDir.path, 'library'))
          ..createSync(recursive: true);
        // 通常ファイル
        File(p.join(libraryDir.path, 'valid.jpg')).writeAsBytesSync([1, 2, 3]);
        // システム・除外ファイル
        File(
          p.join(tempDir.path, 'crash_reports.json'),
        ).writeAsStringSync('{}');
        File(p.join(libraryDir.path, '.DS_Store')).writeAsStringSync('dummy');
        File(p.join(libraryDir.path, 'temp.tmp')).writeAsStringSync('tmp');

        // 過去に誤ってDB登録されていた crash_reports.json と valid.jpg のレコードを準備
        final invalidItem = MediaItem()
          ..uid = 'legacy-crash-log'
          ..path = 'crash_reports.json'
          ..sourceType = MediaSourceType.localCopy
          ..type = MediaType.file;

        await isar.writeTxn(() async {
          await isar.mediaItems.put(invalidItem);
        });

        expect(await isar.mediaItems.count(), equals(1));

        // 同期を実行
        final result = await folderSyncService.syncAll();
        expect(result.isSuccess, isTrue);

        final items = await isar.mediaItems.where().findAll();
        final itemPaths = items.map((i) => i.path).toList();

        // crash_reports.json や .DS_Store は登録されておらず、DBからも削除されている
        expect(itemPaths.contains('crash_reports.json'), isFalse);
        expect(itemPaths.contains('library/.DS_Store'), isFalse);
        expect(itemPaths.contains('library/temp.tmp'), isFalse);
        // 通常ファイルのみ登録されている
        expect(itemPaths.contains('library/valid.jpg'), isTrue);
      },
    );

    test('Android公開復元のメディアを私有領域へ検証コピーしてから登録する', () async {
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final source = File(p.join(publicRoot.path, 'library', 'photo.jpg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1, 2, 3, 4]);

      final androidStorage = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      final androidSidecar = SidecarMetadataService(isar, androidStorage);
      final service = FolderSyncService(
        isar,
        androidStorage,
        androidSidecar,
        permissionRepo,
      );

      final result = await service.syncAll(importPublicRecoverySource: true);

      expect(result.isSuccess, isTrue);
      final privateCopy = File(
        p.join(privateRoot.path, 'library', 'photo.jpg'),
      );
      expect(await privateCopy.readAsBytes(), [1, 2, 3, 4]);
      final item = await isar.mediaItems.where().findFirst();
      expect(item?.path, 'library/photo.jpg');
      expect(item?.originalPath, privateCopy.path);
      expect(
        await Directory(p.join(publicRoot.path, '.tagshelf')).exists(),
        isFalse,
      );
    });

    test('通常同期はAndroid公開領域や全ファイル権限に触れず私有領域だけを走査する', () async {
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicFile = File(p.join(publicRoot.path, 'library', 'public.jpg'));
      final privateFile = File(
        p.join(privateRoot.path, 'library', 'private.jpg'),
      );
      await publicFile.parent.create(recursive: true);
      await privateFile.parent.create(recursive: true);
      await publicFile.writeAsBytes([1]);
      await privateFile.writeAsBytes([2]);
      final androidStorage = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      final service = FolderSyncService(
        isar,
        androidStorage,
        SidecarMetadataService(isar, androidStorage),
        permissionRepo,
      );

      final result = await service.syncAll();

      expect(result.isSuccess, isTrue);
      final items = await isar.mediaItems.where().findAll();
      expect(items.map((item) => item.path), ['library/private.jpg']);
      verifyNever(() => permissionRepo.getManageStoragePermissionStatus());
    });

    test('公開復元元に内容の異なる同名ファイルがある場合は全コピーを開始前に中断する', () async {
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicConflict = File(
        p.join(publicRoot.path, 'library', 'conflict.jpg'),
      );
      final publicNew = File(p.join(publicRoot.path, 'library', 'new.jpg'));
      final privateConflict = File(
        p.join(privateRoot.path, 'library', 'conflict.jpg'),
      );
      await publicConflict.parent.create(recursive: true);
      await privateConflict.parent.create(recursive: true);
      await publicConflict.writeAsBytes([1, 2, 3, 4]);
      await publicNew.writeAsBytes([5, 6, 7, 8]);
      await privateConflict.writeAsBytes([9, 9, 9, 9]);
      final androidStorage = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      final service = FolderSyncService(
        isar,
        androidStorage,
        SidecarMetadataService(isar, androidStorage),
        permissionRepo,
      );

      final result = await service.syncAll(
        importMetadata: false,
        exportMetadata: false,
        importPublicRecoverySource: true,
      );

      expect(result.isFailure, isTrue);
      expect(await privateConflict.readAsBytes(), [9, 9, 9, 9]);
      expect(
        await File(p.join(privateRoot.path, 'library', 'new.jpg')).exists(),
        isFalse,
      );
      expect(await isar.mediaItems.count(), 0);
    });

    test('サイドカー読み込み失敗時はスキャンとDB更新を行わない', () async {
      final failingSidecar = _MockSidecarMetadataService();
      when(
        () => failingSidecar.importMetadata(),
      ).thenAnswer((_) async => Result.failure(AppError.file('import failed')));
      final service = FolderSyncService(
        isar,
        storageManager,
        failingSidecar,
        permissionRepo,
      );
      final source = File(p.join(tempDir.path, 'library', 'photo.jpg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1]);

      final result = await service.syncAll();

      expect(result.isFailure, isTrue);
      expect(await isar.mediaItems.count(), 0);
      verify(() => failingSidecar.importMetadata()).called(1);
      verifyNever(() => failingSidecar.exportMetadata());
    });

    test('サイドカー書き込み失敗を同期成功として返さない', () async {
      final failingSidecar = _MockSidecarMetadataService();
      when(
        () => failingSidecar.importMetadata(),
      ).thenAnswer((_) async => Result.success(0));
      when(
        () => failingSidecar.exportMetadata(),
      ).thenAnswer((_) async => Result.failure(AppError.file('export failed')));
      final service = FolderSyncService(
        isar,
        storageManager,
        failingSidecar,
        permissionRepo,
      );
      final source = File(p.join(tempDir.path, 'library', 'photo.jpg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1]);

      final result = await service.syncAll();

      expect(result.isFailure, isTrue);
      expect(await isar.mediaItems.count(), 1);
      verify(() => failingSidecar.importMetadata()).called(2);
      verify(() => failingSidecar.exportMetadata()).called(1);
    });
  });
}
