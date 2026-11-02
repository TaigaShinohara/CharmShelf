import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class _MockJournal extends Mock implements OperationJournalService {}

class _MockFiles extends Mock implements FileService {}

class _MockRepository extends Mock implements MediaRepository {}

abstract class _ExternalAccessReleaser {
  Future<void> call(Uri uri);
}

class _MockExternalAccessReleaser extends Mock
    implements _ExternalAccessReleaser {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(Uri());
  });

  test('中断した外部フォルダ参照解除を完了してジャーナルを消す', () async {
    final journal = _MockJournal();
    final files = _MockFiles();
    final repository = _MockRepository();
    final releaseAccess = _MockExternalAccessReleaser();
    const entry = OperationJournalEntry(
      id: 'remove-folder-1',
      kind: OperationKind.removeExternalFolderReference,
      stage: OperationStage.planned,
      payload: {
        'rootCollectionId': 10,
        'originalPath': 'content://provider/root',
        'itemIds': <int>[20, 21],
        'collectionIds': <int>[10, 30],
      },
    );
    when(() => journal.readReport()).thenAnswer(
      (_) async => const OperationJournalReadReport(
        entries: [entry],
        quarantinedOperationIds: {},
      ),
    );
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => files.listTrashStagingEntries(),
    ).thenAnswer((_) async => Result.success([]));
    when(() => releaseAccess(any())).thenAnswer((_) async {});
    when(() => journal.remove(any())).thenAnswer((_) async {});
    final service = OperationRecoveryService(
      journal,
      files,
      repository,
      releaseExternalAccess: releaseAccess.call,
    );

    final result = await service.recover();

    expect(result.isSuccess, isTrue);
    verifyInOrder([
      () => repository.deleteGraph(
        any(that: orderedEquals([20, 21])),
        any(that: orderedEquals([10, 30])),
      ),
      () => releaseAccess(Uri.parse('content://provider/root')),
      () => journal.remove('remove-folder-1'),
    ]);
  });

  test('復旧時のDB削除失敗ではアクセス権とジャーナルを維持する', () async {
    final journal = _MockJournal();
    final files = _MockFiles();
    final repository = _MockRepository();
    final releaseAccess = _MockExternalAccessReleaser();
    const entry = OperationJournalEntry(
      id: 'remove-folder-1',
      kind: OperationKind.removeExternalFolderReference,
      stage: OperationStage.committed,
      payload: {
        'rootCollectionId': 10,
        'originalPath': 'content://provider/root',
        'itemIds': <int>[],
        'collectionIds': <int>[10],
      },
    );
    when(() => journal.readReport()).thenAnswer(
      (_) async => const OperationJournalReadReport(
        entries: [entry],
        quarantinedOperationIds: {},
      ),
    );
    when(() => repository.deleteGraph(any(), any())).thenAnswer(
      (_) async => Result.failure(AppError.database('delete failed')),
    );
    final service = OperationRecoveryService(
      journal,
      files,
      repository,
      releaseExternalAccess: releaseAccess.call,
    );

    final result = await service.recover();

    expect(result.isFailure, isTrue);
    verifyNever(() => releaseAccess(any()));
    verifyNever(() => journal.remove(any()));
  });
}
