import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/application/use_cases/remove_external_folder_reference_use_case.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class _MockRepository extends Mock implements MediaRepository {}

class _MockJournal extends Mock implements OperationJournalService {}

abstract class _ExternalAccessReleaser {
  Future<void> call(Uri uri);
}

class _MockExternalAccessReleaser extends Mock
    implements _ExternalAccessReleaser {}

void main() {
  late _MockRepository repository;
  late _MockJournal journal;
  late _MockExternalAccessReleaser releaseAccess;
  late RemoveExternalFolderReferenceUseCase useCase;
  late MediaCollection folder;

  setUpAll(() {
    registerFallbackValue(const MediaFilter());
    registerFallbackValue(<int>[]);
    registerFallbackValue(Uri());
    registerFallbackValue(
      const OperationJournalEntry(
        id: 'fallback',
        kind: OperationKind.removeExternalFolderReference,
        stage: OperationStage.planned,
        payload: {
          'rootCollectionId': 1,
          'originalPath': 'content://fallback/root',
          'itemIds': <int>[],
          'collectionIds': <int>[1],
        },
      ),
    );
  });

  setUp(() {
    repository = _MockRepository();
    journal = _MockJournal();
    releaseAccess = _MockExternalAccessReleaser();
    useCase = RemoveExternalFolderReferenceUseCase(
      repository,
      journal,
      releaseAccess.call,
      operationIdFactory: () => 'remove-folder-1',
    );
    folder = MediaCollection()
      ..id = 10
      ..path = 'content://provider/root'
      ..title = 'root'
      ..type = CollectionType.externalFolder;

    when(() => journal.write(any())).thenAnswer((_) async {});
    when(() => journal.remove(any())).thenAnswer((_) async {});
    when(() => releaseAccess(any())).thenAnswer((_) async {});
  });

  void stubDiscovery({
    Result<List<MediaItem>, AppError>? descendants,
    Result<List<MediaItem>, AppError>? directItems,
    Result<List<MediaCollection>, AppError>? collections,
  }) {
    when(
      () => repository.getDescendants(folder.path),
    ).thenAnswer((_) async => descendants ?? Result.success(<MediaItem>[]));
    when(
      () => repository.getAll(filter: any(named: 'filter')),
    ).thenAnswer((_) async => directItems ?? Result.success(<MediaItem>[]));
    when(() => repository.getDescendantCollections(folder.path)).thenAnswer(
      (_) async => collections ?? Result.success(<MediaCollection>[]),
    );
  }

  test('DBグラフを一括削除してから外部アクセス権を解放する', () async {
    final descendant = MediaItem()
      ..id = 20
      ..path = '${folder.path}/child';
    final direct = MediaItem()
      ..id = 21
      ..path = '${folder.path}/direct';
    final childCollection = MediaCollection()
      ..id = 30
      ..path = '${folder.path}/catalog';
    stubDiscovery(
      descendants: Result.success([descendant]),
      directItems: Result.success([descendant, direct]),
      collections: Result.success([childCollection]),
    );
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    final result = await useCase.invoke(folder);

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.permissionCleanupPending, isFalse);
    final filter =
        verify(
              () => repository.getAll(filter: captureAny(named: 'filter')),
            ).captured.single
            as MediaFilter;
    expect(filter.parentPath, folder.path);
    expect(filter.sourceType, MediaSourceType.externalReference);
    verifyInOrder([
      () => journal.write(any()),
      () => repository.deleteGraph(
        any(that: orderedEquals([20, 21])),
        any(that: orderedEquals([10, 30])),
      ),
      () => releaseAccess(Uri.parse(folder.path)),
      () => journal.remove('remove-folder-1'),
    ]);
  });

  test('対象取得に失敗した場合はDBもアクセス権も変更しない', () async {
    final error = AppError.database('scan failed');
    stubDiscovery(descendants: Result.failure(error));

    final result = await useCase.invoke(folder);

    expect(result.errorOrNull, same(error));
    verifyNever(() => journal.write(any()));
    verifyNever(() => repository.deleteGraph(any(), any()));
    verifyNever(() => releaseAccess(any()));
  });

  test('直下アイテム取得に失敗した場合は変更を開始しない', () async {
    final error = AppError.database('direct scan failed');
    stubDiscovery(directItems: Result.failure(error));

    final result = await useCase.invoke(folder);

    expect(result.errorOrNull, same(error));
    verifyNever(() => journal.write(any()));
    verifyNever(() => repository.deleteGraph(any(), any()));
    verifyNever(() => releaseAccess(any()));
  });

  test('子カタログ取得に失敗した場合は変更を開始しない', () async {
    final error = AppError.database('collection scan failed');
    stubDiscovery(collections: Result.failure(error));

    final result = await useCase.invoke(folder);

    expect(result.errorOrNull, same(error));
    verifyNever(() => journal.write(any()));
    verifyNever(() => repository.deleteGraph(any(), any()));
    verifyNever(() => releaseAccess(any()));
  });

  test('DB削除に失敗した場合はアクセス権を維持して失敗を返す', () async {
    final error = AppError.database('delete failed');
    stubDiscovery();
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.failure(error));

    final result = await useCase.invoke(folder);

    expect(result.errorOrNull, same(error));
    verifyNever(() => releaseAccess(any()));
    verify(() => journal.remove('remove-folder-1')).called(1);
  });

  test('DB削除後のアクセス権解放失敗は後片付け保留として成功を返す', () async {
    stubDiscovery();
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(() => releaseAccess(any())).thenThrow(StateError('release failed'));

    final result = await useCase.invoke(folder);

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.permissionCleanupPending, isTrue);
    verifyNever(() => journal.remove('remove-folder-1'));
  });

  test('ジャーナルを作成できない場合は変更を開始しない', () async {
    stubDiscovery();
    when(() => journal.write(any())).thenThrow(StateError('journal failed'));

    final result = await useCase.invoke(folder);

    expect(result.isFailure, isTrue);
    verifyNever(() => repository.deleteGraph(any(), any()));
    verifyNever(() => releaseAccess(any()));
  });

  test('権限解放後にジャーナル削除が失敗しても後片付け保留として扱う', () async {
    stubDiscovery();
    when(
      () => repository.deleteGraph(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => journal.remove('remove-folder-1'),
    ).thenThrow(StateError('journal cleanup failed'));

    final result = await useCase.invoke(folder);

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.permissionCleanupPending, isTrue);
    verify(() => releaseAccess(Uri.parse(folder.path))).called(1);
  });

  test('参照解除ジャーナルは外部パスとルートIDを検証する', () {
    const valid = OperationJournalEntry(
      id: 'remove-folder-1',
      kind: OperationKind.removeExternalFolderReference,
      stage: OperationStage.planned,
      payload: {
        'rootCollectionId': 10,
        'originalPath': 'content://provider/root',
        'itemIds': <int>[20],
        'collectionIds': <int>[10, 30],
      },
    );
    expect(valid.validate, returnsNormally);

    final invalid = valid.copyWith(
      payload: {
        ...valid.payload,
        'collectionIds': <int>[30],
      },
    );
    expect(invalid.validate, throwsFormatException);
  });
}
