import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class MockJournal extends Mock implements OperationJournalService {}

class MockFiles extends Mock implements FileService {}

class MockRepository extends Mock implements MediaRepository {}

void main() {
  late MockJournal journal;
  late MockFiles files;
  late MockRepository repository;
  late OperationRecoveryService service;

  setUp(() {
    journal = MockJournal();
    files = MockFiles();
    repository = MockRepository();
    service = OperationRecoveryService(journal, files, repository);
    when(() => journal.remove(any())).thenAnswer((_) async {});
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => files.listTrashStagingEntries(),
    ).thenAnswer((_) async => Result.success([]));
  });

  void stubJournal(
    List<OperationJournalEntry> entries, {
    Set<String> quarantinedOperationIds = const {},
  }) {
    when(() => journal.readReport()).thenAnswer(
      (_) async => OperationJournalReadReport(
        entries: entries,
        quarantinedOperationIds: quarantinedOperationIds,
      ),
    );
  }

  OperationJournalEntry deletion() => const OperationJournalEntry(
    id: 'delete-1',
    kind: OperationKind.delete,
    stage: OperationStage.staged,
    payload: {
      'rootItemId': 1,
      'originalPath': 'library/a.jpg',
      'trashPath': '.trash/delete-1/a.jpg',
      'isLocal': true,
    },
  );

  OperationJournalEntry move() => const OperationJournalEntry(
    id: 'move-1',
    kind: OperationKind.move,
    stage: OperationStage.staged,
    payload: {
      'rootItemId': 2,
      'oldPath': 'library/a.jpg',
      'newPath': 'library/folder/a.jpg',
      'newParentPath': 'library/folder',
      'newTitle': null,
      'isLocal': true,
    },
  );

  OperationJournalEntry duplicate() => const OperationJournalEntry(
    id: 'duplicate-1',
    kind: OperationKind.duplicate,
    stage: OperationStage.staged,
    payload: {'rootPath': 'library/a_copy.jpg'},
  );

  test('破損ジャーナルがある間は孤立退避物を清掃しない', () async {
    stubJournal(const [], quarantinedOperationIds: const {'corrupt-delete'});
    when(() => files.listTrashStagingEntries()).thenAnswer(
      (_) async => Result.success([
        TrashStagingEntry(
          operationId: 'corrupt-delete',
          modifiedAt: DateTime(2020),
        ),
        TrashStagingEntry(
          operationId: 'unrelated-orphan',
          modifiedAt: DateTime(2020),
        ),
      ]),
    );
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => files.deleteFile('.trash/corrupt-delete'));
    verifyNever(() => files.deleteFile('.trash/unrelated-orphan'));
  });

  test('DBに項目が残る退避済み削除は元の場所へ復元する', () async {
    final entry = deletion();
    final item = MediaItem()..id = 1;
    stubJournal([entry]);
    when(
      () => repository.getById(1),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists('.trash/delete-1/a.jpg'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(
      () =>
          files.restoreStagedDeletion('.trash/delete-1/a.jpg', 'library/a.jpg'),
    ).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('DB削除済みの退避物は消去する', () async {
    final entry = deletion();
    stubJournal([entry]);
    when(
      () => repository.getById(1),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => files.deleteFile('.trash/delete-1/a.jpg')).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('完全削除中断後はジャーナルに記録したサムネイルも清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'delete-cleanup',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 7,
        'originalPath': 'library/a.jpg',
        'trashPath': '.trash/delete-cleanup/a.jpg',
        'isLocal': true,
        'cleanupPaths': ['.thumbnails/a.jpg'],
      },
    );
    stubJournal([entry]);
    when(
      () => repository.getById(7),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => files.deleteFile('.trash/delete-cleanup/a.jpg')).called(1);
    verify(() => files.deleteFile('.thumbnails/a.jpg')).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('外部参照の完全削除後は永続アクセスを解放する', () async {
    const sourceUri = 'file:///external/a.jpg';
    const entry = OperationJournalEntry(
      id: 'delete-external',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 8,
        'originalPath': sourceUri,
        'trashPath': '',
        'isLocal': false,
        'cleanupPaths': <String>[],
      },
    );
    final released = <Uri>[];
    service = OperationRecoveryService(
      journal,
      files,
      repository,
      releaseExternalAccess: (uri) async => released.add(uri),
    );
    stubJournal([entry]);
    when(
      () => repository.getById(8),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getByPath(sourceUri),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    expect(released, [Uri.parse(sourceUri)]);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('外部参照の権限解放に失敗した場合は再試行用ジャーナルを残す', () async {
    const sourceUri = 'file:///external/a.jpg';
    const entry = OperationJournalEntry(
      id: 'delete-external-failed',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 9,
        'originalPath': sourceUri,
        'trashPath': '',
        'isLocal': false,
        'cleanupPaths': <String>[],
      },
    );
    service = OperationRecoveryService(
      journal,
      files,
      repository,
      releaseExternalAccess: (_) async => throw StateError('release failed'),
    );
    stubJournal([entry]);
    when(
      () => repository.getById(9),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getByPath(sourceUri),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => journal.remove(entry.id));
  });

  for (final scenario in [
    'missing',
    'original-present',
    'path-mismatch',
    'io-error',
  ]) {
    test('欠損保留は完了記録が整合する場合だけ許可する: $scenario', () async {
      service = OperationRecoveryService(
        journal,
        files,
        repository,
        allowMissingCommittedTrash: true,
      );
      const entry = OperationJournalEntry(
        id: 'missing',
        kind: OperationKind.delete,
        stage: OperationStage.committed,
        payload: {
          'rootItemId': 3,
          'originalPath': 'library/a.jpg',
          'trashPath': '.trash/missing/a.jpg',
          'isLocal': true,
        },
      );
      final item = MediaItem()
        ..id = 3
        ..path = 'library/a.jpg'
        ..isTrashed = true
        ..isTrashRoot = true
        ..trashRootPath = 'library/a.jpg'
        ..trashPath = scenario == 'path-mismatch'
            ? '.trash/other/a.jpg'
            : '.trash/missing/a.jpg';
      stubJournal([entry]);
      when(
        () => repository.getById(3),
      ).thenAnswer((_) async => Result.success(item));
      when(() => files.managedEntityExists(any())).thenAnswer((call) async {
        if (scenario == 'io-error') {
          return Result.failure(AppError.file('read failure'));
        }
        return Result.success(
          scenario == 'original-present' &&
              call.positionalArguments.first == 'library/a.jpg',
        );
      });
      final result = await service.recover();
      expect(result.isSuccess, scenario == 'missing');
      expect(service.missingCommittedTrashCount, scenario == 'missing' ? 1 : 0);
      verifyNever(() => journal.remove(any()));
      verifyNever(() => files.deleteFile(any()));
      verifyNever(() => files.restoreStagedDeletion(any(), any()));
    });
  }

  test('コミット済みごみ箱項目は実体とジャーナルを保持する', () async {
    const entry = OperationJournalEntry(
      id: 'delete-committed',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 3,
        'originalPath': 'library/a.jpg',
        'trashPath': '.trash/delete-committed/a.jpg',
        'isLocal': true,
      },
    );
    final item = MediaItem()
      ..id = 3
      ..isTrashed = true
      ..trashPath = '.trash/delete-committed/a.jpg';
    stubJournal([entry]);
    when(
      () => repository.getById(3),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists('.trash/delete-committed/a.jpg'),
    ).thenAnswer((_) async => Result.success(true));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verifyNever(() => files.deleteFile(any()));
    verifyNever(() => files.restoreStagedDeletion(any(), any()));
    verifyNever(() => journal.remove(any()));
  });

  test('復元完了後に残ったローカル削除ジャーナルだけを清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'delete-restored',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 8,
        'originalPath': 'library/restored.jpg',
        'trashPath': '.trash/delete-restored/restored.jpg',
        'isLocal': true,
      },
    );
    final item = MediaItem()
      ..id = 8
      ..path = 'library/restored.jpg'
      ..isTrashed = false;
    stubJournal([entry]);
    when(
      () => repository.getById(8),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists('library/restored.jpg'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.managedEntityExists('.trash/delete-restored/restored.jpg'),
    ).thenAnswer((_) async => Result.success(false));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => journal.remove(entry.id)).called(1);
    verifyNever(() => files.deleteFile(any()));
  });

  test('復元完了後に残った外部参照ジャーナルだけを清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'external-restored',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 9,
        'originalPath': 'content://provider/restored',
        'trashPath': '.trash/external-restored/restored',
        'isLocal': false,
      },
    );
    final item = MediaItem()
      ..id = 9
      ..sourceType = MediaSourceType.externalReference
      ..isTrashed = false;
    stubJournal([entry]);
    when(
      () => repository.getById(9),
    ).thenAnswer((_) async => Result.success(item));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => journal.remove(entry.id)).called(1);
    verifyNever(() => files.managedEntityExists(any()));
  });

  test('復元済みDBに元実体と退避実体が併存する曖昧状態は自動変更しない', () async {
    const entry = OperationJournalEntry(
      id: 'delete-ambiguous',
      kind: OperationKind.delete,
      stage: OperationStage.committed,
      payload: {
        'rootItemId': 10,
        'originalPath': 'library/a.jpg',
        'trashPath': '.trash/delete-ambiguous/a.jpg',
        'isLocal': true,
      },
    );
    final item = MediaItem()
      ..id = 10
      ..isTrashed = false;
    stubJournal([entry]);
    when(
      () => repository.getById(10),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => journal.remove(any()));
    verifyNever(() => files.deleteFile(any()));
  });

  test('移行記録が保護する古いごみ箱コピーは清掃しない', () async {
    final now = DateTime(2026, 7, 15, 12);
    service = OperationRecoveryService(
      journal,
      files,
      repository,
      now: () => now,
      additionalProtectedTrashIds: () async => {'migration'},
    );
    stubJournal([]);
    when(() => files.listTrashStagingEntries()).thenAnswer(
      (_) async => Result.success([
        TrashStagingEntry(
          operationId: 'migration',
          modifiedAt: now.subtract(const Duration(days: 3)),
        ),
      ]),
    );
    expect((await service.recover()).isSuccess, isTrue);
    verifyNever(() => files.deleteFile(any()));
  });

  test('DBとジャーナルから孤立して24時間を超えた退避物を清掃する', () async {
    final now = DateTime(2026, 7, 15, 12);
    service = OperationRecoveryService(
      journal,
      files,
      repository,
      now: () => now,
    );
    stubJournal([]);
    when(() => files.listTrashStagingEntries()).thenAnswer(
      (_) async => Result.success([
        TrashStagingEntry(
          operationId: 'orphan',
          modifiedAt: now.subtract(const Duration(hours: 25)),
        ),
      ]),
    );
    when(
      () => files.deleteFile('.trash/orphan'),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => files.deleteFile('.trash/orphan')).called(1);
  });

  test('新しい退避物とDB参照中の退避物は孤立清掃から保護する', () async {
    final now = DateTime(2026, 7, 15, 12);
    service = OperationRecoveryService(
      journal,
      files,
      repository,
      now: () => now,
    );
    final root = MediaItem()
      ..isTrashed = true
      ..isTrashRoot = true
      ..trashPath = '.trash/protected/a.jpg';
    stubJournal([]);
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([root]));
    when(() => files.listTrashStagingEntries()).thenAnswer(
      (_) async => Result.success([
        TrashStagingEntry(
          operationId: 'protected',
          modifiedAt: now.subtract(const Duration(days: 10)),
        ),
        TrashStagingEntry(
          operationId: 'recent',
          modifiedAt: now.subtract(const Duration(hours: 1)),
        ),
      ]),
    );

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verifyNever(() => files.deleteFile('.trash/protected'));
    verifyNever(() => files.deleteFile('.trash/recent'));
  });

  test('DB未登録の中断インポートをサムネイルごと清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'import-1',
      kind: OperationKind.import,
      stage: OperationStage.staged,
      payload: {'path': 'library/a.jpg', 'thumbnailPath': '.thumbnails/a.jpg'},
    );
    stubJournal([entry]);
    when(
      () => repository.getByPath('library/a.jpg'),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => files.deleteFile('library/a.jpg')).called(1);
    verify(() => files.deleteFile('.thumbnails/a.jpg')).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('DB巻戻し失敗後の再起動では登録済み実体を削除しない', () async {
    const entry = OperationJournalEntry(
      id: 'import-rollback-failed',
      kind: OperationKind.import,
      stage: OperationStage.staged,
      payload: {'path': 'library/a.jpg', 'thumbnailPath': '.thumbnails/a.jpg'},
    );
    stubJournal([entry]);
    final item = MediaItem()..path = 'library/a.jpg';
    when(
      () => repository.getByPath(item.path),
    ).thenAnswer((_) async => Result.success(item));
    final result = await service.recover();
    expect(result.isSuccess, isTrue);
    verifyNever(() => files.deleteFile(any()));
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('復旧清掃に失敗したジャーナルは残して失敗を返す', () async {
    final entry = deletion();
    stubJournal([entry]);
    when(
      () => repository.getById(1),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.failure(AppError.file('busy')));

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => journal.remove(any()));
  });

  test('物理移動後かつDB更新前の中断は実体を旧パスへ戻す', () async {
    final entry = move();
    final item = MediaItem()
      ..id = 2
      ..path = 'library/a.jpg';
    stubJournal([entry]);
    when(
      () => repository.getById(2),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists('library/a.jpg'),
    ).thenAnswer((_) async => Result.success(false));
    when(
      () => files.managedEntityExists('library/folder/a.jpg'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.moveEntity(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(
      () => files.moveEntity('library/folder/a.jpg', 'library/a.jpg'),
    ).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('DB更新後の中断は未更新の子孫を前進復旧する', () async {
    final entry = move();
    final item = MediaItem()
      ..id = 2
      ..path = 'library/folder/a.jpg';
    stubJournal([entry]);
    when(
      () => repository.getById(2),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists('library/a.jpg'),
    ).thenAnswer((_) async => Result.success(false));
    when(
      () => files.managedEntityExists('library/folder/a.jpg'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => repository.getCollectionByPath('library/a.jpg'),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.updatePathsForMovedDirectory(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(
      () => repository.updatePathsForMovedDirectory(
        'library/a.jpg',
        'library/folder/a.jpg',
      ),
    ).called(1);
    verifyNever(() => files.moveEntity(any(), any()));
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('移動元と移動先が両方存在する曖昧な状態は自動復旧しない', () async {
    final entry = move();
    final item = MediaItem()
      ..id = 2
      ..path = 'library/a.jpg';
    stubJournal([entry]);
    when(
      () => repository.getById(2),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => files.moveEntity(any(), any()));
    verifyNever(() => journal.remove(any()));
  });

  test('DB未登録の中断フォルダ作成は物理フォルダを清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'create-folder-1',
      kind: OperationKind.createFolder,
      stage: OperationStage.staged,
      payload: {'path': 'library/new-folder'},
    );
    stubJournal([entry]);
    when(
      () => repository.getByPath('library/new-folder'),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists('library/new-folder'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.deleteFile('library/new-folder'),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => files.deleteFile('library/new-folder')).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('中断複製はDBグラフ・実体・サムネイルを再収集して清掃する', () async {
    final entry = duplicate();
    final rootItem = MediaItem()
      ..id = 50
      ..path = 'library/a_copy.jpg'
      ..thumbnailPath = '.thumbnails/copy.jpg';
    final rootCollection = MediaCollection()
      ..id = 51
      ..path = 'library/a_copy.jpg';
    stubJournal([entry]);
    when(
      () => repository.getByPath(entry.payload['rootPath']! as String),
    ).thenAnswer((_) async => Result.success(rootItem));
    when(
      () => repository.getDescendants(any()),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(rootCollection));
    when(
      () => repository.getDescendantCollections(any()),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => repository.deleteGraph([50], [51])).called(1);
    verify(() => files.deleteFile('library/a_copy.jpg')).called(1);
    verify(() => files.deleteFile('.thumbnails/copy.jpg')).called(1);
    verify(() => journal.remove(entry.id)).called(1);
  });

  test('コミット済み複製は完成データを保持してジャーナルだけを清掃する', () async {
    const entry = OperationJournalEntry(
      id: 'duplicate-committed',
      kind: OperationKind.duplicate,
      stage: OperationStage.committed,
      payload: {'rootPath': 'library/a_copy.jpg'},
    );
    stubJournal([entry]);

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verify(() => journal.remove(entry.id)).called(1);
    verifyNever(() => repository.getByPath(any()));
    verifyNever(() => repository.deleteGraph(any(), any()));
    verifyNever(() => files.deleteFile(any()));
  });
}
