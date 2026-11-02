import 'dart:io';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/scan_directory_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/local_notification_service_io.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';

class MockImportMediaUseCase extends Mock implements ImportMediaUseCase {}

class MockCreateFolderUseCase extends Mock implements CreateFolderUseCase {}

class MockExternalStorageService extends Mock
    implements ExternalStorageService {}

class MockFileService extends Mock implements FileService {}

class MockOperationJournalService extends Mock
    implements OperationJournalService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockLocalNotificationService extends Mock
    implements LocalNotificationService {}

void main() {
  late MockImportMediaUseCase mockImportUseCase;
  late MockCreateFolderUseCase mockCreateFolderUseCase;
  late MockExternalStorageService mockStorageService;
  late MockFileService mockFileService;
  late MockOperationJournalService mockOperationJournal;
  late MockMediaRepository mockRepository;
  late MockLocalNotificationService mockNotificationService;
  late InternalImportService service;

  setUpAll(() {
    registerFallbackValue(MediaItem());
    registerFallbackValue(MediaCollection());
    registerFallbackValue(false);
    registerFallbackValue(
      const OperationJournalEntry(
        id: 'fallback',
        kind: OperationKind.import,
        stage: OperationStage.planned,
        payload: {'path': 'library/fallback'},
      ),
    );
    registerFallbackValue(File(''));
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockImportUseCase = MockImportMediaUseCase();
    mockCreateFolderUseCase = MockCreateFolderUseCase();
    mockStorageService = MockExternalStorageService();
    mockFileService = MockFileService();
    mockOperationJournal = MockOperationJournalService();
    mockRepository = MockMediaRepository();
    mockNotificationService = MockLocalNotificationService();

    when(
      () => mockNotificationService.showProgress(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        maxProgress: any(named: 'maxProgress'),
        currentProgress: any(named: 'currentProgress'),
        indeterminate: any(named: 'indeterminate'),
      ),
    ).thenAnswer((_) async => Result.success(null));

    when(
      () => mockNotificationService.showNow(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => Result.success(null));

    when(() => mockStorageService.isSupportedExtension(any())).thenReturn(true);
    when(
      () => mockRepository.saveCollection(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => mockRepository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(() => mockOperationJournal.write(any())).thenAnswer((_) async {});
    when(() => mockOperationJournal.remove(any())).thenAnswer((_) async {});

    when(
      () => mockRepository.save(any()),
    ).thenAnswer((_) async => Result.success(null));
    service = InternalImportService(
      mockImportUseCase,
      mockCreateFolderUseCase,
      mockStorageService,
      mockFileService,
      mockOperationJournal,
      mockRepository,
      mockNotificationService,
      isCancelled: () => false,
      invalidateCollection: (_) {},
      invalidateLibrary: () {},
      fileSize: (_) async => 3,
    );
  });

  test(
    'content import keeps display name and stable source identity and removes only its own staging file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tagshelf_content_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final staged = File('${directory.path}/staged.jpg');
      final unrelated = File('${directory.path}/other.jpg');
      await staged.writeAsBytes([1, 2, 3]);
      await unrelated.writeAsBytes([4]);
      final uri = Uri.parse('content://provider/tree/root/document/file');
      when(
        () => mockStorageService.copyToTemp(
          uri,
          'photo.jpg',
          expectedBytes: 3,
          maxBytes: any(named: 'maxBytes'),
        ),
      ).thenAnswer((_) async => staged.path);
      final item = MediaItem()
        ..id = 8
        ..path = 'library/photo.jpg';
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: null,
          sourceFileName: 'photo.jpg',
          isCatalog: false,
          expectedFileBytes: 3,
        ),
      ).thenAnswer((_) async => Result.success(item));
      final progress = <SyncProgress>[];
      final result = await service.importContentFile(
        uri,
        'photo.jpg',
        'Folder/photo.jpg',
        expectedBytes: 3,
        onProgress: progress.add,
      );
      expect(progress.last.status, SyncStatus.completed);
      expect(result.isSuccess, isTrue);
      expect(
        result.dataOrNull!.committedFiles.single.sourcePath,
        'Folder/photo.jpg',
      );
      expect(await staged.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test(
    'failed content staging reports an explicit retryable item without a destination write',
    () async {
      final uri = Uri.parse('content://provider/tree/root/document/file');
      when(
        () => mockStorageService.copyToTemp(
          uri,
          'photo.jpg',
          expectedBytes: 3,
          maxBytes: any(named: 'maxBytes'),
        ),
      ).thenAnswer((_) async => null);
      final progress = <SyncProgress>[];
      final result = await service.importContentFile(
        uri,
        'photo.jpg',
        'photo.jpg',
        expectedBytes: 3,
        onProgress: progress.add,
      );
      expect(progress.last.status, SyncStatus.completed);
      expect(
        result.dataOrNull!.failedEntries.single.reason,
        ImportFailureReasonCode.temporaryCopy,
      );
      expect(result.dataOrNull!.pendingSourcePaths, ['photo.jpg']);
      verifyZeroInteractions(mockImportUseCase);
    },
  );

  test('device import never deletes its original after copying', () async {
    final directory = await Directory.systemTemp.createTemp(
      'device-import-original-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final original = File('${directory.path}/source.txt');
    await original.writeAsString('abc');
    when(
      () => mockStorageService.copyToTemp(
        original.uri,
        'source.txt',
        expectedBytes: 3,
      ),
    ).thenAnswer((_) async => original.path);
    final item = MediaItem()
      ..id = 73
      ..path = 'library/source.txt';
    when(
      () => mockImportUseCase.invoke(
        any(),
        parentPath: null,
        sourceFileName: 'source.txt',
        isCatalog: false,
        expectedFileBytes: 3,
      ),
    ).thenAnswer((_) async => Result.success(item));
    final result = await service.importDeviceFile(
      original.uri,
      'source.txt',
      'Documents/source.txt',
      expectedBytes: 3,
    );
    expect(result.isSuccess, isTrue);
    expect(
      result.dataOrNull!.committedFiles.single.sourcePath,
      'Documents/source.txt',
    );
    expect(await original.readAsString(), 'abc');
  });

  test(
    'unknown document size is measured before destination import and only owned staging is removed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tagshelf_unknown_document_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final staged = File('${directory.path}/staged.jpg');
      final other = File('${directory.path}/unrelated.jpg');
      await staged.writeAsBytes([1, 2, 3, 4]);
      await other.writeAsBytes([9]);
      final uri = Uri.parse('content://provider/document/opaque');
      service = InternalImportService(
        mockImportUseCase,
        mockCreateFolderUseCase,
        mockStorageService,
        mockFileService,
        mockOperationJournal,
        mockRepository,
        mockNotificationService,
        isCancelled: () => false,
        invalidateCollection: (_) {},
        invalidateLibrary: () {},
      );
      when(
        () => mockStorageService.copyToTemp(
          uri,
          'photo.jpg',
          expectedBytes: null,
          maxBytes: 8,
        ),
      ).thenAnswer((_) async => staged.path);
      final saved = MediaItem()
        ..id = 31
        ..size = 4
        ..path = 'library/Current/photo.jpg';
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: 'library/Current',
          sourceFileName: 'photo.jpg',
          isCatalog: true,
          expectedFileBytes: 4,
        ),
      ).thenAnswer((_) async => Result.success(saved));
      final measured = <int>[];

      final result = await service.importContentFile(
        uri,
        'photo.jpg',
        'document-opaque',
        targetParentPath: 'library/Current',
        isCatalog: true,
        maxBytes: 8,
        onMeasuredBytes: measured.add,
      );

      expect(result.isSuccess, isTrue);
      expect(measured, [4]);
      expect(
        result.dataOrNull!.committedFiles.single.sourcePath,
        'document-opaque',
      );
      expect(result.dataOrNull!.committedFiles.single.sizeBytes, 4);
      expect(await staged.exists(), isFalse);
      expect(await other.readAsBytes(), [9]);
      verifyNever(() => mockFileService.deleteFile(any()));
    },
  );

  test(
    'measured unknown document exceeding remaining budget never writes a destination',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tagshelf_large_document_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final staged = File('${directory.path}/staged.jpg');
      await staged.writeAsBytes([1, 2, 3, 4]);
      final uri = Uri.parse('content://provider/document/oversize');
      service = InternalImportService(
        mockImportUseCase,
        mockCreateFolderUseCase,
        mockStorageService,
        mockFileService,
        mockOperationJournal,
        mockRepository,
        mockNotificationService,
        isCancelled: () => false,
        invalidateCollection: (_) {},
        invalidateLibrary: () {},
      );
      when(
        () => mockStorageService.copyToTemp(
          uri,
          'photo.jpg',
          expectedBytes: null,
          maxBytes: 3,
        ),
      ).thenAnswer((_) async => staged.path);

      final result = await service.importContentFile(
        uri,
        'photo.jpg',
        'document-oversize',
        maxBytes: 3,
      );

      final report =
          result.dataOrNull ??
          ImportExecutionReport.fromMap(result.errorOrNull!.additionalData!);
      expect(report.processedItems, 0);
      expect(report.failedItems, 1);
      expect(report.pendingSourcePaths, ['document-oversize']);
      expect(await staged.exists(), isFalse);
      verifyNever(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          sourceFileName: any(named: 'sourceFileName'),
          isCatalog: any(named: 'isCatalog'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      );
    },
  );

  group('InternalImportService.importFolder', () {
    test(
      'known SAF folder size exceeding the remaining session budget is refused before a destination is created',
      () async {
        final uri = Uri.parse('content://provider/tree/Album');
        service = InternalImportService(
          mockImportUseCase,
          mockCreateFolderUseCase,
          mockStorageService,
          mockFileService,
          mockOperationJournal,
          mockRepository,
          mockNotificationService,
          isCancelled: () => false,
          invalidateCollection: (_) {},
          invalidateLibrary: () {},
          maxImportTotalBytes: 100,
        );
        when(
          () => mockStorageService.listFiles(
            uri,
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ExternalFileInfo(
              uri: 'content://provider/tree/Album/document/photo',
              name: 'photo.jpg',
              relativePath: 'photo.jpg',
              isMedia: true,
              size: 50,
            ),
          ),
        );

        final result = await service.importFolder(uri, maxBytes: 20);

        expect(result.isFailure, isTrue);
        verifyNever(
          () => mockCreateFolderUseCase.invoke(
            any(),
            parentPath: any(named: 'parentPath'),
          ),
        );
        verifyNever(
          () => mockStorageService.copyToTemp(
            any(),
            any(),
            expectedBytes: any(named: 'expectedBytes'),
            maxBytes: any(named: 'maxBytes'),
          ),
        );
      },
    );

    test(
      'standard SAF folder measures unknown size and cleans all owned content copies',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'tagshelf_unknown_folder_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final known = File('${directory.path}/known.jpg');
        final unknown = File('${directory.path}/unknown.jpg');
        final unrelated = File('${directory.path}/unrelated.jpg');
        await known.writeAsBytes([1, 2, 3]);
        await unknown.writeAsBytes([4, 5, 6, 7]);
        await unrelated.writeAsBytes([9]);
        final rootUri = Uri.parse('content://provider/tree/Chosen');
        final knownUri = Uri.parse('content://provider/document/known');
        final unknownUri = Uri.parse('content://provider/document/unknown');
        final root = MediaItem()
          ..id = 1
          ..path = 'library/Chosen'
          ..type = MediaType.folder;
        service = InternalImportService(
          mockImportUseCase,
          mockCreateFolderUseCase,
          mockStorageService,
          mockFileService,
          mockOperationJournal,
          mockRepository,
          mockNotificationService,
          isCancelled: () => false,
          invalidateCollection: (_) {},
          invalidateLibrary: () {},
          maxImportTotalBytes: 100,
        );
        when(
          () => mockCreateFolderUseCase.invoke('Chosen', parentPath: null),
        ).thenAnswer((_) async => Result.success(root));
        when(
          () => mockStorageService.listFiles(
            rootUri,
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            ExternalFileInfo(
              uri: '$knownUri',
              name: 'a.jpg',
              relativePath: 'a.jpg',
              size: 3,
              isMedia: true,
            ),
            ExternalFileInfo(
              uri: '$unknownUri',
              name: 'b.jpg',
              relativePath: 'b.jpg',
              isMedia: true,
            ),
          ]),
        );
        when(
          () => mockStorageService.copyToTemp(
            knownUri,
            'a.jpg',
            expectedBytes: 3,
            maxBytes: 10,
          ),
        ).thenAnswer((_) async => known.path);
        when(
          () => mockStorageService.copyToTemp(
            unknownUri,
            'b.jpg',
            expectedBytes: null,
            maxBytes: 7,
          ),
        ).thenAnswer((_) async => unknown.path);
        final measuredBytes = <int>[];
        when(
          () => mockImportUseCase.invoke(
            any(),
            parentPath: 'library/Chosen',
            sourceFileName: any(named: 'sourceFileName'),
            importedAt: any(named: 'importedAt'),
            expectedFileBytes: any(named: 'expectedFileBytes'),
          ),
        ).thenAnswer((call) async {
          final file = call.positionalArguments.single as File;
          final expected = call.namedArguments[#expectedFileBytes] as int;
          expect(expected, await file.length());
          measuredBytes.add(expected);
          final name = call.namedArguments[#sourceFileName] as String;
          return Result.success(
            MediaItem()
              ..id = name == 'a.jpg' ? 2 : 3
              ..size = expected
              ..path = 'library/Chosen/$name',
          );
        });

        final result = await service.importFolder(
          rootUri,
          sourceName: 'Chosen',
          maxBytes: 10,
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.dataOrNull!.committedFiles.map((item) => item.sourcePath),
          ['a.jpg', 'b.jpg'],
        );
        expect(result.dataOrNull!.pendingSourcePaths, isEmpty);
        expect(
          result.dataOrNull!.committedFiles.map((item) => item.sizeBytes),
          [3, 4],
        );
        expect(measuredBytes, [3, 4]);
        expect(await known.exists(), isFalse);
        expect(await unknown.exists(), isFalse);
        expect(await unrelated.readAsBytes(), [9]);
        verifyNever(() => mockFileService.deleteFile(any()));
      },
    );

    test(
      'unknown SAF folder sizes share a cumulative budget and reject overflow before destination write',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'tagshelf_folder_budget_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final first = File('${directory.path}/first.jpg');
        final second = File('${directory.path}/second.jpg');
        await first.writeAsBytes([1, 2, 3, 4]);
        await second.writeAsBytes([5, 6, 7]);
        final rootUri = Uri.parse('content://provider/tree/Chosen');
        final firstUri = Uri.parse('content://provider/document/first');
        final secondUri = Uri.parse('content://provider/document/second');
        final root = MediaItem()
          ..id = 1
          ..path = 'library/Chosen'
          ..type = MediaType.folder;
        service = InternalImportService(
          mockImportUseCase,
          mockCreateFolderUseCase,
          mockStorageService,
          mockFileService,
          mockOperationJournal,
          mockRepository,
          mockNotificationService,
          isCancelled: () => false,
          invalidateCollection: (_) {},
          invalidateLibrary: () {},
          maxImportTotalBytes: 100,
        );
        when(
          () => mockCreateFolderUseCase.invoke('Chosen', parentPath: null),
        ).thenAnswer((_) async => Result.success(root));
        when(
          () => mockStorageService.listFiles(
            rootUri,
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            ExternalFileInfo(
              uri: '$firstUri',
              name: 'a.jpg',
              relativePath: 'a.jpg',
              isMedia: true,
            ),
            ExternalFileInfo(
              uri: '$secondUri',
              name: 'b.jpg',
              relativePath: 'b.jpg',
              isMedia: true,
            ),
          ]),
        );
        final remainingBudgets = <int>[];
        when(
          () => mockStorageService.copyToTemp(
            any(),
            any(),
            expectedBytes: null,
            maxBytes: any(named: 'maxBytes'),
          ),
        ).thenAnswer((call) async {
          remainingBudgets.add(call.namedArguments[#maxBytes] as int);
          return call.positionalArguments.first == firstUri
              ? first.path
              : second.path;
        });
        when(
          () => mockImportUseCase.invoke(
            any(),
            parentPath: 'library/Chosen',
            sourceFileName: 'a.jpg',
            importedAt: any(named: 'importedAt'),
            expectedFileBytes: 4,
          ),
        ).thenAnswer(
          (_) async => Result.success(
            MediaItem()
              ..id = 2
              ..size = 4
              ..path = 'library/Chosen/a.jpg',
          ),
        );

        final result = await service.importFolder(
          rootUri,
          sourceName: 'Chosen',
          maxBytes: 5,
        );

        expect(result.isSuccess, isTrue);
        final report = result.dataOrNull!;
        expect(remainingBudgets, [5, 1]);
        expect(report.processedItems, 1);
        expect(report.failedItems, 1);
        expect(report.committedFiles.single.sourcePath, 'a.jpg');
        expect(report.pendingSourcePaths, ['b.jpg']);
        expect(await first.exists(), isFalse);
        expect(await second.exists(), isFalse);
        verifyNever(
          () => mockImportUseCase.invoke(
            any(),
            parentPath: any(named: 'parentPath'),
            sourceFileName: 'b.jpg',
            importedAt: any(named: 'importedAt'),
            expectedFileBytes: any(named: 'expectedFileBytes'),
          ),
        );
        verifyNever(() => mockFileService.deleteFile(any()));
      },
    );

    test(
      'selected device folder uses its frozen entries without reopening SAF',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'device-folder-test-',
        );
        addTearDown(() => temp.delete(recursive: true));
        final original = File('${temp.path}/chapter/page.jpg');
        await original.parent.create();
        await original.writeAsBytes([1, 2, 3]);
        final root = MediaItem()
          ..id = 1
          ..path = 'library/Chosen'
          ..type = MediaType.folder;
        final chapter = MediaItem()
          ..id = 2
          ..path = 'library/Chosen/chapter'
          ..type = MediaType.folder;
        when(
          () => mockCreateFolderUseCase.invoke('Chosen', parentPath: null),
        ).thenAnswer((_) async => Result.success(root));
        when(
          () =>
              mockCreateFolderUseCase.invoke('chapter', parentPath: root.path),
        ).thenAnswer((_) async => Result.success(chapter));
        when(
          () => mockStorageService.listFiles(
            any(),
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenThrow(StateError('A file URI must not enter the SAF scanner'));
        when(
          () => mockStorageService.copyToTemp(
            original.uri,
            'page.jpg',
            expectedBytes: 3,
          ),
        ).thenAnswer((_) async => original.path);
        when(
          () => mockImportUseCase.invoke(
            any(),
            parentPath: chapter.path,
            sourceFileName: 'page.jpg',
            importedAt: any(named: 'importedAt'),
            expectedFileBytes: 3,
          ),
        ).thenAnswer(
          (_) async => Result.success(
            MediaItem()
              ..id = 3
              ..path = '${chapter.path}/page.jpg',
          ),
        );
        final result = await service.importFolder(
          temp.uri,
          sourceName: 'Chosen',
          sourceEntries: [
            ExternalFileInfo(
              uri: '${original.uri}',
              name: 'page.jpg',
              relativePath: 'chapter/page.jpg',
              size: 3,
              isMedia: true,
            ),
          ],
          selectedRelativePaths: {'chapter/page.jpg'},
        );
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull!.processedItems, 1);
        expect(result.dataOrNull!.failedItems, 0);
        expect(await original.readAsBytes(), [1, 2, 3]);
        verifyNever(
          () => mockStorageService.listFiles(
            any(),
            isCancelled: any(named: 'isCancelled'),
          ),
        );
      },
    );

    test('サブフォルダのみにファイルが存在する場合でもルートフォルダとサブフォルダのカタログが正しく生成されること', () async {
      final rootUri = Uri.parse('file:///test/ParentFolder');

      // ルートフォルダ作成のモック
      final rootFolderItem = MediaItem()
        ..id = 1
        ..path = 'library/ParentFolder'
        ..type = MediaType.folder;
      when(
        () => mockCreateFolderUseCase.invoke('ParentFolder', parentPath: null),
      ).thenAnswer((_) async => Result.success(rootFolderItem));

      // サブフォルダ作成のモック
      final subFolderItem = MediaItem()
        ..id = 2
        ..path = 'library/ParentFolder/Chapter1'
        ..type = MediaType.folder;
      when(
        () => mockCreateFolderUseCase.invoke(
          'Chapter1',
          parentPath: 'library/ParentFolder',
        ),
      ).thenAnswer((_) async => Result.success(subFolderItem));

      // スキャン結果（サブフォルダ配下に1ファイル）
      final fileInfo = ExternalFileInfo(
        uri: 'file:///test/ParentFolder/Chapter1/page1.jpg',
        name: 'page1.jpg',
        relativePath: 'Chapter1/page1.jpg',
        size: 3,
        isMedia: true,
      );
      when(
        () => mockStorageService.listFiles(
          rootUri,
          isCancelled: any(named: 'isCancelled'),
        ),
      ).thenAnswer((_) => Stream.value(fileInfo));

      when(
        () => mockStorageService.copyToTemp(
          any(),
          any(),
          expectedBytes: any(named: 'expectedBytes'),
        ),
      ).thenAnswer((_) async => '/temp/page1.jpg');

      final importedMediaItem = MediaItem()
        ..id = 10
        ..path = 'library/ParentFolder/Chapter1/page1.jpg'
        ..thumbnailPath = 'thumbnails/page1.jpg'
        ..type = MediaType.file;

      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: 'library/ParentFolder/Chapter1',
          sourceFileName: 'page1.jpg',
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      ).thenAnswer((_) async => Result.success(importedMediaItem));

      // 実行: ルートフォルダに scrapBook、サブフォルダにも scrapBook
      final savedCollections = <MediaCollection>[];
      when(() => mockRepository.saveCollection(captureAny())).thenAnswer((
        invocation,
      ) async {
        final col = invocation.positionalArguments.first as MediaCollection;
        savedCollections.add(col);
        return Result.success(null);
      });

      final result = await service.importFolder(
        rootUri,
        isCatalog: true,
        registerChildFolders: true,
      );

      expect(result.isSuccess, true);

      // ルートフォルダとサブフォルダの2つのMediaCollectionが保存されたことを検証
      expect(savedCollections.length, 2);

      final rootCol = savedCollections.firstWhere(
        (c) => c.path == 'library/ParentFolder',
      );
      expect(rootCol.title, 'ParentFolder');
      expect(rootCol.isCatalog, true);
      // 子孫のファイルは、さらに上のカタログの表紙にしない
      expect(rootCol.coverImagePath, isNull);

      final subCol = savedCollections.firstWhere(
        (c) => c.path == 'library/ParentFolder/Chapter1',
      );
      expect(subCol.title, 'Chapter1');
      expect(subCol.isCatalog, true);
      expect(subCol.coverImagePath, 'thumbnails/page1.jpg');
    });
  });

  test(
    'folder selection reaches preflight and copying; retry reuses verified destination',
    () async {
      final uri = Uri.parse('file:///source/Folder');
      final root = MediaItem()
        ..id = 1
        ..path = 'library/Folder'
        ..type = MediaType.folder;
      final kept = MediaItem()
        ..id = 2
        ..path = 'library/Folder/keep.jpg'
        ..type = MediaType.file;
      final retry = MediaItem()
        ..id = 3
        ..path = 'library/Folder/retry.jpg'
        ..type = MediaType.file;
      when(
        () => mockCreateFolderUseCase.invoke('Folder', parentPath: null),
      ).thenAnswer((_) async => Result.success(root));
      when(
        () => mockRepository.getById(1),
      ).thenAnswer((_) async => Result.success(root));
      when(
        () => mockStorageService.listFiles(
          uri,
          isCancelled: any(named: 'isCancelled'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          ExternalFileInfo(
            uri: 'file:///source/Folder/keep.jpg',
            name: 'keep.jpg',
            relativePath: 'keep.jpg',
            size: 3,
            isMedia: true,
          ),
          ExternalFileInfo(
            uri: 'file:///source/Folder/retry.jpg',
            name: 'retry.jpg',
            relativePath: 'retry.jpg',
            size: 3,
            isMedia: true,
          ),
          // An unselected file with unknown size must not block preflight or be copied.
          ExternalFileInfo(
            uri: 'file:///source/Folder/excluded.jpg',
            name: 'excluded.jpg',
            relativePath: 'excluded.jpg',
            isMedia: true,
          ),
        ]),
      );
      final copied = <String>[];
      var failRetry = true;
      when(
        () => mockStorageService.copyToTemp(
          any(),
          any(),
          expectedBytes: any(named: 'expectedBytes'),
        ),
      ).thenAnswer((call) async {
        final name = call.positionalArguments[1] as String;
        copied.add(name);
        return name == 'retry.jpg' && failRetry ? null : '/temp/$name';
      });
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          sourceFileName: any(named: 'sourceFileName'),
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
          isCatalog: any(named: 'isCatalog'),
        ),
      ).thenAnswer(
        (call) async => Result.success(
          call.namedArguments[#sourceFileName] == 'keep.jpg' ? kept : retry,
        ),
      );
      final first = (await service.importFolder(
        uri,
        selectedRelativePaths: {'keep.jpg', 'retry.jpg'},
        isCatalog: true,
      )).dataOrNull!;
      expect(first.committedFiles.map((item) => item.id), [2]);
      expect(first.pendingSourcePaths, ['retry.jpg']);
      expect(copied, ['keep.jpg', 'retry.jpg']);
      failRetry = false;
      final second = (await service.importFolder(
        uri,
        selectedRelativePaths: {'retry.jpg'},
        isCatalog: true,
        resumeDestinations: first.destinations,
      )).dataOrNull!;
      expect(second.committedFiles.map((item) => item.id), [3]);
      expect(copied, ['keep.jpg', 'retry.jpg', 'retry.jpg']);
      verify(
        () => mockCreateFolderUseCase.invoke('Folder', parentPath: null),
      ).called(1);
      verify(() => mockRepository.saveCollection(any())).called(1);
    },
  );

  test(
    'changed retry destination fails before copying instead of creating a duplicate folder',
    () async {
      when(
        () => mockRepository.getById(1),
      ).thenAnswer((_) async => Result.success(null));
      final result = await service.importFolder(
        Uri.parse('file:///source/Folder'),
        selectedRelativePaths: {'retry.jpg'},
        resumeDestinations: const [
          ImportCommittedItem(
            id: 1,
            path: 'library/Folder',
            sourcePath: '',
            isFolder: true,
          ),
        ],
      );
      expect(result.isFailure, isTrue);
      expect(
        ImportExecutionReport.fromMap(
          result.errorOrNull!.additionalData!,
        ).retryBlocked,
        isTrue,
      );
      verifyNever(
        () => mockCreateFolderUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
        ),
      );
      verifyNever(
        () => mockStorageService.copyToTemp(
          any(),
          any(),
          expectedBytes: any(named: 'expectedBytes'),
        ),
      );
    },
  );

  test('実際のscanから未対応BIN5件を含むフォルダを追加してもJPGを巻き戻さない', () async {
    final rootUri = Uri.parse('file:///source/mixed');
    final root = MediaItem()
      ..id = 1
      ..path = 'library/mixed'
      ..type = MediaType.folder;
    final photo = MediaItem()
      ..id = 2
      ..path = 'library/mixed/photo.jpg';
    final entries = [
      ExternalFileInfo(
        uri: 'file:///source/mixed/photo.jpg',
        name: 'photo.jpg',
        relativePath: 'photo.jpg',
        size: 3,
        isMedia: true,
      ),
      for (var i = 1; i <= 5; i++)
        ExternalFileInfo(
          uri: 'file:///source/mixed/file$i.bin',
          name: 'file$i.bin',
          relativePath: 'file$i.bin',
          size: 3,
          isMedia: false,
        ),
    ];
    when(
      () => mockStorageService.listFiles(
        rootUri,
        isCancelled: any(named: 'isCancelled'),
      ),
    ).thenAnswer((_) => Stream.fromIterable(entries));
    when(
      () => mockCreateFolderUseCase.invoke('mixed', parentPath: null),
    ).thenAnswer((_) async => Result.success(root));
    when(
      () => mockStorageService.copyToTemp(
        any(),
        any(),
        expectedBytes: any(named: 'expectedBytes'),
        maxBytes: any(named: 'maxBytes'),
      ),
    ).thenAnswer((_) async => '/temp/photo.jpg');
    when(
      () => mockImportUseCase.invoke(
        any(),
        parentPath: any(named: 'parentPath'),
        sourceFileName: any(named: 'sourceFileName'),
        importedAt: any(named: 'importedAt'),
        expectedFileBytes: any(named: 'expectedFileBytes'),
        isCatalog: any(named: 'isCatalog'),
      ),
    ).thenAnswer((_) async => Result.success(photo));
    when(
      () => mockRepository.getById(1),
    ).thenAnswer((_) async => Result.success(root));
    when(
      () => mockRepository.getById(2),
    ).thenAnswer((_) async => Result.success(photo));
    when(
      () => mockRepository.deleteGraph([1, 2], []),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => mockFileService.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final tree = (await ScanDirectoryUseCase(
      mockStorageService,
    ).invoke(rootUri)).dataOrNull!;
    expect(tree.children.length, 6);
    expect(
      tree.children
          .where((node) => !node.isMedia)
          .every((node) => node.includeInImport),
      isTrue,
    );
    final result = await AdvancedImportUseCase(
      service,
    ).invoke([tree, ...tree.children]);
    final report =
        result.dataOrNull ??
        ImportExecutionReport.fromMap(result.errorOrNull!.additionalData!);
    expect(result.isSuccess, isTrue);
    verify(
      () => mockStorageService.copyToTemp(
        Uri.parse('file:///source/mixed/photo.jpg'),
        'photo.jpg',
        expectedBytes: 3,
        maxBytes: any(named: 'maxBytes'),
      ),
    ).called(1);
    verifyNever(() => mockFileService.deleteFile(any()));
    verifyNever(() => mockRepository.deleteGraph([1, 2], []));
    expect(report.committedFiles.map((item) => item.id), [2]);
    expect(report.totalItems, 6);
    expect(report.processedItems, 1);
    expect(report.failedItems, 5);
    expect(
      report.failedEntries.every(
        (entry) => entry.reason == ImportFailureReasonCode.unsupported,
      ),
      isTrue,
    );
    expect(report.pendingSourcePaths, isEmpty);
    expect(report.isRolledBack, isFalse);
  });

  test('確認後に消失した対応JPGは未対応扱いせず失敗分の再試行対象に残す', () async {
    final rootUri = Uri.parse('file:///source/mixed');
    final root = MediaItem()
      ..id = 1
      ..path = 'library/mixed'
      ..type = MediaType.folder;
    final photo = MediaItem()
      ..id = 2
      ..path = 'library/mixed/photo.jpg';
    final entries = [
      ExternalFileInfo(
        uri: 'file:///source/mixed/photo.jpg',
        name: 'photo.jpg',
        relativePath: 'photo.jpg',
        size: 3,
        isMedia: true,
      ),
      ExternalFileInfo(
        uri: 'file:///source/mixed/missing.jpg',
        name: 'missing.jpg',
        relativePath: 'missing.jpg',
        size: 3,
        isMedia: true,
      ),
    ];
    var scans = 0;
    when(
      () => mockStorageService.listFiles(
        rootUri,
        isCancelled: any(named: 'isCancelled'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable(scans++ == 0 ? entries : entries.take(1)),
    );
    when(
      () => mockCreateFolderUseCase.invoke('mixed', parentPath: null),
    ).thenAnswer((_) async => Result.success(root));
    when(
      () => mockStorageService.copyToTemp(
        any(),
        any(),
        expectedBytes: any(named: 'expectedBytes'),
        maxBytes: any(named: 'maxBytes'),
      ),
    ).thenAnswer((_) async => '/temp/photo.jpg');
    when(
      () => mockImportUseCase.invoke(
        any(),
        parentPath: any(named: 'parentPath'),
        sourceFileName: any(named: 'sourceFileName'),
        importedAt: any(named: 'importedAt'),
        expectedFileBytes: any(named: 'expectedFileBytes'),
        isCatalog: any(named: 'isCatalog'),
      ),
    ).thenAnswer((_) async => Result.success(photo));
    when(
      () => mockRepository.getById(1),
    ).thenAnswer((_) async => Result.success(root));
    when(
      () => mockRepository.getById(2),
    ).thenAnswer((_) async => Result.success(photo));
    when(
      () => mockRepository.deleteGraph([1, 2], []),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => mockFileService.deleteFile(any()),
    ).thenAnswer((_) async => Result.success(null));

    final tree = (await ScanDirectoryUseCase(
      mockStorageService,
    ).invoke(rootUri)).dataOrNull!;
    expect(tree.children.length, 2);
    expect(
      tree.children
          .where((node) => !node.isMedia)
          .every((node) => node.includeInImport),
      isTrue,
    );
    final result = await AdvancedImportUseCase(
      service,
    ).invoke([tree, ...tree.children]);
    final report =
        result.dataOrNull ??
        ImportExecutionReport.fromMap(result.errorOrNull!.additionalData!);
    expect(result.isSuccess, isTrue);
    verify(
      () => mockStorageService.copyToTemp(
        Uri.parse('file:///source/mixed/photo.jpg'),
        'photo.jpg',
        expectedBytes: 3,
        maxBytes: any(named: 'maxBytes'),
      ),
    ).called(1);
    verifyNever(() => mockFileService.deleteFile(any()));
    verifyNever(() => mockRepository.deleteGraph([1, 2], []));
    expect(report.committedFiles.map((item) => item.id), [2]);
    expect(report.totalItems, 2);
    expect(report.processedItems, 1);
    expect(report.failedItems, 1);
    expect(
      report.failedEntries.every(
        (entry) => entry.reason == ImportFailureReasonCode.file,
      ),
      isTrue,
    );
    expect(report.pendingSourcePaths, ['missing.jpg']);
    expect(report.isRolledBack, isFalse);
  });

  group('InternalImportService.importFiles', () {
    test('子取り込みの保存状態が不明なら前の成果を残して再試行と巻戻しを止める', () async {
      final saved = MediaItem()
        ..id = 9
        ..path = 'library/first.jpg';
      var calls = 0;
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          isCatalog: any(named: 'isCatalog'),
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Result.success(saved)
            : Result.failure(
                AppError.database(
                  'rollback failed',
                ).withAdditionalData({'importRetryBlocked': true}),
              );
      });
      final result = await service.importFiles([
        File('/source/first.jpg'),
        File('/source/uncertain.jpg'),
        File('/source/later.jpg'),
      ]);
      expect(result.isFailure, isTrue);
      final report = ImportExecutionReport.fromMap(
        result.errorOrNull!.additionalData!,
      );
      expect(report.retryBlocked, isTrue);
      expect(report.committedFiles.map((item) => item.id), [9]);
      expect(report.processedItems, 1);
      expect(calls, 2);
      verifyNever(() => mockFileService.deleteFile(any()));
    });

    test('件数上限超過は最初のファイルを処理する前に拒否する', () async {
      service = InternalImportService(
        mockImportUseCase,
        mockCreateFolderUseCase,
        mockStorageService,
        mockFileService,
        mockOperationJournal,
        mockRepository,
        mockNotificationService,
        isCancelled: () => false,
        invalidateCollection: (_) {},
        invalidateLibrary: () {},
        maxImportFileCount: 1,
        fileSize: (_) async => 3,
      );

      final result = await service.importFiles([
        File('/source/one.jpg'),
        File('/source/two.jpg'),
      ]);

      expect(result.isFailure, isTrue);
      verifyNever(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          isCatalog: any(named: 'isCatalog'),
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      );
    });

    test('取消時はDBと取込済みの実ファイル・サムネイルをロールバックする', () async {
      var isCancelled = false;
      service = InternalImportService(
        mockImportUseCase,
        mockCreateFolderUseCase,
        mockStorageService,
        mockFileService,
        mockOperationJournal,
        mockRepository,
        mockNotificationService,
        isCancelled: () => isCancelled,
        invalidateCollection: (_) {},
        invalidateLibrary: () {},
        fileSize: (_) async => 3,
      );
      final importedItem = MediaItem()
        ..id = 10
        ..path = 'library/page1.jpg'
        ..thumbnailPath = '.thumbnails/page1.jpg'
        ..type = MediaType.file;
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          isCatalog: any(named: 'isCatalog'),
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      ).thenAnswer((_) async {
        isCancelled = true;
        return Result.success(importedItem);
      });
      when(
        () => mockRepository.getById(10),
      ).thenAnswer((_) async => Result.success(importedItem));
      when(
        () => mockRepository.deleteGraph([10], []),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockFileService.deleteFile(any()),
      ).thenAnswer((_) async => Result.success(null));

      final result = await service.importFiles([
        File('/source/page1.jpg'),
        File('/source/page2.jpg'),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isCancelled, isTrue);
      expect(result.dataOrNull?.hasCommittedFiles, isFalse);
      expect(result.dataOrNull?.processedItems, 0);
      verify(() => mockRepository.deleteGraph([10], [])).called(1);
      verify(() => mockFileService.deleteFile('library/page1.jpg')).called(1);
      verify(
        () => mockFileService.deleteFile('.thumbnails/page1.jpg'),
      ).called(1);
      verify(() => mockOperationJournal.write(any())).called(1);
      verify(() => mockOperationJournal.remove(any())).called(1);
    });

    test('ロールバックの実ファイル削除失敗を成功として隠さない', () async {
      var isCancelled = false;
      service = InternalImportService(
        mockImportUseCase,
        mockCreateFolderUseCase,
        mockStorageService,
        mockFileService,
        mockOperationJournal,
        mockRepository,
        mockNotificationService,
        isCancelled: () => isCancelled,
        invalidateCollection: (_) {},
        invalidateLibrary: () {},
        fileSize: (_) async => 3,
      );
      final importedItem = MediaItem()
        ..id = 11
        ..path = 'library/page1.jpg'
        ..type = MediaType.file;
      when(
        () => mockImportUseCase.invoke(
          any(),
          parentPath: any(named: 'parentPath'),
          isCatalog: any(named: 'isCatalog'),
          importedAt: any(named: 'importedAt'),
          expectedFileBytes: any(named: 'expectedFileBytes'),
        ),
      ).thenAnswer((_) async {
        isCancelled = true;
        return Result.success(importedItem);
      });
      when(
        () => mockRepository.getById(11),
      ).thenAnswer((_) async => Result.success(importedItem));
      when(
        () => mockRepository.deleteGraph([11], []),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockFileService.deleteFile('library/page1.jpg'),
      ).thenAnswer((_) async => Result.failure(AppError.file('削除に失敗')));

      final result = await service.importFiles([
        File('/source/page1.jpg'),
        File('/source/page2.jpg'),
      ]);

      expect(result.isFailure, isTrue);
      verify(() => mockOperationJournal.write(any())).called(1);
      verifyNever(() => mockOperationJournal.remove(any()));
    });
  });
}
