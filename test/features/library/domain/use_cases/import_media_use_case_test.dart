import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';

class MockFileService extends Mock implements FileService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockFile extends Mock implements File {}

class MockImportJournal extends Mock implements OperationJournalService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFileService mockFileService;
  late MockMediaRepository mockMediaRepository;
  late ImportMediaUseCase useCase;

  setUpAll(() {
    registerFallbackValue(MediaItem());
    registerFallbackValue(MediaCollection());
    registerFallbackValue(MockFile());
    registerFallbackValue(
      const OperationJournalEntry(
        id: 'test',
        kind: OperationKind.import,
        stage: OperationStage.staged,
        payload: {'path': 'library/test.jpg'},
      ),
    );
  });

  setUp(() {
    mockFileService = MockFileService();
    mockMediaRepository = MockMediaRepository();
    when(
      () => mockMediaRepository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    useCase = ImportMediaUseCase(
      mockFileService,
      Future.value(mockMediaRepository),
    );
    when(
      () => mockFileService.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));
  });

  group('ImportMediaUseCase.invoke', () {
    final testFile = MockFile();
    const testRelativePath = 'library/test_uuid.jpg';
    const testOriginalPath = '/path/to/original.jpg';

    setUp(() {
      when(() => testFile.absolute).thenReturn(testFile);
      when(() => testFile.path).thenReturn(testOriginalPath);
      when(() => testFile.length()).thenAnswer((_) async => 1024);
    });

    test('カタログ保存とDB巻戻しが失敗した場合は実体を保持する', () async {
      when(
        () => mockFileService.importFile(any<File>()),
      ).thenAnswer((_) async => Result.success(testRelativePath));
      when(() => mockMediaRepository.save(any<MediaItem>())).thenAnswer((
        call,
      ) async {
        (call.positionalArguments.first as MediaItem).id = 42;
        return Result.success(null);
      });
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.failure(AppError.database('カタログ保存失敗')));
      when(
        () => mockMediaRepository.delete(42),
      ).thenAnswer((_) async => Result.failure(AppError.database('巻戻し失敗')));
      final result = await useCase.invoke(testFile, isCatalog: true);
      expect(result.isFailure, true);
      expect(result.errorOrNull!.additionalData?['importRetryBlocked'], isTrue);
      verifyNever(() => mockFileService.deleteFile(any()));
    });

    test('DB保存後のjournal削除失敗は保存成功を保持し再取り込みを誘発しない', () async {
      final journal = MockImportJournal();
      when(() => journal.write(any())).thenAnswer((_) async {});
      when(
        () => journal.remove(any()),
      ).thenThrow(StateError('journal unavailable'));
      useCase = ImportMediaUseCase(
        mockFileService,
        Future.value(mockMediaRepository),
        journal,
      );
      when(
        () => mockFileService.importFile(
          any<File>(),
          onDestinationPrepared: any(named: 'onDestinationPrepared'),
          onDestinationPublished: any(named: 'onDestinationPublished'),
          importOperationId: any(named: 'importOperationId'),
        ),
      ).thenAnswer((_) async => Result.success(testRelativePath));
      when(() => mockMediaRepository.save(any<MediaItem>())).thenAnswer((
        call,
      ) async {
        (call.positionalArguments.first as MediaItem).id = 42;
        return Result.success(null);
      });
      final result = await useCase.invoke(testFile);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.id, 42);
      verifyNever(() => mockMediaRepository.delete(any()));
      verifyNever(() => mockFileService.deleteFile(any()));
    });

    test('plannedとstagedのjournalにコピーと同じoperationの一時パスを保持する', () async {
      final journal = MockImportJournal();
      final entries = <OperationJournalEntry>[];
      when(() => journal.write(any())).thenAnswer((call) async {
        entries.add(call.positionalArguments.single as OperationJournalEntry);
      });
      when(() => journal.remove(any())).thenAnswer((_) async {});
      useCase = ImportMediaUseCase(
        mockFileService,
        Future.value(mockMediaRepository),
        journal,
      );
      String? copyOperationId;
      when(
        () => mockFileService.importFile(
          any<File>(),
          onDestinationPrepared: any(named: 'onDestinationPrepared'),
          onDestinationPublished: any(named: 'onDestinationPublished'),
          importOperationId: any(named: 'importOperationId'),
        ),
      ).thenAnswer((call) async {
        copyOperationId = call.namedArguments[#importOperationId] as String;
        expect(FileService.isImportActive(copyOperationId!), isTrue);
        await (call.namedArguments[#onDestinationPrepared]
            as Future<void> Function(String))(testRelativePath);
        await (call.namedArguments[#onDestinationPublished]
            as Future<void> Function(String))(testRelativePath);
        return Result.success(testRelativePath);
      });
      when(() => mockMediaRepository.save(any<MediaItem>())).thenAnswer((
        call,
      ) async {
        expect(FileService.isImportActive(copyOperationId!), isTrue);
        (call.positionalArguments.single as MediaItem).id = 42;
        return Result.success(null);
      });
      expect((await useCase.invoke(testFile)).isSuccess, isTrue);
      expect(entries.map((entry) => entry.stage), [
        OperationStage.planned,
        OperationStage.staged,
      ]);
      expect(entries.every((entry) => entry.id == copyOperationId), isTrue);
      expect(
        entries.last.payload['copyArtifacts'],
        entries.first.payload['copyArtifacts'],
      );
      expect(
        (entries.first.payload['copyArtifacts'] as Map)['partialPath'],
        '$testRelativePath.$copyOperationId.tagshelf-part',
      );
      expect(FileService.isImportActive(copyOperationId!), isFalse);
    });

    test('正常系: ファイルコピーとDB保存が成功した場合、Successを返すこと', () async {
      // Setup
      when(
        () => mockFileService.importFile(any<File>()),
      ).thenAnswer((_) async => Result.success(testRelativePath));
      when(() => mockMediaRepository.save(any<MediaItem>())).thenAnswer((
        call,
      ) async {
        (call.positionalArguments.single as MediaItem).id = 42;
        return Result.success(null);
      });

      // Execute
      final result = await useCase.invoke(testFile);

      // Verify
      expect(result.isSuccess, true);
      final item = result.dataOrNull!;
      expect(item.path, testRelativePath);
      expect(item.originalPath, testOriginalPath);
      expect(item.size, 1024);

      verify(() => mockFileService.importFile(testFile)).called(1);
      verify(() => mockMediaRepository.save(any<MediaItem>())).called(1);
    });

    test('異常系: ファイルコピーに失敗した場合、Failureを返すこと', () async {
      // Setup
      final error = AppError.file('Copy failed');
      when(
        () => mockFileService.importFile(any<File>()),
      ).thenAnswer((_) async => Result.failure(error));

      // Execute
      final result = await useCase.invoke(testFile);

      // Verify
      expect(result.isFailure, true);
      expect(result.errorOrNull, error);
      verify(() => mockFileService.importFile(testFile)).called(1);
      verifyNever(() => mockMediaRepository.save(any<MediaItem>()));
    });

    test('異常系: DB保存に失敗した場合、Failureを返すこと', () async {
      // Setup
      final error = AppError.database('DB save failed');
      when(
        () => mockFileService.importFile(any<File>()),
      ).thenAnswer((_) async => Result.success(testRelativePath));
      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.failure(error));

      // Execute
      final result = await useCase.invoke(testFile);

      // Verify
      expect(result.isFailure, true);
      expect(result.errorOrNull?.category, ErrorCategory.database);
      verify(() => mockFileService.importFile(testFile)).called(1);
      // RetryPolicy.database は maxAttempts: 2 なので 2回呼ばれる
      verify(() => mockMediaRepository.save(any<MediaItem>())).called(2);
    });

    test('正常系: サブフォルダ内でのインポート時にもカタログ登録を指定すればMediaCollectionが作成されること', () async {
      // Setup
      const subParentPath = 'library/subfolder';
      const subRelativePath = 'library/subfolder/photo.jpg';
      when(
        () => mockFileService.importFile(
          any<File>(),
          targetParentPath: any(named: 'targetParentPath'),
        ),
      ).thenAnswer((_) async => Result.success(subRelativePath));
      when(() => mockMediaRepository.save(any<MediaItem>())).thenAnswer((
        call,
      ) async {
        (call.positionalArguments.single as MediaItem).id = 42;
        return Result.success(null);
      });
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke(
        testFile,
        parentPath: subParentPath,
        isCatalog: true,
      );

      // Verify
      expect(result.isSuccess, true);
      final savedCollection =
          verify(
                () => mockMediaRepository.saveCollection(captureAny()),
              ).captured.single
              as MediaCollection;
      expect(savedCollection.items.isChanged, isTrue);
      expect(savedCollection.isCatalog, isTrue);
    });
  });
}
