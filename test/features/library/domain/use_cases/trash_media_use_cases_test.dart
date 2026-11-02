import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/empty_trash_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/permanently_delete_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';

class MockFiles extends Mock implements FileService {}

class MockRepository extends Mock implements MediaRepository {}

class MockJournal extends Mock implements OperationJournalService {}

class MockPermanentDelete extends Mock
    implements PermanentlyDeleteTrashedMediaUseCase {}

class FakeJournalEntry extends Fake implements OperationJournalEntry {}

void main() {
  late MockFiles files;
  late MockRepository repository;
  late MockJournal journal;
  late MediaItem root;

  setUpAll(() => registerFallbackValue(FakeJournalEntry()));

  setUp(() {
    files = MockFiles();
    repository = MockRepository();
    journal = MockJournal();
    when(
      () => files.managedEntityExists(any()),
    ).thenAnswer((_) async => Result.success(true));
    root = MediaItem()
      ..id = 1
      ..path = 'library/a.jpg'
      ..sourceType = MediaSourceType.localCopy
      ..isTrashed = true
      ..isTrashRoot = true
      ..trashPath = '.trash/delete-1/a.jpg';
    when(() => journal.remove(any())).thenAnswer((_) async {});
    when(() => journal.write(any())).thenAnswer((_) async {});
    when(() => journal.readAll()).thenAnswer(
      (_) async => [
        const OperationJournalEntry(
          id: 'delete-1',
          kind: OperationKind.delete,
          stage: OperationStage.committed,
          payload: {'rootItemId': 1},
        ),
      ],
    );
    when(
      () => repository.getTrashRestoreConflicts(any()),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getTrashedItems(any()),
    ).thenAnswer((_) async => Result.success([root]));
    when(
      () => repository.getTrashedCollections(any()),
    ).thenAnswer((_) async => Result.success(const []));
    when(
      () => repository.getByPath(any(), includeTrashed: false),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getCollectionByPath(any(), includeTrashed: false),
    ).thenAnswer((_) async => Result.success(null));
  });

  test('ごみ箱から実体とDBグラフを復元してジャーナルを削除する', () async {
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.restoreGraphFromTrash(root.path),
    ).thenAnswer((_) async => Result.success(null));

    final result = await useCase.invoke(root);

    expect(result.isSuccess, isTrue);
    verify(
      () => files.restoreStagedDeletion(root.trashPath!, root.path),
    ).called(1);
    verify(() => repository.restoreGraphFromTrash(root.path)).called(1);
    verify(() => journal.remove('delete-1')).called(1);
  });

  test('DB復元失敗時は実体を再びごみ箱へ戻す', () async {
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.restoreGraphFromTrash(root.path),
    ).thenAnswer((_) async => Result.failure(AppError.database('failed')));
    when(
      () => files.stageDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await useCase.invoke(root);

    expect(result.isFailure, isTrue);
    verify(() => files.stageDeletion(root.path, root.trashPath!)).called(1);
    verifyNever(() => journal.remove(any()));
  });

  test('DB上の復元先が競合する場合は実体とDBグラフを変更しない', () async {
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    when(
      () => repository.getByPath(root.path, includeTrashed: false),
    ).thenAnswer(
      (_) async => Result.success(
        MediaItem()
          ..id = 99
          ..path = root.path
          ..isTrashed = false,
      ),
    );

    final result = await useCase.invoke(root);

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.additionalData?['conflictingPaths'], [
      root.path,
    ]);
    verifyNever(() => files.restoreStagedDeletion(any(), any()));
    verifyNever(() => repository.restoreGraphFromTrash(any()));
    verifyNever(() => journal.remove(any()));
  });

  test('完全削除はDBグラフ確定後に実体とサムネイルを消去する', () async {
    root.thumbnailPath = '.thumbnails/a.jpg';
    final useCase = PermanentlyDeleteTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
      releaseExternalAccess: (_) async {},
    );
    when(
      () => repository.getTrashedItems(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getTrashedCollections(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.deleteGraph([root.id], []),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await useCase.invoke(root);

    expect(result.isSuccess, isTrue);
    verify(() => journal.write(any())).called(1);
    verifyInOrder([
      () => repository.deleteGraph([root.id], []),
      () => files.deleteFile(root.trashPath!),
      () => files.deleteFile(root.thumbnailPath!),
      () => journal.remove('delete-1'),
    ]);
  });

  test('外部参照の完全削除はアイテムIDからジャーナルを解決する', () async {
    final released = <Uri>[];
    root
      ..sourceType = MediaSourceType.externalReference
      ..path = 'file:///external/a.jpg'
      ..trashPath = null;
    final useCase = PermanentlyDeleteTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
      releaseExternalAccess: (uri) async => released.add(uri),
    );
    when(
      () => repository.getTrashedItems(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getTrashedCollections(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.deleteGraph([root.id], []),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getByPath(root.path),
    ).thenAnswer((_) async => Result.success(null));
    when(() => journal.readAll()).thenAnswer(
      (_) async => [
        const OperationJournalEntry(
          id: 'external-delete',
          kind: OperationKind.delete,
          stage: OperationStage.committed,
          payload: {'rootItemId': 1},
        ),
      ],
    );

    final result = await useCase.invoke(root);

    expect(result.isSuccess, isTrue);
    expect(released, [Uri.parse(root.path)]);
    verify(() => journal.remove('external-delete')).called(1);
    verifyNever(() => files.deleteFile(any()));
  });

  test('ジャーナルがない場合でもフォールバックとしてDBグラフと実体削除を実行する', () async {
    final useCase = PermanentlyDeleteTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
      releaseExternalAccess: (_) async {},
    );
    when(
      () => repository.getTrashedItems(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getTrashedCollections(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.deleteGraph([root.id], []),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(() => journal.readAll()).thenAnswer((_) async => []);

    final result = await useCase.invoke(root);

    expect(result.isSuccess, isTrue);
    verify(() => repository.deleteGraph([root.id], [])).called(1);
    verify(() => files.deleteFile(root.trashPath!)).called(1);
  });

  test('完全削除のジャーナル書き込み例外をFailureへ変換する', () async {
    final useCase = PermanentlyDeleteTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
      releaseExternalAccess: (_) async {},
    );
    when(
      () => repository.getTrashedItems(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getTrashedCollections(root.path),
    ).thenAnswer((_) async => Result.success([]));
    when(() => journal.write(any())).thenThrow(Exception('disk full'));

    final result = await useCase.invoke(root);

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.category, ErrorCategory.file);
    verifyNever(() => repository.deleteGraph(any(), any()));
  });

  test('復元中の予期しない例外をFailureへ変換する', () async {
    final useCase = RestoreTrashedMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    when(
      () => repository.getByPath(any(), includeTrashed: false),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getCollectionByPath(any(), includeTrashed: false),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getTrashedItems(any()),
    ).thenAnswer((_) async => Result.success([root]));
    when(
      () => repository.getTrashedCollections(any()),
    ).thenAnswer((_) async => Result.success(const []));
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.restoreGraphFromTrash(any()),
    ).thenThrow(Exception('database unavailable'));

    final result = await useCase.invoke(root);

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.category, ErrorCategory.file);
    verify(
      () => files.restoreStagedDeletion(root.trashPath!, root.path),
    ).called(1);
  });

  test('ごみ箱を空にすると全ルートを順番に完全削除する', () async {
    final second = MediaItem()
      ..id = 2
      ..path = 'library/b.jpg'
      ..isTrashed = true
      ..isTrashRoot = true;
    final permanentDelete = MockPermanentDelete();
    final useCase = EmptyTrashUseCase(
      Future.value(repository),
      permanentDelete,
    );
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([root, second]));
    when(
      () => permanentDelete.invoke(root),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => permanentDelete.invoke(second),
    ).thenAnswer((_) async => Result.success(null));

    final result = await useCase.invoke();

    expect(result.dataOrNull, 2);
    verifyInOrder([
      () => permanentDelete.invoke(root),
      () => permanentDelete.invoke(second),
    ]);
  });

  test('ごみ箱を空にする途中で失敗すると残りを保持して件数を返す', () async {
    final second = MediaItem()
      ..id = 2
      ..path = 'library/b.jpg'
      ..isTrashed = true
      ..isTrashRoot = true;
    final third = MediaItem()
      ..id = 3
      ..path = 'library/c.jpg'
      ..isTrashed = true
      ..isTrashRoot = true;
    final permanentDelete = MockPermanentDelete();
    final useCase = EmptyTrashUseCase(
      Future.value(repository),
      permanentDelete,
    );
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([root, second, third]));
    when(
      () => permanentDelete.invoke(root),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => permanentDelete.invoke(second),
    ).thenAnswer((_) async => Result.failure(AppError.file('purge failed')));

    final result = await useCase.invoke();

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.additionalData?['deletedCount'], 1);
    expect(result.errorOrNull?.additionalData?['totalCount'], 3);
    final failedItems = result.errorOrNull?.additionalData?['failedItems'];
    expect(failedItems, isA<List<Map<String, dynamic>>>());
    expect((failedItems as List).first, containsPair('displayName', 'b.jpg'));
    verifyNever(() => permanentDelete.invoke(third));
  });

  test('ごみ箱一覧取得の例外をFailureへ変換する', () async {
    final permanentDelete = MockPermanentDelete();
    final useCase = EmptyTrashUseCase(
      Future.value(repository),
      permanentDelete,
    );
    when(
      () => repository.getTrashedRoots(),
    ).thenThrow(Exception('database unavailable'));

    final result = await useCase.invoke();

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.category, ErrorCategory.file);
  });
}
