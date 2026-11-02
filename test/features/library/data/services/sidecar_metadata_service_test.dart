import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;
  late LocalStorageManager storageManager;
  late SidecarMetadataService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sidecar_test_');

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
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDir.path,
      name: 'sidecar_test_db_${DateTime.now().microsecondsSinceEpoch}',
    );

    storageManager = LocalStorageManager();
    service = SidecarMetadataService(isar, storageManager);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SidecarMetadataService Tests', () {
    test('タグの階層関係（親・子・ancestorIds）がエクスポート&インポートで正しく復元される', () async {
      // 1. 親タグと子タグを作成
      final parentTag = Tag()
        ..key = 'facet1::Parent'
        ..name = 'Parent'
        ..facetId = 1;

      await isar.writeTxn(() async {
        await isar.tags.put(parentTag);
      });

      final childTag = Tag()
        ..key = 'facet1::Child'
        ..name = 'Child'
        ..facetId = 1
        ..parentId = parentTag.id
        ..ancestorIds = [parentTag.id];

      await isar.writeTxn(() async {
        await isar.tags.put(childTag);
      });

      // 2. メタデータをエクスポート
      final exportResult = await service.exportMetadata();
      expect(exportResult.isSuccess, isTrue);

      // JSONファイルの内容を検証
      final metaFile = await storageManager.getMetadataFile();
      expect(await metaFile.exists(), isTrue);
      final jsonMap =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      expect(jsonMap['version'], equals(2));
      final tagsJson = jsonMap['tags'] as List<dynamic>;
      final childJson =
          tagsJson.firstWhere((t) => t['key'] == 'facet1::Child')
              as Map<String, dynamic>;
      expect(childJson['parentKey'], equals('facet1::Parent'));

      // 3. DBをクリア（IDをリセット）
      await isar.writeTxn(() async {
        await isar.tags.clear();
      });
      expect(await isar.tags.count(), equals(0));

      // 4. メタデータをインポート
      final importResult = await service.importMetadata();
      expect(importResult.isSuccess, isTrue);
      expect(importResult.dataOrNull, equals(2));

      // 5. 復元されたタグの親子関係を確認
      final restoredParent = await isar.tags
          .where()
          .keyEqualTo('facet1::Parent')
          .findFirst();
      final restoredChild = await isar.tags
          .where()
          .keyEqualTo('facet1::Child')
          .findFirst();

      expect(restoredParent, isNotNull);
      expect(restoredChild, isNotNull);
      expect(restoredChild!.parentId, equals(restoredParent!.id));
      expect(restoredChild.ancestorIds, equals([restoredParent.id]));
    });

    test('MediaCollectionの全属性およびタグ関連付けが完全に復元・マージされる', () async {
      final rootDir = await storageManager.getRootDirectory();
      Directory(
        p.join(rootDir.path, 'folders/test_col'),
      ).createSync(recursive: true);
      File(p.join(rootDir.path, 'covers/test.jpg')).createSync(recursive: true);

      final tag = Tag()
        ..key = 'facet1::SampleTag'
        ..name = 'SampleTag';

      final col = MediaCollection()
        ..uid = 'col-123'
        ..title = 'Test Collection'
        ..alias = 'Renamed Collection'
        ..path = 'folders/test_col'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..tier = 4
        ..isFavorite = true
        ..isPinned = true
        ..isArchived = false
        ..isHidden = false
        ..coverImagePath = 'covers/test.jpg'
        ..defaultSortOrder = SortOrder.nameAsc
        ..defaultViewMode = ViewMode.grid
        ..notes = 'Important note';

      await isar.writeTxn(() async {
        await isar.tags.put(tag);
        await isar.mediaCollections.put(col);
        col.tags.add(tag);
        await col.tags.save();
      });

      // エクスポート
      final exportResult = await service.exportMetadata();
      expect(exportResult.isSuccess, isTrue);

      // DBをクリア
      await isar.writeTxn(() async {
        await isar.tags.clear();
        await isar.mediaCollections.clear();
      });

      // インポート
      final importResult = await service.importMetadata();
      expect(importResult.isSuccess, isTrue);

      // 検証
      final restoredCol = await isar.mediaCollections
          .where()
          .pathEqualTo('folders/test_col')
          .findFirst();
      expect(restoredCol, isNotNull);
      expect(restoredCol!.title, equals('Test Collection'));
      expect(restoredCol.alias, equals('Renamed Collection'));
      expect(restoredCol.isCatalog, isTrue);
      expect(restoredCol.tier, equals(4));
      expect(restoredCol.isFavorite, isTrue);
      expect(restoredCol.isPinned, isTrue);
      expect(restoredCol.coverImagePath, equals('covers/test.jpg'));
      expect(restoredCol.defaultSortOrder, equals(SortOrder.nameAsc));
      expect(restoredCol.defaultViewMode, equals(ViewMode.grid));
      expect(restoredCol.notes, equals('Important note'));

      await restoredCol.tags.load();
      expect(restoredCol.tags.length, equals(1));
      expect(restoredCol.tags.first.key, equals('facet1::SampleTag'));

      // Unregistering changes the stored boolean, without re-inferring a type
      // from the cover, rank, or file format on the next import.
      restoredCol.isCatalog = false;
      await isar.writeTxn(() => isar.mediaCollections.put(restoredCol));
      expect((await service.exportMetadata()).isSuccess, isTrue);
      final metadataFile = await storageManager.getMetadataFile();
      final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
      final exportedCollection =
          (metadata['collections'] as List).single as Map;
      expect(exportedCollection['isCatalog'], isFalse);
      expect(exportedCollection.containsKey('genre'), isFalse);
      await isar.writeTxn(() => isar.mediaCollections.clear());
      expect((await service.importMetadata()).isSuccess, isTrue);
      final unregistered = await isar.mediaCollections
          .where()
          .pathEqualTo('folders/test_col')
          .findFirst();
      expect(unregistered!.isCatalog, isFalse);
      expect(unregistered.tier, 4);
    });

    test('metadata.json破損時に .bak から自動フォールバック復元できる', () async {
      final tag = Tag()
        ..key = 'facet1::FallbackTag'
        ..name = 'FallbackTag';

      await isar.writeTxn(() async {
        await isar.tags.put(tag);
      });

      // 1回目のエクスポート（.bak作成用）
      await service.exportMetadata();
      // 2回目のエクスポート（.bakに有効なデータが入る）
      await service.exportMetadata();

      final metaFile = await storageManager.getMetadataFile();
      final bakFile = File('${metaFile.path}.bak');
      expect(await bakFile.exists(), isTrue);

      // metadata.json を不正な文字列で破壊
      await metaFile.writeAsString('{{INVALID JSON');

      // DBクリア
      await isar.writeTxn(() async {
        await isar.tags.clear();
      });

      // インポート実行
      final importResult = await service.importMetadata();
      expect(importResult.isSuccess, isTrue);

      // .bak から正常に復元されていることを確認
      final restoredTag = await isar.tags
          .where()
          .keyEqualTo('facet1::FallbackTag')
          .findFirst();
      expect(restoredTag, isNotNull);
    });

    test('スキーマ v1 形式のJSONファイルから後方互換性を持ってインポートできる', () async {
      final rootDir = await storageManager.getRootDirectory();
      Directory(
        p.join(rootDir.path, 'folders/v1_col'),
      ).createSync(recursive: true);

      final v1Json = {
        'version': 1,
        'tags': [
          {
            'key': 'facet1::V1Parent',
            'name': 'V1Parent',
            'facetId': 1,
            'parentId': null,
          },
        ],
        'collections': [
          {
            'title': 'V1 Collection',
            'relativePath': 'folders/v1_col',
            'isCatalog': true,
            'type': 'folder',
            'tier': 2,
            'isFavorite': true,
            'tagKeys': ['facet1::V1Parent'],
          },
        ],
        'mediaItems': [],
      };

      final metaFile = await storageManager.getMetadataFile();
      if (!await metaFile.parent.exists()) {
        await metaFile.parent.create(recursive: true);
      }
      await metaFile.writeAsString(jsonEncode(v1Json));

      final importResult = await service.importMetadata();
      expect(importResult.isSuccess, isTrue);

      final col = await isar.mediaCollections
          .where()
          .pathEqualTo('folders/v1_col')
          .findFirst();
      expect(col, isNotNull);
      expect(col!.title, equals('V1 Collection'));
      expect(col.isFavorite, isTrue);

      await col.tags.load();
      expect(col.tags.length, equals(1));
      expect(col.tags.first.key, equals('facet1::V1Parent'));
    });

    test('library パスのコレクションはエクスポートおよびインポートから除外される', () async {
      final col = MediaCollection()
        ..title = 'library'
        ..path = 'library'
        ..isCatalog = true
        ..type = CollectionType.folder;

      await isar.writeTxn(() async {
        await isar.mediaCollections.put(col);
      });

      final exportResult = await service.exportMetadata();
      expect(exportResult.isSuccess, isTrue);

      final metaFile = await storageManager.getMetadataFile();
      final jsonMap =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final collections = (jsonMap['collections'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(collections.any((c) => c['relativePath'] == 'library'), isFalse);
    });

    test('Android旧公開メタデータは検証後に私有領域へ移行し公開コピーを削除する', () async {
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      storageManager = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      service = SidecarMetadataService(isar, storageManager);
      await storageManager.getRootDirectory();
      final legacyFile = File(
        p.join(
          publicRoot.path,
          LocalStorageManager.sidecarMetaDirName,
          LocalStorageManager.metadataFileName,
        ),
      );
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': [
            {'key': 'legacy::tag', 'name': 'Legacy'},
          ],
          'collections': <Object>[],
          'mediaItems': <Object>[],
        }),
      );

      final result = await service.importMetadata(includeLegacy: true);

      expect(result.isSuccess, isTrue);
      final privateMetadata = await storageManager.getMetadataFile();
      expect(await privateMetadata.exists(), isTrue);
      expect(await legacyFile.exists(), isFalse);
      expect(await legacyFile.parent.exists(), isFalse);
      expect(
        await isar.tags.where().keyEqualTo('legacy::tag').findFirst(),
        isNotNull,
      );
    });

    test('旧公開メタデータ削除が途中失敗してもマーカーから次回再開できる', () async {
      final privateRoot = Directory(p.join(tempDir.path, 'private-retry'));
      final publicRoot = Directory(p.join(tempDir.path, 'public-retry'));
      storageManager = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      await storageManager.getRootDirectory();
      final legacyFile = File(
        p.join(
          publicRoot.path,
          LocalStorageManager.sidecarMetaDirName,
          LocalStorageManager.metadataFileName,
        ),
      );
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': [
            {'key': 'legacy::retry', 'name': 'Retry'},
          ],
          'collections': <Object>[],
          'mediaItems': <Object>[],
        }),
      );
      var failedOnce = false;
      service = SidecarMetadataService(
        isar,
        storageManager,
        deleteFile: (file) async {
          if (file.path == legacyFile.path && !failedOnce) {
            failedOnce = true;
            throw FileSystemException('一時的な削除失敗', file.path);
          }
          await file.delete();
        },
      );

      final first = await service.importMetadata(includeLegacy: true);

      final marker = File(
        p.join(
          privateRoot.path,
          LocalStorageManager.sidecarMetaDirName,
          SidecarMetadataService.legacyMigrationMarkerName,
        ),
      );
      expect(first.isFailure, isTrue);
      expect(await legacyFile.exists(), isTrue);
      expect(await marker.exists(), isTrue);
      expect(
        await storageManager.getMetadataFile().then((f) => f.exists()),
        isTrue,
      );

      final second = await service.importMetadata(includeLegacy: true);

      expect(second.isSuccess, isTrue);
      expect(await legacyFile.exists(), isFalse);
      expect(await marker.exists(), isFalse);
      expect(
        await isar.tags.where().keyEqualTo('legacy::retry').findFirst(),
        isNotNull,
      );
    });

    test('ルート外を指すsidecarパスをDBへ反映せず拒否する', () async {
      final rootDir = await storageManager.getPrivateRootDirectory();
      final outside = Directory(
        p.normalize(p.join(rootDir.path, '..', 'outside')),
      );
      await outside.create(recursive: true);
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': <Object>[],
          'collections': [
            {
              'title': 'Unsafe',
              'relativePath': '../outside',
              'coverImagePath': '../outside/cover.jpg',
            },
          ],
          'mediaItems': <Object>[],
        }),
      );

      final result = await service.importMetadata();

      expect(result.isFailure, isTrue);
      expect(await isar.mediaCollections.count(), 0);
    });

    test('管理用ディレクトリを通常コレクションとして復元しない', () async {
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': <Object>[],
          'collections': [
            {'title': 'Internal', 'relativePath': '.tagshelf/internal'},
          ],
          'mediaItems': <Object>[],
        }),
      );

      final result = await service.importMetadata();

      expect(result.isFailure, isTrue);
      expect(await isar.mediaCollections.count(), 0);
    });

    test('旧版が記録した安全な管理領域外パスは無視して有効なメタデータを復元する', () async {
      final rootDir = await storageManager.getPrivateRootDirectory();
      await Directory(
        p.join(rootDir.path, 'library', 'Valid'),
      ).create(recursive: true);
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': [
            {'key': 'valid::tag', 'name': 'Valid'},
          ],
          'collections': [
            {'title': 'Old bug', 'relativePath': 'migration_check'},
            {'title': 'Valid', 'relativePath': 'library/Valid'},
          ],
          'mediaItems': [
            {'relativePath': 'migration_check/photo.jpg', 'isHidden': true},
          ],
        }),
      );

      final result = await service.importMetadata();

      expect(result.isSuccess, isTrue);
      expect(
        await isar.mediaCollections
            .where()
            .pathEqualTo('library/Valid')
            .count(),
        1,
      );
      expect(
        await isar.mediaCollections
            .where()
            .pathEqualTo('migration_check')
            .count(),
        0,
      );
      expect(await isar.tags.where().keyEqualTo('valid::tag').count(), 1);
    });

    test('過大なsidecarとレコード上限超過を読込前に拒否する', () async {
      final metaFile = await storageManager.getMetadataFile();
      await metaFile.parent.create(recursive: true);
      final limited = SidecarMetadataService(
        isar,
        storageManager,
        maxMetadataBytes: 128,
        maxRecordsPerType: 1,
      );
      await metaFile.writeAsString(List.filled(129, 'x').join());
      expect((await limited.importMetadata()).isFailure, isTrue);

      await metaFile.writeAsString(
        jsonEncode({
          'version': 2,
          'tags': [
            {'key': 'one', 'name': 'One'},
            {'key': 'two', 'name': 'Two'},
          ],
          'collections': <Object>[],
          'mediaItems': <Object>[],
        }),
      );
      final recordLimited = SidecarMetadataService(
        isar,
        storageManager,
        maxMetadataBytes: 1024,
        maxRecordsPerType: 1,
      );
      expect((await recordLimited.importMetadata()).isFailure, isTrue);
    });
  });
}
