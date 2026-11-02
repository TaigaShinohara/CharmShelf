import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _Files extends Mock implements FileService {}

class _Journal extends Mock implements OperationJournalService {}

class _Entry extends Fake implements OperationJournalEntry {}

void main() {
  setUpAll(() => registerFallbackValue(_Entry()));
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar isar;
  late IsarMediaRepository repository;
  late _Files files;
  late _Journal journal;
  late MediaItem root;
  late MediaCollection collection;
  late RestoreTrashedMediaUseCase restore;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trash_restore_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: directory.path,
      name: 'trash_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = IsarMediaRepository(isar);
    files = _Files();
    journal = _Journal();
    when(() => journal.readAll()).thenAnswer((_) async => []);
    when(() => journal.write(any())).thenAnswer((_) async {});
    root = MediaItem()
      ..uid = 'trashed-file'
      ..path = 'library/qa.png'
      ..isTrashed = true
      ..isTrashRoot = true
      ..trashRootPath = 'library/qa.png'
      ..trashPath = '.trash/qa/qa.png';
    collection = MediaCollection()
      ..uid = 'trashed-catalog'
      ..path = root.path
      ..title = 'QA catalog'
      ..alias = 'Preserved alias'
      ..type = CollectionType.file
      ..isTrashed = true
      ..trashRootPath = root.path;
    await isar.writeTxn(() async {
      await isar.mediaItems.put(root);
      await isar.mediaCollections.put(collection);
      collection.items.add(root);
      await collection.items.save();
    });
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    when(() => journal.remove(any())).thenAnswer((_) async {});
    restore = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
  });
  tearDown(() async {
    await isar.close();
    await directory.delete(recursive: true);
  });

  test('実Isarのごみ箱内ファイルとカタログを自己競合なしで復元する', () async {
    final result = await restore.invoke(root);
    expect(result.isSuccess, isTrue, reason: '${result.errorOrNull}');
    final restoredItem = (await repository.getByPath(
      root.path,
      includeTrashed: false,
    )).dataOrNull;
    final restoredCollection = (await repository.getCollectionByPath(
      root.path,
      includeTrashed: false,
    )).dataOrNull;
    expect(restoredItem?.id, root.id);
    expect(restoredCollection?.alias, 'Preserved alias');
    expect(restoredCollection?.isTrashed, isFalse);
    verify(
      () => files.restoreStagedDeletion(root.trashPath!, root.path),
    ).called(1);
  });

  test('先に見つかるごみ箱内レコードが同じパスの有効ファイルを隠さない', () async {
    final active = MediaItem()
      ..uid = 'active-file'
      ..path = root.path;
    await isar.writeTxn(() async {
      await isar.mediaItems.put(active);
    });
    final result = await restore.invoke(root);
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.additionalData?['conflictingPaths'], [
      root.path,
    ]);
    verifyNever(() => files.restoreStagedDeletion(any(), any()));
  });

  test('別名で復元する先の有効カタログとの競合も拒否する', () async {
    final active = MediaCollection()
      ..uid = 'active-catalog'
      ..path = 'library/taken.png';
    await isar.writeTxn(() async {
      await isar.mediaCollections.put(active);
    });
    final result = await restore.invoke(root, newName: 'taken.png');
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.additionalData?['conflictingPaths'], [
      'library/taken.png',
    ]);
    verifyNever(() => files.restoreStagedDeletion(any(), any()));
  });
}
