import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/duplicate_media_use_case.dart';

class MockRepository extends Mock implements MediaRepository {}

class MockFiles extends Mock implements FileService {}

class MockOperationJournal extends Mock implements OperationJournalService {}

class FakeMediaItem extends Fake implements MediaItem {}

class FakeOperationJournalEntry extends Fake implements OperationJournalEntry {}

void main() {
  late MockRepository repository;
  late MockFiles files;
  late DuplicateMediaUseCase useCase;

  setUpAll(() {
    registerFallbackValue(FakeMediaItem());
    registerFallbackValue(FakeOperationJournalEntry());
  });

  setUp(() {
    repository = MockRepository();
    files = MockFiles();
    useCase = DuplicateMediaUseCase(Future.value(repository), files);
    when(
      () => files.copyEntity(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
  });

  MediaItem item() => MediaItem()
    ..id = 1
    ..path = 'library/a.jpg'
    ..sourceType = MediaSourceType.localCopy
    ..type = MediaType.file;

  test('コピー後のDB保存失敗時はDBとコピー済み実体を補償清掃する', () async {
    when(
      () => repository.save(any()),
    ).thenAnswer((_) async => Result.failure(AppError.database('save failed')));

    final result = await useCase.invoke(item());

    expect(result.errorOrNull?.category, ErrorCategory.database);
    verify(() => repository.deleteGraph([], [])).called(1);
    verify(() => files.deleteFile(any(that: startsWith('library/')))).called(1);
  });

  test('補償清掃自体の失敗を重大ファイルエラーとして返す', () async {
    when(
      () => repository.save(any()),
    ).thenAnswer((_) async => Result.failure(AppError.database('save failed')));
    when(
      () => files.deleteFile(any()),
    ).thenAnswer((_) async => Result.failure(AppError.file('cleanup failed')));

    final result = await useCase.invoke(item());

    expect(result.errorOrNull?.category, ErrorCategory.file);
    expect(result.errorOrNull?.message, contains('cleanup also failed'));
  });

  test('コピー後にrepositoryが例外を投げてもコピー済み実体を補償清掃する', () async {
    when(() => repository.save(any())).thenThrow(StateError('db crashed'));

    final result = await useCase.invoke(item());

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.message, contains('複製に失敗'));
    verify(() => repository.deleteGraph([], [])).called(1);
    verify(() => files.deleteFile(any(that: startsWith('library/')))).called(1);
  });

  test('外部参照は物理コピー前に拒否する', () async {
    final external = item()
      ..sourceType = MediaSourceType.externalReference
      ..path = 'content://provider/1';

    final result = await useCase.invoke(external);

    expect(result.errorOrNull?.category, ErrorCategory.validation);
    verifyNever(() => files.copyEntity(any(), any()));
  });

  test('正常完了時は複製ジャーナルをplanned・staged・committedへ進める', () async {
    final journal = MockOperationJournal();
    final journaledUseCase = DuplicateMediaUseCase(
      Future.value(repository),
      files,
      journal,
    );
    when(() => journal.write(any())).thenAnswer((_) async {});
    when(() => journal.remove(any())).thenAnswer((_) async {});
    when(
      () => repository.save(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await journaledUseCase.invoke(item());

    expect(result.isSuccess, isTrue);
    final entries = verify(
      () => journal.write(captureAny()),
    ).captured.cast<OperationJournalEntry>().toList();
    expect(entries.map((entry) => entry.stage), [
      OperationStage.planned,
      OperationStage.staged,
      OperationStage.committed,
    ]);
    expect(entries.first.kind, OperationKind.duplicate);
    verify(() => journal.remove(entries.first.id)).called(1);
  });
}
