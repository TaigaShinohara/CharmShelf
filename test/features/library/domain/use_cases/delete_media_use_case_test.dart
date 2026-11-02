import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/delete_media_use_case.dart';

class MockFileService extends Mock implements FileService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockOperationJournalService extends Mock
    implements OperationJournalService {}

class FakeJournalEntry extends Fake implements OperationJournalEntry {}

void main() {
  late MockFileService files;
  late MockMediaRepository repository;
  late MockOperationJournalService journal;
  late DeleteMediaUseCase useCase;

  setUpAll(() {
    registerFallbackValue(FakeJournalEntry());
    registerFallbackValue(DateTime(2025));
  });

  setUp(() {
    files = MockFileService();
    repository = MockMediaRepository();
    journal = MockOperationJournalService();
    useCase = DeleteMediaUseCase(files, Future.value(repository), journal);

    when(
      () => repository.getByParentPath(any()),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => repository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.moveGraphToTrash(
        any(),
        any(),
        rootItemId: any(named: 'rootItemId'),
        trashPath: any(named: 'trashPath'),
        trashedAt: any(named: 'trashedAt'),
      ),
    ).thenAnswer((_) async => Result.success(null));
    when(() => journal.write(any())).thenAnswer((_) async {});
    when(() => journal.remove(any())).thenAnswer((_) async {});
    when(
      () => files.stageDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.restoreStagedDeletion(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));
  });

  MediaItem localItem({int id = 1, MediaType type = MediaType.file}) =>
      MediaItem()
        ..id = id
        ..path = type == MediaType.folder ? 'library/folder' : 'library/a.jpg'
        ..thumbnailPath = type == MediaType.file ? '.thumbnails/a.jpg' : null
        ..sourceType = MediaSourceType.localCopy
        ..type = type;

  test('ローカル項目を退避後、DBグラフを復元可能なごみ箱状態にする', () async {
    final item = localItem();

    final result = await useCase.invoke(item);

    expect(result.isSuccess, isTrue);
    verify(() => files.stageDeletion(item.path, any())).called(1);
    verify(
      () => repository.moveGraphToTrash(
        [item.id],
        [],
        rootItemId: item.id,
        trashPath: any(named: 'trashPath'),
        trashedAt: any(named: 'trashedAt'),
      ),
    ).called(1);
    verifyNever(() => files.deleteFile(any()));
    verify(() => journal.write(any())).called(3);
    verifyNever(() => journal.remove(any()));
  });

  test('DB削除失敗時は退避物を元へ戻し、ジャーナルを削除する', () async {
    final item = localItem();
    final error = AppError.database('DB delete failed');
    when(
      () => repository.moveGraphToTrash(
        any(),
        any(),
        rootItemId: any(named: 'rootItemId'),
        trashPath: any(named: 'trashPath'),
        trashedAt: any(named: 'trashedAt'),
      ),
    ).thenAnswer((_) async => Result.failure(error));

    final result = await useCase.invoke(item);

    expect(result.errorOrNull?.category, ErrorCategory.database);
    verify(() => files.restoreStagedDeletion(any(), item.path)).called(1);
    verify(() => journal.remove(any())).called(1);
    verifyNever(() => files.deleteFile(item.thumbnailPath!));
  });

  test('正常なごみ箱移動はコミット済みジャーナルを復元用に保持する', () async {
    final item = localItem();

    final result = await useCase.invoke(item);

    expect(result.isSuccess, isTrue);
    verifyNever(() => journal.remove(any()));
    verifyNever(() => files.deleteFile(any()));
  });

  test('外部参照は物理ファイルを操作せずDBだけ削除する', () async {
    final item = MediaItem()
      ..id = 2
      ..path = 'content://provider/item/2'
      ..sourceType = MediaSourceType.externalReference
      ..type = MediaType.file;

    final result = await useCase.invoke(item);

    expect(result.isSuccess, isTrue);
    final journalEntries = verify(
      () => journal.write(captureAny()),
    ).captured.cast<OperationJournalEntry>();
    expect(journalEntries, isNotEmpty);
    expect(
      journalEntries.every((entry) => entry.payload['trashPath'] == ''),
      isTrue,
    );
    verify(
      () => repository.moveGraphToTrash(
        [item.id],
        [],
        rootItemId: item.id,
        trashPath: null,
        trashedAt: any(named: 'trashedAt'),
      ),
    ).called(1);
    verifyNever(() => files.stageDeletion(any(), any()));
    verifyNever(() => files.restoreStagedDeletion(any(), any()));
    verifyNever(() => files.deleteFile(any()));
  });

  test('フォルダは子を収集して単一トランザクションに渡す', () async {
    final folder = localItem(id: 10, type: MediaType.folder);
    final child = MediaItem()
      ..id = 11
      ..path = '${folder.path}/child.jpg'
      ..parentPath = folder.path
      ..sourceType = MediaSourceType.localCopy
      ..type = MediaType.file;
    when(
      () => repository.getByParentPath(folder.path),
    ).thenAnswer((_) async => Result.success([child]));

    final result = await useCase.invoke(folder);

    expect(result.isSuccess, isTrue);
    verify(
      () => repository.moveGraphToTrash(
        [child.id, folder.id],
        [],
        rootItemId: folder.id,
        trashPath: any(named: 'trashPath'),
        trashedAt: any(named: 'trashedAt'),
      ),
    ).called(1);
    verify(() => files.stageDeletion(folder.path, any())).called(1);
  });

  test('不正IDは副作用なしで拒否する', () async {
    final item = localItem(id: 0);

    final result = await useCase.invoke(item);

    expect(result.errorOrNull?.category, ErrorCategory.validation);
    verifyNever(() => journal.write(any()));
    verifyNever(
      () => repository.moveGraphToTrash(
        any(),
        any(),
        rootItemId: any(named: 'rootItemId'),
        trashPath: any(named: 'trashPath'),
        trashedAt: any(named: 'trashedAt'),
      ),
    );
  });
}
