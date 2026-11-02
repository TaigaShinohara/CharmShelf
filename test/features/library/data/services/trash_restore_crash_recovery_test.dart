import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Journal extends OperationJournalService {
  String? crash;
  @override
  Future<void> write(OperationJournalEntry entry) async {
    await super.write(entry);
    if (crash == 'intent' && entry.payload.containsKey('restoreTargetPath')) {
      throw StateError('復元意図の保存直後に終了');
    }
  }

  @override
  Future<void> remove(String id) async {
    if (crash == 'cleanup') throw StateError('ジャーナル清掃直前に終了');
    await super.remove(id);
  }
}

class _Files extends FileService {
  bool crashAfterMove = false;
  @override
  Future<Result<void, AppError>> restoreStagedDeletion(
    String trash,
    String target,
  ) async {
    final result = await super.restoreStagedDeletion(trash, target);
    if (result.isSuccess && crashAfterMove) throw StateError('物理移動直後に終了');
    return result;
  }
}

class _Repository extends IsarMediaRepository {
  _Repository(super.isar);
  String? crash;
  @override
  Future<Result<void, AppError>> restoreGraphFromTrash(
    String rootPath, {
    String? targetRootPath,
    String? targetParentPath,
  }) async {
    if (crash == 'beforeDB') throw StateError('DB更新直前に終了');
    final result = await super.restoreGraphFromTrash(
      rootPath,
      targetRootPath: targetRootPath,
      targetParentPath: targetParentPath,
    );
    if (crash == 'afterDB' && result.isSuccess) throw StateError('DB更新直後に終了');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar isar;
  late _Repository repository;
  late _Journal journal;
  late _Files files;
  late MediaItem root;
  late MediaItem child;
  late MediaCollection collection;
  late String digest;
  late PathProviderPlatform oldPaths;
  const original = 'library/album';
  const trash = '.trash/deletion/album';
  const target = 'library/renamed';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'tagshelf_restore_crash_',
    );
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    PrivateStorageService.resetForTesting();
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: directory.path,
      name: 'restore_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = _Repository(isar);
    journal = _Journal();
    files = _Files();
    await Directory('${directory.path}/$original').create(recursive: true);
    final file = await File(
      '${directory.path}/$original/photo.jpg',
    ).writeAsBytes(List.generate(1024, (i) => i % 256));
    digest = sha256.convert(await file.readAsBytes()).toString();
    root = MediaItem()
      ..uid = 'root'
      ..path = original
      ..type = MediaType.folder;
    child = MediaItem()
      ..uid = 'child'
      ..path = '$original/photo.jpg'
      ..parentPath = original;
    collection = MediaCollection()
      ..uid = 'album'
      ..path = original
      ..title = '作品'
      ..alias = '保持する名前'
      ..coverImagePath = child.path;
    expect((await repository.save(root)).isSuccess, isTrue);
    expect((await repository.save(child)).isSuccess, isTrue);
    expect((await repository.saveCollection(collection)).isSuccess, isTrue);
    final tag = Tag()
      ..name = '保持するタグ'
      ..key = 'tag';
    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      collection.tags.add(tag);
      await collection.tags.save();
      collection.items.add(child);
      await collection.items.save();
    });
    expect((await files.stageDeletion(original, trash)).isSuccess, isTrue);
    expect(
      (await repository.moveGraphToTrash(
        [root.id, child.id],
        [collection.id],
        rootItemId: root.id,
        trashPath: trash,
        trashedAt: DateTime.now(),
      )).isSuccess,
      isTrue,
    );
    root = (await repository.getById(root.id)).dataOrNull!;
    await journal.write(
      OperationJournalEntry(
        id: 'deletion',
        kind: OperationKind.delete,
        stage: OperationStage.committed,
        payload: {
          'rootItemId': root.id,
          'originalPath': original,
          'trashPath': trash,
          'isLocal': true,
        },
      ),
    );
  });
  tearDown(() async {
    await isar.close();
    PathProviderPlatform.instance = oldPaths;
    PrivateStorageService.resetForTesting();
    await directory.delete(recursive: true);
  });

  for (final crash in ['intent', 'move', 'beforeDB', 'afterDB', 'cleanup']) {
    test('別名復元の$crash中断から実ファイル・タグ・子孫を保持して再開', () async {
      journal.crash = crash;
      files.crashAfterMove = crash == 'move';
      repository.crash = crash;
      final useCase = RestoreTrashedMediaUseCase(
        files,
        Future.value(repository),
        journal,
      );
      final result = await useCase.invoke(root, newName: 'renamed');
      expect(result.isSuccess, crash == 'cleanup');
      journal.crash = null;
      files.crashAfterMove = false;
      repository.crash = null;
      // プロセス内のオブジェクトを使わずDBを閉じて開き直す。
      final name = isar.name;
      await isar.close();
      isar = await Isar.open(
        [
          MediaCollectionSchema,
          MediaItemSchema,
          TagSchema,
          TagFacetSchema,
          StorageRefSchema,
        ],
        directory: directory.path,
        name: name,
      );
      repository = _Repository(isar);
      final recovered = await OperationRecoveryService(
        journal,
        files,
        repository,
      ).recover();
      expect(recovered.isSuccess, isTrue, reason: '${recovered.errorOrNull}');
      if (crash == 'intent') {
        final stillTrashed = (await repository.getById(root.id)).dataOrNull!;
        expect(stillTrashed.isTrashed, isTrue);
        expect(
          (await RestoreTrashedMediaUseCase(
            files,
            Future.value(repository),
            journal,
          ).invoke(stillTrashed, newName: 'renamed')).isSuccess,
          isTrue,
        );
      }
      final restoredRoot = (await repository.getById(root.id)).dataOrNull!;
      final restoredChild = (await repository.getById(child.id)).dataOrNull!;
      final restoredCollection = (await repository.getCollectionById(
        collection.id,
      )).dataOrNull!;
      expect(restoredRoot.path, target);
      expect(restoredRoot.isTrashed, isFalse);
      expect(restoredChild.path, '$target/photo.jpg');
      expect(restoredChild.parentPath, target);
      expect(restoredCollection.path, target);
      expect(restoredCollection.coverImagePath, '$target/photo.jpg');
      expect(restoredCollection.alias, '保持する名前');
      await restoredCollection.tags.load();
      expect(restoredCollection.tags.single.name, '保持するタグ');
      final bytes = await File(
        '${directory.path}/$target/photo.jpg',
      ).readAsBytes();
      expect(sha256.convert(bytes).toString(), digest);
      expect(await Directory('${directory.path}/$trash').exists(), isFalse);
      expect(await journal.readAll(), isEmpty);
      final refs = await isar.storageRefs.where().findAll();
      expect(
        refs.where((ref) => ref.ownerUid == 'child').single.locator,
        '$target/photo.jpg',
      );
      expect(
        (await OperationRecoveryService(
          journal,
          files,
          repository,
        ).recover()).isSuccess,
        isTrue,
      );
    });
  }

  test('復元先に別のごみ箱カタログがあっても置換せずロールバックする', () async {
    final other = MediaCollection()
      ..uid = 'other'
      ..path = target
      ..isTrashed = true
      ..trashRootPath = target
      ..alias = '消してはいけない';
    expect((await repository.saveCollection(other)).isSuccess, isTrue);
    final result = await RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    ).invoke(root, newName: 'renamed');
    expect(result.isFailure, isTrue);
    expect(
      (await repository.getCollectionById(other.id)).dataOrNull?.alias,
      '消してはいけない',
    );
    expect(await File('${directory.path}/$trash/photo.jpg').exists(), isTrue);
    expect((await repository.getById(root.id)).dataOrNull?.isTrashed, isTrue);
  });

  test('DB未登録の実体と衝突しても別名で再試行できる', () async {
    final occupied = File('${directory.path}/$target');
    await occupied.writeAsString('既存ファイル');
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    expect((await useCase.invoke(root, newName: 'renamed')).isFailure, isTrue);
    expect(
      (await useCase.invoke(root, newName: 'different')).isSuccess,
      isTrue,
    );
    expect(await occupied.readAsString(), '既存ファイル');
    expect(
      sha256
          .convert(
            await File(
              '${directory.path}/library/different/photo.jpg',
            ).readAsBytes(),
          )
          .toString(),
      digest,
    );
    expect(await journal.readAll(), isEmpty);
  });

  test('同一起動中の再試行でも復元先の記録を失わない', () async {
    files.crashAfterMove = true;
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    expect((await useCase.invoke(root, newName: 'renamed')).isFailure, isTrue);
    files.crashAfterMove = false;
    expect(
      (await useCase.invoke(root, newName: 'different')).isSuccess,
      isTrue,
    );
    expect((await repository.getById(root.id)).dataOrNull?.path, target);
    expect(await journal.readAll(), isEmpty);
  });
}
