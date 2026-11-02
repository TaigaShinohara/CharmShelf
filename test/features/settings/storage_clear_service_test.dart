import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_service.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_recovery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDocDir;
  late Directory tempCacheDir;
  late Directory tempSupportDir;
  late LocalStorageManager storageManager;
  late StorageClearRecoveryStore recoveryStore;
  late StorageClearService service;

  setUp(() async {
    tempDocDir = await Directory.systemTemp.createTemp(
      'storage_clear_doc_test_',
    );
    tempCacheDir = await Directory.systemTemp.createTemp(
      'storage_clear_cache_test_',
    );
    tempSupportDir = await Directory.systemTemp.createTemp(
      'storage_clear_support_test_',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDocDir.path;
            }
            if (methodCall.method == 'getTemporaryDirectory') {
              return tempCacheDir.path;
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return tempSupportDir.path;
            }
            return null;
          },
        );

    isar = await Isar.open(
      [
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
        ViewingHistorySchema,
      ],
      directory: tempDocDir.path,
      name: 'storage_clear_test_db_${DateTime.now().microsecondsSinceEpoch}',
    );

    storageManager = LocalStorageManager();
    recoveryStore = StorageClearRecoveryStore(
      supportDirectory: () async => tempSupportDir,
    );
    service = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await isar.close(deleteFromDisk: true);
    if (await tempDocDir.exists()) {
      await tempDocDir.delete(recursive: true);
    }
    if (await tempCacheDir.exists()) {
      await tempCacheDir.delete(recursive: true);
    }
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  test(
    'clearStorage removes all files in storage directory and clears Isar database',
    () async {
      // 1. 専用ルートディレクトリの準備とファイル・サブディレクトリの作成
      final rootDir = await storageManager.getRootDirectory();
      final sampleFile = File(p.join(rootDir.path, 'test_image.png'));
      await sampleFile.writeAsString('sample image content');

      final subFolder = Directory(p.join(rootDir.path, 'SubFolder'));
      await subFolder.create();
      final subFile = File(p.join(subFolder.path, 'nested.txt'));
      await subFile.writeAsString('nested content');

      // キャッシュファイル作成
      final cacheFile = File(p.join(tempCacheDir.path, 'thumbnail.jpg'));
      await cacheFile.writeAsString('cache content');

      // 2. Isar DBにテストデータを挿入
      await isar.writeTxn(() async {
        final item = MediaItem()
          ..path = sampleFile.path
          ..size = 100
          ..addedAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isar.mediaItems.put(item);

        final col = MediaCollection()
          ..title = 'Test Collection'
          ..path = subFolder.path
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isar.mediaCollections.put(col);

        final tag = Tag()
          ..name = 'Test Tag'
          ..key = 'test_tag'
          ..facetId = 1
          ..level = 0
          ..colorValue = 0xFF0000FF
          ..createdAt = DateTime.now();
        await isar.tags.put(tag);
        await isar.viewingHistorys.put(
          ViewingHistory()
            ..itemUid = 'previous-file'
            ..openedAt = DateTime.now(),
        );
      });

      expect(await isar.mediaItems.count(), 1);
      expect(await isar.mediaCollections.count(), 1);
      expect(await isar.tags.count(), 1);
      expect(await isar.viewingHistorys.count(), 1);
      expect(await sampleFile.exists(), isTrue);
      expect(await subFile.exists(), isTrue);
      expect(await cacheFile.exists(), isTrue);

      // 3. ストレージ消去を実行
      final result = await service.clearStorage();

      // 4. 検証
      expect(result.isSuccess, isTrue);

      // ファイルが削除されていること
      expect(await sampleFile.exists(), isFalse);
      expect(await subFile.exists(), isFalse);
      expect(await subFolder.exists(), isFalse);
      expect(await cacheFile.exists(), isFalse);

      // DBがクリアされていること
      expect(await isar.mediaItems.count(), 0);
      expect(await isar.mediaCollections.count(), 0);
      expect(await isar.tags.count(), 0);
      expect(await isar.viewingHistorys.count(), 0);
      expect(await recoveryStore.isPending(), isFalse);

      // 専用ディレクトリとメタデータディレクトリが再生成されていること
      expect(await rootDir.exists(), isTrue);
      final metaDir = await storageManager.getMetadataDirectory();
      expect(await metaDir.exists(), isTrue);
    },
  );

  test('clearStorage respects cancellation token before starting', () async {
    final rootDir = await storageManager.getRootDirectory();
    final sampleFile = File(p.join(rootDir.path, 'keep_this_file.png'));
    await sampleFile.writeAsString('should remain');

    final cancellationToken = StorageClearCancellationToken();
    cancellationToken.cancel();

    final result = await service.clearStorage(
      cancellationToken: cancellationToken,
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorOrNull?.message, contains('中断'));
    expect(await sampleFile.exists(), isTrue);
    expect(await recoveryStore.isPending(), isFalse);
  });

  test('管理ファイルの削除失敗時もDBを空にして欠損参照を残さない', () async {
    final rootDir = await storageManager.getRootDirectory();
    final sampleFile = File(p.join(rootDir.path, 'cannot_delete.png'));
    await sampleFile.writeAsBytes([1, 2, 3]);
    await isar.writeTxn(() async {
      await isar.mediaItems.put(
        MediaItem()
          ..path = 'cannot_delete.png'
          ..size = 3
          ..addedAt = DateTime.now()
          ..updatedAt = DateTime.now(),
      );
    });
    var journalCleared = false;
    var preferencesCleared = false;
    final failingService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      deleteEntity: (entity) async {
        if (entity.path == sampleFile.path) {
          throw FileSystemException('削除を拒否', entity.path);
        }
        await entity.delete(recursive: entity is Directory);
      },
      clearOperationJournal: () async {
        journalCleared = true;
      },
      clearTransientPreferences: () async {
        preferencesCleared = true;
      },
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await failingService.clearStorage();

    expect(result.isFailure, isTrue);
    expect(await sampleFile.exists(), isTrue);
    expect(await isar.mediaItems.count(), 0);
    expect(journalCleared, isTrue);
    expect(preferencesCleared, isTrue);
    expect(await recoveryStore.isPending(), isTrue);

    final retryService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      temporaryDirectory: () async => tempCacheDir,
    );
    final recovered = await retryService.recoverPendingClear();

    expect(recovered.isSuccess, isTrue);
    expect(await sampleFile.exists(), isFalse);
    expect(await recoveryStore.isPending(), isFalse);
  });

  test('外部アクセス権の解放失敗時は内部消去を完了して次回再試行する', () async {
    final rootDir = await storageManager.getRootDirectory();
    final sampleFile = File(p.join(rootDir.path, 'keep.jpg'));
    await sampleFile.writeAsBytes([1, 2, 3]);
    await isar.writeTxn(() async {
      await isar.mediaItems.put(
        MediaItem()
          ..path = 'keep.jpg'
          ..size = 3
          ..addedAt = DateTime.now()
          ..updatedAt = DateTime.now(),
      );
    });
    final failingService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      releaseAllExternalAccess: () async => throw StateError('release failed'),
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await failingService.clearStorage();

    expect(result.isFailure, isTrue);
    expect(await sampleFile.exists(), isFalse);
    expect(await isar.mediaItems.count(), 0);
    expect(await recoveryStore.isPending(), isTrue);

    final newFile = File(p.join(rootDir.path, 'created-after-failure.jpg'));
    await newFile.writeAsBytes([4, 5, 6]);
    await isar.writeTxn(() async {
      await isar.mediaItems.put(
        MediaItem()
          ..path = 'created-after-failure.jpg'
          ..size = 3
          ..addedAt = DateTime.now()
          ..updatedAt = DateTime.now(),
      );
    });

    var retryReleaseCount = 0;
    final retryService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      releaseAllExternalAccess: () async {
        retryReleaseCount++;
      },
      temporaryDirectory: () async => tempCacheDir,
    );
    final recovered = await retryService.recoverPendingClear();

    expect(recovered.isSuccess, isTrue);
    expect(retryReleaseCount, 1);
    expect(await newFile.exists(), isTrue);
    expect(await isar.mediaItems.count(), 1);
    expect(await recoveryStore.isPending(), isFalse);
  });

  test('内部消去が失敗した場合は外部アクセス権を解放しない', () async {
    var accessReleased = false;
    final failingService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      clearOperationJournal: () async => throw StateError('journal failed'),
      releaseAllExternalAccess: () async {
        accessReleased = true;
      },
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await failingService.clearStorage();

    expect(result.isFailure, isTrue);
    expect(accessReleased, isFalse);
    expect(await recoveryStore.isPending(), isTrue);
  });

  test('復旧マーカーを保存できない場合はDBとファイルを変更しない', () async {
    final rootDir = await storageManager.getRootDirectory();
    final sampleFile = File(p.join(rootDir.path, 'keep.jpg'));
    await sampleFile.writeAsBytes([1, 2, 3]);
    await isar.writeTxn(() async {
      await isar.mediaItems.put(
        MediaItem()
          ..path = 'keep.jpg'
          ..size = 3
          ..addedAt = DateTime.now()
          ..updatedAt = DateTime.now(),
      );
    });
    var accessReleased = false;
    final failingService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: StorageClearRecoveryStore(
        supportDirectory: () async => throw StateError('marker failed'),
      ),
      releaseAllExternalAccess: () async {
        accessReleased = true;
      },
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await failingService.clearStorage();

    expect(result.isFailure, isTrue);
    expect(await sampleFile.exists(), isTrue);
    expect(await isar.mediaItems.count(), 1);
    expect(accessReleased, isFalse);
  });

  test('DB消去後はジャーナル・一時設定の消去を実行する', () async {
    var journalCleared = false;
    var preferencesCleared = false;
    var accessReleased = false;
    final coordinatedService = StorageClearService(
      isar,
      storageManager,
      recoveryStore: recoveryStore,
      releaseAllExternalAccess: () async {
        accessReleased = true;
      },
      clearOperationJournal: () async {
        journalCleared = true;
      },
      clearTransientPreferences: () async {
        preferencesCleared = true;
      },
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await coordinatedService.clearStorage();

    expect(result.isSuccess, isTrue);
    expect(accessReleased, isTrue);
    expect(journalCleared, isTrue);
    expect(preferencesCleared, isTrue);
  });

  test('Androidのストレージ消去は私有領域だけを消し公開の旧復元元を残す', () async {
    final privateRoot = Directory(p.join(tempDocDir.path, 'private'));
    final publicRoot = Directory(p.join(tempDocDir.path, 'public'));
    final privateFile = File(
      p.join(privateRoot.path, 'library', 'private.jpg'),
    );
    final publicFile = File(
      p.join(publicRoot.path, 'library', 'legacy-public.jpg'),
    );
    await privateFile.parent.create(recursive: true);
    await publicFile.parent.create(recursive: true);
    await privateFile.writeAsBytes([1, 2, 3]);
    await publicFile.writeAsBytes([4, 5, 6]);
    final androidStorage = LocalStorageManager(
      isAndroid: true,
      privateRootDirectory: privateRoot,
      androidPublicRootDirectory: publicRoot,
    );
    final androidService = StorageClearService(
      isar,
      androidStorage,
      recoveryStore: recoveryStore,
      temporaryDirectory: () async => tempCacheDir,
    );

    final result = await androidService.clearStorage();

    expect(result.isSuccess, isTrue);
    expect(await privateFile.exists(), isFalse);
    expect(await publicFile.readAsBytes(), [4, 5, 6]);
  });
}
